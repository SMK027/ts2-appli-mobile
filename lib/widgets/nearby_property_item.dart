// Issue #9 - [CF-HOME] : Item d'un bien "Près de vous"
// Issue #11 - [CF-HOME] : Bouton favori
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/property.dart';
import '../screens/property_detail_screen.dart';

class NearbyPropertyItem extends StatefulWidget {
  final Property property;

  const NearbyPropertyItem({super.key, required this.property});

  @override
  State<NearbyPropertyItem> createState() => _NearbyPropertyItemState();
}

class _NearbyPropertyItemState extends State<NearbyPropertyItem> {
  @override
  Widget build(BuildContext context) {
    final p = widget.property;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PropertyDetailScreen(property: p),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
          // Photo avec badge type de bien
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: p.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: p.photoUrl!,
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 110,
                        width: 110,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.home,
                            size: 32, color: Colors.grey),
                      ),
              ),

              // Badge type de bien
              if (p.typeBien.isNotEmpty)
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.typeBien,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),

          // Infos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Note (rating)
                  if (p.rating != null)
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          p.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),

                  const SizedBox(height: 2),

                  // Nom du bien
                  Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Commune + distance
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey),
                      Expanded(
                        child: Text(
                          p.commune,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.distanceKm != null)
                        Text(
                          '${p.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Prix/nuit + bouton Réserver
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (p.prixNuit != null)
                        Text(
                          '${p.prixNuit!.toStringAsFixed(0)} €/nuit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Voir', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
