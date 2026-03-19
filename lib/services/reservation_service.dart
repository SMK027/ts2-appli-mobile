// Issues #15, #16, #17 - [CF-RESA] : Service de réservation
// Détail d'un bien, blocages, tarifs, création de réservation
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/property.dart';
import 'api_service.dart';

class ReservationService {
  /// Récupère le détail d'un bien (GET /biens/:id) avec prestations
  Future<Property?> getPropertyDetail(int idBien) async {
    try {
      final response =
          await ApiService().client.get('${ApiConfig.biensEndpoint}/$idBien');
      return Property.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (_) {
      return null;
    }
  }

  /// Récupère les photos d'un bien (GET /biens/:id/photos)
  Future<List<String>> getPropertyPhotos(int idBien) async {
    try {
      final response = await ApiService()
          .client
          .get('${ApiConfig.biensEndpoint}/$idBien/photos');
      final List data = response.data as List;
      return data
          .map((p) => p['lien_photo']?.toString() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// Récupère les blocages d'un bien (GET /biens/:id/blocages)
  Future<List<Map<String, dynamic>>> getPropertyBlocages(int idBien) async {
    try {
      final response = await ApiService()
          .client
          .get('${ApiConfig.biensEndpoint}/$idBien/blocages');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (_) {
      return [];
    }
  }

  /// Récupère les tarifs d'un bien (GET /biens/:id/tarifs)
  Future<List<Map<String, dynamic>>> getPropertyTarifs(int idBien) async {
    try {
      final response = await ApiService()
          .client
          .get('${ApiConfig.biensEndpoint}/$idBien/tarifs');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (_) {
      return [];
    }
  }

  /// Crée une réservation (POST /reservations)
  Future<Map<String, dynamic>?> createReservation({
    required String dateDebut,
    required String dateFin,
    required int idBien,
    required int idTarif,
  }) async {
    final response = await ApiService().client.post(
      ApiConfig.reservationsEndpoint,
      data: {
        'date_debut': dateDebut,
        'date_fin': dateFin,
        'id_bien': idBien,
        'id_tarif': idTarif,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
