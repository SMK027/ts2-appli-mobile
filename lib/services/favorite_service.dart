// Issue #11 - [CF-HOME] : Service de gestion des favoris
// Charge les favoris depuis l'API et gère le toggle local
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  final Set<int> _favoriteIds = {};
  final Map<int, int> _bienToFavoriId = {};

  bool isFavorite(int idBien) => _favoriteIds.contains(idBien);

  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// Charge les favoris depuis l'API (GET /favoris)
  Future<void> loadFavorites() async {
    try {
      final response =
          await ApiService().client.get(ApiConfig.favorisEndpoint);
      final List data = response.data as List;
      _favoriteIds.clear();
      _bienToFavoriId.clear();
      for (final item in data) {
        final idBien = item['id_bien'];
        final idFavori = item['id_favoris'] ?? item['id'];
        int? parsedBien;
        int? parsedFavori;
        if (idBien is int) {
          parsedBien = idBien;
        } else if (idBien != null) {
          parsedBien = int.tryParse(idBien.toString());
        }
        if (idFavori is int) {
          parsedFavori = idFavori;
        } else if (idFavori != null) {
          parsedFavori = int.tryParse(idFavori.toString());
        }
        if (parsedBien != null) {
          _favoriteIds.add(parsedBien);
          if (parsedFavori != null) {
            _bienToFavoriId[parsedBien] = parsedFavori;
          }
        }
      }
    } on DioException catch (_) {
      // Silencieux si l'API échoue
    }
  }

  /// Toggle favori : mise à jour locale immédiate + appel API
  Future<bool> toggleFavorite(int idBien) async {
    if (_favoriteIds.contains(idBien)) {
      _favoriteIds.remove(idBien);
      _removeFavoriteApi(idBien);
      return false;
    } else {
      _favoriteIds.add(idBien);
      _addFavoriteApi(idBien);
      return true;
    }
  }

  Future<void> _addFavoriteApi(int idBien) async {
    try {
      final response = await ApiService().client.post(
        ApiConfig.favorisEndpoint,
        data: {'id_bien': idBien},
      );
      final data = response.data;
      if (data is Map) {
        final idFavori = data['id_favoris'] ?? data['id'];
        if (idFavori != null) {
          _bienToFavoriId[idBien] = idFavori is int
              ? idFavori
              : int.tryParse(idFavori.toString()) ?? 0;
        }
      }
    } on DioException catch (_) {
      _favoriteIds.remove(idBien);
    }
  }

  Future<void> _removeFavoriteApi(int idBien) async {
    try {
      await ApiService().client.delete(
        '${ApiConfig.favorisEndpoint}/$idBien',
      );
      _bienToFavoriId.remove(idBien);
    } on DioException catch (_) {
      _favoriteIds.add(idBien);
    }
  }

  /// Réinitialise les favoris (ex: déconnexion)
  void clear() {
    _favoriteIds.clear();
  }
}
