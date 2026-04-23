// Issue #14 - [CF-CARTE] : Popup fiche résumée d'un bien sur la carte
// Photo, nom, note, localisation, type, superficie, prestations, prix, bouton Réserver
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/property.dart';
import '../models/review.dart';
import '../services/favorite_service.dart';
import '../services/reservation_service.dart';
import '../services/search_filter_service.dart';
import '../screens/booking_screen.dart';

class PropertyPopup extends StatefulWidget {
  final Property property;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final double? userLatitude;
  final double? userLongitude;

  const PropertyPopup({
    super.key,
    required this.property,
    this.dateDebut,
    this.dateFin,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<PropertyPopup> createState() => _PropertyPopupState();
}

class _PropertyPopupState extends State<PropertyPopup> {
  Property? _detail;
  List<String> _photos = [];
  List<Review> _reviews = [];
  bool _loading = true;
  int _currentPhotoIndex = 0;

  double? _distanceToPropertyKm(Property p) {
    if (p.distanceKm != null) return p.distanceKm;
    if (widget.userLatitude == null || widget.userLongitude == null) return null;
    if (p.latitude == null || p.longitude == null) return null;

    final meters = Geolocator.distanceBetween(
      widget.userLatitude!,
      widget.userLongitude!,
      p.latitude!,
      p.longitude!,
    );
    return meters / 1000.0;
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _openFullscreen(BuildContext context, List<String> photos, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenGallery(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
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

  List<Widget> _buildReviewsPreview() {
    final avgRating = _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;
    final previewed = _reviews.take(3).toList();

    return [
      const Divider(height: 1),
      const SizedBox(height: 10),
      Row(
        children: [
          const Text('Avis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          const Icon(Icons.star, color: Colors.amber, size: 13),
          const SizedBox(width: 2),
          Text(avgRating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Text(' (${_reviews.length})',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      const SizedBox(height: 8),
      ...previewed.map((review) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFF1A3C5E).withAlpha(30),
                  child: Text(
                    review.prenomLocataire?.isNotEmpty == true
                        ? review.prenomLocataire![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF1A3C5E),
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(review.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                          const Spacer(),
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < review.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 11,
                            ),
                          ),
                        ],
                      ),
                      if (review.comment != null && review.comment!.isNotEmpty)
                        Text(
                          review.comment!,
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = _detail ?? widget.property;
    final distanceKm = _distanceToPropertyKm(p);
    final isFav = FavoriteService().isFavorite(p.id);
    final allPhotos = _photos.isNotEmpty
        ? _photos
        : (p.photoUrl != null ? [p.photoUrl!] : <String>[]);
    final photoUrl = allPhotos.isNotEmpty ? allPhotos[_currentPhotoIndex] : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo + navigation + bouton fermer + favori
            Stack(
              children: [
                GestureDetector(
                  onTap: allPhotos.isNotEmpty
                      ? () => _openFullscreen(context, allPhotos, _currentPhotoIndex)
                      : null,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, url) => Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, url, err) => Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported,
                                  size: 40, color: Colors.grey),
                            ),
                          )
                        : Container(
                            height: 180,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.home,
                                size: 48, color: Colors.grey),
                          ),
                  ),
                ),
                // Bouton photo précédente
                if (allPhotos.length > 1)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _currentPhotoIndex =
                              (_currentPhotoIndex - 1 + allPhotos.length) %
                              allPhotos.length;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(100),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                // Bouton photo suivante
                if (allPhotos.length > 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _currentPhotoIndex =
                              (_currentPhotoIndex + 1) % allPhotos.length;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(100),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                // Points indicateurs
                if (allPhotos.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(allPhotos.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentPhotoIndex ? 10 : 6,
                          height: i == _currentPhotoIndex ? 10 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _currentPhotoIndex
                                ? Colors.white
                                : Colors.white.withAlpha(140),
                          ),
                        );
                      }),
                    ),
                  ),
                // Bouton fermer
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ),
                // Bouton favori
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      FavoriteService().toggleFavorite(p.id);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + note
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (p.rating != null) ...[
                          const Icon(Icons.star,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            p.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Localisation
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${p.commune}${p.cpCommune != null ? ' (${p.cpCommune})' : ''}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ),
                        if (distanceKm != null)
                          Text(
                            '${distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Type + superficie
                    Row(
                      children: [
                        Text(p.typeBien,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary, fontSize: 13)),
                        const Text(' · ',
                            style: TextStyle(color: Colors.grey)),
                        Text('${p.superficie.toStringAsFixed(0)} m²',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        if (p.nbCouchage != null) ...[
                          const Text(' · ',
                              style: TextStyle(color: Colors.grey)),
                          Text('${p.nbCouchage} couchages',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ],
                      ],
                    ),

                    // Prestations
                    if (p.prestations.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: p.prestations.take(5).map((presta) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(presta,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.primary)),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Avis (3 premiers)
                    if (_reviews.isNotEmpty) ..._buildReviewsPreview(),

                    const SizedBox(height: 16),

                    // Prix + bouton Réserver
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (p.prixNuit != null)
                          Text(
                            '${p.prixNuit!.toStringAsFixed(0)} €/nuit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BookingScreen(
                                      property: _detail ?? p,
                                      dateDebut: widget.dateDebut,
                                      dateFin: widget.dateFin,
                                      nbPersonnes: SearchFilterService().nbCouchages,
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('Réserver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
      ),
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _FullscreenGallery({required this.photos, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Galerie swipeable
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.photos[i],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 60,
                    ),
                  ),
                ),
              );
            },
          ),

          // Bouton fermer
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),

          // Compteur et points indicateurs
          if (widget.photos.length > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    '${_currentIndex + 1} / ${widget.photos.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.photos.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentIndex ? 10 : 6,
                        height: i == _currentIndex ? 10 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentIndex
                              ? Colors.white
                              : Colors.white.withAlpha(120),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
