// Issue #22 - [CF-PROFIL] : Service pour les informations du compte
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  /// Récupère les informations du compte connecté (GET /compte)
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response =
          await ApiService().client.get(ApiConfig.compteEndpoint);
      return response.data as Map<String, dynamic>;
    } on DioException catch (_) {
      return null;
    }
  }

  /// Met à jour les informations du compte (PUT /compte)
  Future<Map<String, dynamic>?> updateProfile(
      Map<String, dynamic> data) async {
    final response = await ApiService().client.put(
      ApiConfig.compteEndpoint,
      data: data,
    );
    return response.data as Map<String, dynamic>?;
  }

  /// Récupère les réservations de l'utilisateur (GET /reservations)
  Future<List<Map<String, dynamic>>> getReservations() async {
    try {
      final response =
          await ApiService().client.get(ApiConfig.reservationsEndpoint);
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (_) {
      return [];
    }
  }

  /// Détail d'une réservation (GET /reservations/:id)
  Future<Map<String, dynamic>?> getReservationDetail(int id) async {
    try {
      final response =
          await ApiService().client.get('${ApiConfig.reservationsEndpoint}/$id');
      return response.data as Map<String, dynamic>;
    } on DioException catch (_) {
      return null;
    }
  }

  /// Annule une réservation (DELETE /reservations/:id)
  Future<bool> cancelReservation(int id) async {
    try {
      await ApiService().client.delete('${ApiConfig.reservationsEndpoint}/$id');
      return true;
    } on DioException catch (_) {
      return false;
    }
  }
}
