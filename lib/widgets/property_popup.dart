// Issue #14 - [CF-CARTE] : Popup fiche résumée d'un bien sur la carte
// Photo, nom, note, localisation, type, superficie, prestations, prix, bouton Réserver
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/property.dart';
import '../services/favorite_service.dart';
import '../services/reservation_service.dart';
import '../services/search_filter_service.dart';
import '../screens/booking_screen.dart';

class PropertyPopup extends StatefulWidget {
  final Property property;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const PropertyPopup({super.key, required this.property, this.dateDebut, this.dateFin});

  @override
  State<PropertyPopup> createState() => _PropertyPopupState();
}

class _PropertyPopupState extends State<PropertyPopup> {
  Property? _detail;
  List<String> _photos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final service = ReservationService();
    final results = await Future.wait([
      service.getPropertyDetail(widget.property.id),
      service.getPropertyPhotos(widget.property.id),
    ]);
    if (!mounted) return;
    setState(() {
      _detail = results[0] as Property?;
      _photos = results[1] as List<String>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _detail ?? widget.property;
    final isFav = FavoriteService().isFavorite(p.id);
    final photoUrl =
        _photos.isNotEmpty ? _photos.first : p.photoUrl;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo + bouton fermer + favori
            Stack(
              children: [
                ClipRRect(
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
                    const SizedBox(height: 16),

                    // Prix + bouton Réserver
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (p.prixNuit != null)
                          Text(
                            '${p.prixNuit!.toStringAsFixed(0)} €/sem.',
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
