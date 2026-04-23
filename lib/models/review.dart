/// Modèle d'un avis client sur un bien
class Review {
  final int id;
  final int rating;
  final String? comment;
  final String? prenomLocataire;
  final String? nomLocataire;
  final DateTime? dateAvis;

  const Review({
    required this.id,
    required this.rating,
    this.comment,
    this.prenomLocataire,
    this.nomLocataire,
    this.dateAvis,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id_avis'] is int
          ? json['id_avis'] as int
          : int.tryParse(json['id_avis']?.toString() ?? '') ?? 0,
      rating: json['rating'] is int
          ? json['rating'] as int
          : int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      comment: json['comment']?.toString(),
      prenomLocataire: json['prenom_locataire']?.toString(),
      nomLocataire: json['nom_locataire']?.toString(),
      dateAvis: json['date_avis'] != null
          ? DateTime.tryParse(json['date_avis'].toString())
          : null,
    );
  }

  String get displayName {
    if (prenomLocataire != null && nomLocataire != null) {
      return '$prenomLocataire ${nomLocataire![0].toUpperCase()}.';
    }
    if (prenomLocataire != null) return prenomLocataire!;
    return 'Anonyme';
  }
}
