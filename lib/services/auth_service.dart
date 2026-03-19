// Issue #7 - [CF-AUTH] : Authentification via API et gestion du token de session
// Stockage sécurisé du token JWT via flutter_secure_storage
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _refreshExpiresAtKey = 'refresh_expires_at';

  /// Vérifie si un token de session est déjà stocké (Issue #2)
  Future<String?> getStoredToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Récupère le refresh token stocké
  Future<String?> getStoredRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Vérifie si la date d'expiration du refresh token est dépassée
  Future<bool> isRefreshTokenExpired() async {
    final raw = await _storage.read(key: _refreshExpiresAtKey);
    if (raw == null || raw.isEmpty) return false;
    final expiresAt = DateTime.tryParse(raw);
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }

  /// Vérifie si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    if (token != null && token.isNotEmpty) return true;

    final refreshToken = await getStoredRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    return !(await isRefreshTokenExpired());
  }

  /// Issue #7 : Envoie les identifiants à l'API et stocke le token JWT
  /// Retourne null en cas de succès, ou un message d'erreur
  Future<String?> login(String email, String password) async {
    try {
      final response = await ApiService().client.post(
        ApiConfig.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      final token = response.data['token'] as String?;
      final refreshToken = response.data['refresh_token'] as String?;
      final refreshExpiresAt = response.data['refresh_expires_at']?.toString();

      if (token == null || token.isEmpty || refreshToken == null || refreshToken.isEmpty) {
        return 'Réponse invalide du serveur.';
      }

      // Stockage sécurisé des tokens
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      if (refreshExpiresAt != null && refreshExpiresAt.isNotEmpty) {
        await _storage.write(key: _refreshExpiresAtKey, value: refreshExpiresAt);
      }

      // Injection du token dans le client HTTP pour les futures requêtes
      ApiService().setAuthToken(token);

      return null; // Succès
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Email ou mot de passe incorrect. Compte inexistant ou verrouillé.';
      }
      return ApiService.handleError(e);
    } catch (e) {
      return 'Une erreur inattendue est survenue.';
    }
  }

  /// Déconnecte l'utilisateur : supprime le token stocké
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _refreshExpiresAtKey);
    ApiService().clearAuthToken();
  }

  /// Initialise le token au démarrage si déjà connecté
  Future<void> initToken() async {
    final token = await getStoredToken();
    if (token != null) {
      ApiService().setAuthToken(token);
    }
  }
}
