// Issue #1 - [INIT] : Initialisation du client HTTP Dio avec l'URL de base de l'API
// Gestion des erreurs de connexion (pas de réseau, API indisponible)
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'navigation_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _refreshExpiresAtKey = 'refresh_expires_at';
  static const _retryFlag = '__refresh_retry__';

  Completer<void>? _refreshCompleter;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final statusCode = e.response?.statusCode;
          if (statusCode == 401 && _shouldTryRefresh(e.requestOptions)) {
            final refreshed = await _refreshAccessToken();
            if (refreshed) {
              try {
                final retryRequest = e.requestOptions;
                retryRequest.extra[_retryFlag] = true;

                final latestToken = await _storage.read(key: _tokenKey);
                if (latestToken != null && latestToken.isNotEmpty) {
                  retryRequest.headers['Authorization'] = 'Bearer $latestToken';
                }

                final response = await _dio.fetch<dynamic>(retryRequest);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;

  /// Ajoute le token JWT dans les en-têtes de chaque requête
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Supprime le token JWT des en-têtes
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  bool _shouldTryRefresh(RequestOptions requestOptions) {
    if (requestOptions.extra[_retryFlag] == true) return false;
    final path = requestOptions.path;
    if (path.endsWith(ApiConfig.loginEndpoint)) return false;
    if (path.endsWith(ApiConfig.refreshEndpoint)) return false;
    return true;
  }

  Future<bool> _refreshAccessToken() async {
    // Si un refresh est déjà en cours, attendre son résultat.
    if (_refreshCompleter != null) {
      await _refreshCompleter!.future;
      final token = await _storage.read(key: _tokenKey);
      return token != null && token.isNotEmpty;
    }

    _refreshCompleter = Completer<void>();
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        await _clearStoredTokens();
        NavigationService().forceLogoutToLanding();
        return false;
      }

      final dioNoInterceptor = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dioNoInterceptor.post(
        ApiConfig.refreshEndpoint,
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;
      if (data is! Map) {
        await _clearStoredTokens();
        NavigationService().forceLogoutToLanding();
        return false;
      }

      final token = data['token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString();
      final refreshExpiresAt = data['refresh_expires_at']?.toString();

      if (token == null || token.isEmpty || newRefreshToken == null || newRefreshToken.isEmpty) {
        await _clearStoredTokens();
        NavigationService().forceLogoutToLanding();
        return false;
      }

      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
      if (refreshExpiresAt != null && refreshExpiresAt.isNotEmpty) {
        await _storage.write(key: _refreshExpiresAtKey, value: refreshExpiresAt);
      }

      setAuthToken(token);
      return true;
    } catch (_) {
      await _clearStoredTokens();
      NavigationService().forceLogoutToLanding();
      return false;
    } finally {
      _refreshCompleter?.complete();
      _refreshCompleter = null;
    }
  }

  Future<void> _clearStoredTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _refreshExpiresAtKey);
    clearAuthToken();
  }

  /// Traduit les erreurs Dio en messages lisibles pour l'utilisateur
  static String handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'La connexion a expiré. Vérifiez votre réseau.';
      case DioExceptionType.connectionError:
        return 'Impossible de contacter le serveur. Vérifiez votre connexion internet.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        final apiMessage = data is Map ? data['error']?.toString() : null;
        if (statusCode == 401) {
          return 'Identifiants incorrects ou session expirée.';
        } else if (statusCode == 404) {
          return apiMessage ?? 'Ressource introuvable.';
        } else if (statusCode == 409) {
          return apiMessage ?? 'Conflit : la ressource existe déjà.';
        } else if (statusCode == 429) {
          return apiMessage ?? 'Trop de requêtes. Veuillez réessayer plus tard.';
        } else if (statusCode != null && statusCode >= 500) {
          return apiMessage ?? 'Le serveur est temporairement indisponible.';
        }
        return apiMessage ?? 'Une erreur est survenue (code $statusCode).';
      default:
        return 'Une erreur inattendue est survenue.';
    }
  }
}
