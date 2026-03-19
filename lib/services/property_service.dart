// Service de récupération des biens immobiliers
// Issue #8 - Biens "En vedette"
// Issue #9 - Biens "Près de vous"
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/property.dart';
import 'api_service.dart';

class PropertyService {
  /// Récupère la première photo d'un bien (GET /biens/:id/photos)
  Future<String?> _getFirstPhoto(int idBien) async {
    try {
      final response = await ApiService()
          .client
          .get('${ApiConfig.biensEndpoint}/$idBien/photos');
      final List data = response.data as List;
      for (final p in data) {
        final url = p['lien_photo']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    } on DioException catch (_) {
      // ignore
    }
    return null;
  }

  /// Récupère le tarif hebdomadaire d'un bien (semaine courante ou premier disponible)
  Future<double?> _getWeeklyTarif(int idBien) async {
    try {
      final response = await ApiService()
          .client
          .get('${ApiConfig.biensEndpoint}/$idBien/tarifs');
      final List data = response.data as List;
      if (data.isEmpty) return null;

      // Chercher le tarif de la semaine courante
      final now = DateTime.now();
      final yearNow = now.year.toString();
      final weekNow = _weekNumber(now);

      for (final t in data) {
        final annee = t['annee_tarif']?.toString();
        final semaine = int.tryParse(t['semaine_tarif']?.toString() ?? '');
        if (annee == yearNow && semaine == weekNow) {
          final tarif = t['tarif'];
          if (tarif != null) {
            return tarif is num ? tarif.toDouble() : double.tryParse(tarif.toString());
          }
        }
      }

      // Sinon, premier tarif disponible
      final first = data.first;
      final tarif = first['tarif'];
      if (tarif != null) {
        return tarif is num ? tarif.toDouble() : double.tryParse(tarif.toString());
      }
    } on DioException catch (_) {
      // ignore
    }
    return null;
  }

  static int _weekNumber(DateTime date) {
    final jan1 = DateTime.utc(date.year, 1, 1);
    final days = date.toUtc().difference(jan1).inDays;
    return ((days + jan1.weekday) / 7).ceil();
  }

  /// Enrichit une liste de biens avec photos et tarifs (en parallèle)
  Future<List<Property>> enrichProperties(List<Property> properties) async {
    final futures = properties.map((p) async {
      var prop = p;
      if (prop.photoUrl == null) {
        final photo = await _getFirstPhoto(prop.id);
        if (photo != null) prop = prop.copyWith(photoUrl: photo);
      }
      if (prop.prixNuit == null) {
        final tarif = await _getWeeklyTarif(prop.id);
        if (tarif != null) prop = prop.copyWith(prixNuit: tarif);
      }
      return prop;
    });
    return Future.wait(futures);
  }

  /// Issue #8 : Récupère les biens mis en vedette
  Future<List<Property>> getFeaturedProperties() async {
    try {
      final response = await ApiService()
          .client
          .get(ApiConfig.featuredPropertiesEndpoint);
      final List data = response.data as List;
      final properties = data
          .map((json) => Property.fromJson(json as Map<String, dynamic>))
          .toList();
      return enrichProperties(properties);
    } on DioException catch (_) {
      return [];
    }
  }

  /// Issue #9 : Récupère les biens proches d'une position GPS
  Future<List<Property>> getNearbyProperties({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await ApiService().client.get(
        ApiConfig.nearbyPropertiesEndpoint,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
        },
      );
      final List data = response.data as List;
      final properties = data
          .map((json) => Property.fromJson(json as Map<String, dynamic>))
          .toList();
      return enrichProperties(properties);
    } on DioException catch (_) {
      return [];
    }
  }

  /// Recherche avancée avec filtres (GET /biens?...)
  Future<List<Property>> searchProperties({
    String? commune,
    String? typeBien,
    int? nbPersonnes,
    String? animaux,
    double? tarifMin,
    double? tarifMax,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (commune != null && commune.isNotEmpty) params['commune'] = commune;
      if (typeBien != null && typeBien.isNotEmpty) params['type_bien'] = typeBien;
      if (nbPersonnes != null) params['nb_personnes'] = nbPersonnes;
      if (animaux != null && animaux.isNotEmpty) params['animaux'] = animaux;
      if (tarifMin != null) params['tarif_min'] = tarifMin;
      if (tarifMax != null) params['tarif_max'] = tarifMax;

      final response = await ApiService().client.get(
        ApiConfig.biensEndpoint,
        queryParameters: params,
      );
      final List data = response.data as List;
      final properties = data
          .map((json) => Property.fromJson(json as Map<String, dynamic>))
          .toList();
      return enrichProperties(properties);
    } on DioException catch (_) {
      return [];
    }
  }

  /// Filtre les biens disponibles (ni réservés ni bloqués) pour une période donnée
  /// via GET /biens/:id/disponibilite?date_debut=...&date_fin=...
  Future<List<Property>> filterAvailable({
    required List<Property> properties,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    final dateDebutStr = dateDebut.toIso8601String().split('T').first;
    final dateFinStr = dateFin.toIso8601String().split('T').first;

    final futures = properties.map((p) async {
      try {
        final response = await ApiService().client.get(
          '${ApiConfig.biensEndpoint}/${p.id}/disponibilite',
          queryParameters: {
            'date_debut': dateDebutStr,
            'date_fin': dateFinStr,
          },
        );
        final data = response.data as Map<String, dynamic>;
        return data['disponible'] == true ? p : null;
      } on DioException catch (_) {
        return p; // en cas d'erreur, on garde le bien
      }
    });
    final results = await Future.wait(futures);
    return results.whereType<Property>().toList();
  }
}
