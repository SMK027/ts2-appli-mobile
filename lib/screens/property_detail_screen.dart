import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/property.dart';
import '../models/review.dart';
import '../services/location_service.dart';
import '../services/favorite_service.dart';
import '../services/reservation_service.dart';
import '../services/search_filter_service.dart';
import 'booking_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  Property? _detail;
  List<String> _photos = [];
  List<Review> _reviews = [];
  bool _loading = true;
  double? _userDistance;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _calculateDistance();
  }

  Future<void> _loadDetail() async {
    final service = ReservationService();
    final results = await Future.wait([
      service.getPropertyDetail(widget.property.id),
      service.getPropertyPhotos(widget.property.id),
      service.getPropertyReviews(widget.property.id),
    ]);

    if (!mounted) return;
    setState(() {
      _detail = results[0] as Property?;
      _photos = results[1] as List<String>;
      _reviews = results[2] as List<Review>;
      _loading = false;
    });
  }

  Future<void> _calculateDistance() async {
    try {
      final position = await LocationService().getCurrentPosition();
      if (!mounted || position == null) return;
      
      final p = _detail ?? widget.property;
      if (p.latitude == null || p.longitude == null) return;
      
      final meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        p.latitude!,
        p.longitude!,
      );
      
      setState(() {
        _userDistance = meters / 1000.0;
      });
    } catch (_) {
      // Silently fail if location unavailable
    }
  }

  Widget _buildReviewsSection() {
    if (_reviews.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Avis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 8),
          Text('Aucun avis pour ce bien.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      );
    }

    final avgRating = _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Avis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 2),
            Text(
              avgRating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              ' (${_reviews.length})',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._reviews.map(_buildReviewCard),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF1A3C5E).withAlpha(30),
                child: Text(
                  review.prenomLocataire?.isNotEmpty == true
                      ? review.prenomLocataire![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF1A3C5E),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (review.dateAvis != null)
                      Text(
                        '${review.dateAvis!.day.toString().padLeft(2, '0')}/'
                        '${review.dateAvis!.month.toString().padLeft(2, '0')}/'
                        '${review.dateAvis!.year}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _detail ?? widget.property;
    final isFav = FavoriteService().isFavorite(p.id);
    final photoUrl = _photos.isNotEmpty ? _photos.first : p.photoUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du bien'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.home,
                                size: 56,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: GestureDetector(
                        onTap: () {
                          FavoriteService().toggleFavorite(p.id);
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (p.rating != null) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 3),
                            Text(
                              p.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${p.commune}${p.cpCommune != null ? ' (${p.cpCommune})' : ''}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                          if (_userDistance != null)
                            Text(
                              '${_userDistance!.toStringAsFixed(1)} km',
                              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            p.typeBien,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(' · ', style: TextStyle(color: Colors.grey)),
                          Text(
                            '${p.superficie.toStringAsFixed(0)} m²',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (p.nbCouchage != null) ...[
                            const Text(' · ', style: TextStyle(color: Colors.grey)),
                            Text(
                              '${p.nbCouchage} couchages',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                      if (p.prestations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Prestations',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: p.prestations.map((presta) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withAlpha(22),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                presta,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Section avis
                      _buildReviewsSection(),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (p.prixNuit != null)
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${p.prixNuit!.toStringAsFixed(0)} €',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' / nuit',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BookingScreen(
                                  property: p,
                                  nbPersonnes: SearchFilterService().nbCouchages,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Réserver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
