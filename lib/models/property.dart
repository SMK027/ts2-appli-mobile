/// Modèle de données pour un bien immobilier
/// Issues #8, #9, #11, #12, #14, #15 - [CF-HOME] [CF-CARTE] [CF-RESA]
class Property {
  final int id;
  final String name;
  final String commune;
  final String typeBien;
  final double superficie;
  final String? photoUrl;
  final String? badge;
  final List<String> prestations;
  final double? rating;
  final double? distanceKm;
  final double? prixNuit;
  final double? latitude;
  final double? longitude;
  final int? nbCouchage;
  final String? description;
  final String? rue;
  final String? cpCommune;

  const Property({
    required this.id,
    required this.name,
    required this.commune,
    required this.typeBien,
    required this.superficie,
    this.photoUrl,
    this.badge,
    this.prestations = const [],
    this.rating,
    this.distanceKm,
    this.prixNuit,
    this.latitude,
    this.longitude,
    this.nbCouchage,
    this.description,
    this.rue,
    this.cpCommune,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id_bien'] is int
          ? json['id_bien'] as int
          : int.tryParse(json['id_bien'].toString()) ?? 0,
      name: json['nom_bien']?.toString() ?? '',
      commune: json['nom_commune']?.toString() ?? '',
      typeBien: json['des_typebien']?.toString() ?? '',
      superficie: _toDouble(json['superficie_bien']) ?? 0,
      photoUrl: json['lien_photo']?.toString(),
      badge: json['badge']?.toString(),
      prestations: (json['prestations'] as List<dynamic>?)
              ?.map((e) => e is Map ? (e['libelle_prestation']?.toString() ?? e.toString()) : e.toString())
              .toList() ??
          [],
      rating: _toDouble(json['rating_moyen']),
      distanceKm: _toDouble(json['distance_km']),
      prixNuit: _toDouble(json['tarif']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      nbCouchage: json['nb_couchage'] is int
          ? json['nb_couchage'] as int
          : int.tryParse(json['nb_couchage']?.toString() ?? ''),
      description: json['description_bien']?.toString(),
      rue: json['rue_bien']?.toString(),
      cpCommune: json['cp_commune']?.toString(),
    );
  }

  Property copyWith({String? photoUrl, double? prixNuit, double? distanceKm}) {
    return Property(
      id: id,
      name: name,
      commune: commune,
      typeBien: typeBien,
      superficie: superficie,
      photoUrl: photoUrl ?? this.photoUrl,
      badge: badge,
      prestations: prestations,
      rating: rating,
      distanceKm: distanceKm ?? this.distanceKm,
      prixNuit: prixNuit ?? this.prixNuit,
      latitude: latitude,
      longitude: longitude,
      nbCouchage: nbCouchage,
      description: description,
      rue: rue,
      cpCommune: cpCommune,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
