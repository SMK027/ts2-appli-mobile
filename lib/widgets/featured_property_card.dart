// Issue #8 - [CF-HOME] : Carte d'un bien "En vedette"
// Issue #11 - [CF-HOME] : Ajout et suppression d'un bien en favori
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/property.dart';
import '../screens/property_detail_screen.dart';
import '../services/favorite_service.dart';

class FeaturedPropertyCard extends StatefulWidget {
  final Property property;
  final VoidCallback? onFavoriteChanged;

  const FeaturedPropertyCard({
    super.key,
    required this.property,
    this.onFavoriteChanged,
  });

  @override
  State<FeaturedPropertyCard> createState() => _FeaturedPropertyCardState();
}

class _FeaturedPropertyCardState extends State<FeaturedPropertyCard> {
  static IconData _prestationIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wifi') || lower.contains('internet')) return Icons.wifi;
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('piscine')) return Icons.pool;
    if (lower.contains('clim')) return Icons.ac_unit;
    if (lower.contains('tv') || lower.contains('télé')) return Icons.tv;
    if (lower.contains('lave')) return Icons.local_laundry_service;
    if (lower.contains('cuisine')) return Icons.kitchen;
    if (lower.contains('jardin')) return Icons.yard;
    if (lower.contains('baignoire') || lower.contains('bain')) return Icons.bathtub;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final isFavorite = FavoriteService().isFavorite(p.id);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PropertyDetailScreen(property: p),
        ),
      ),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Photo + badge + bouton favori
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: p.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: p.photoUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported,
                              size: 40, color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.home, size: 48, color: Colors.grey),
                        ),
                      ),
              ),

              // Badge (ex: "Coup de coeur", "Nouveau")
              if (p.badge != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.badge!.toLowerCase().contains('nouveau')
                          ? const Color(0xFF10B981)
                          : Colors.red.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Bouton favori (cœur) - Issue #11
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    FavoriteService().toggleFavorite(p.id);
                    setState(() {});
                    widget.onFavoriteChanged?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color:
                          isFavorite ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Informations du bien
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + rating
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.rating != null) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        p.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Commune + type · surface
                Row(
                  children: [
                    Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '${p.commune}   ${p.typeBien} · ${p.superficie.toStringAsFixed(0)} m²',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Icônes prestations
                if (p.prestations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: p.prestations.take(4).map((presta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          _prestationIcon(presta),
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                // Prix + bouton Voir
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
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: ' / nuit',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PropertyDetailScreen(property: p),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Voir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
