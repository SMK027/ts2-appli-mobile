// Issue #12 - [CF-CARTE] : Carte interactive avec marqueurs de prix des biens
// Issue #13 - [CF-CARTE] : Filtres par prix et bottom sheet liste des biens
// Issue #14 - [CF-CARTE] : Popup fiche d'un bien sur la carte avec bouton Réserver
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/property.dart';
import '../services/property_service.dart';
import '../services/location_service.dart';
import '../services/favorite_service.dart';
import '../widgets/property_popup.dart';
import 'search_screen.dart';

class MapScreen extends StatefulWidget {
  final List<Property>? initialProperties;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const MapScreen({super.key, this.initialProperties, this.dateDebut, this.dateFin});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Property> _allProperties = [];
  List<Property> _filteredProperties = [];
  String _selectedFilter = 'Tous';
  bool _loading = true;
  LatLng _userPosition = const LatLng(46.603354, 1.888334); // Centre France
  bool _hasUserPosition = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refresh() => _loadData();

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final List<Property> properties;
    if (widget.initialProperties != null) {
      properties = widget.initialProperties!;
    } else {
      properties = await PropertyService().getFeaturedProperties();
    }
    final position = await LocationService().getCurrentPosition();

    if (!mounted) return;

    setState(() {
      _allProperties = properties
          .where((p) => p.latitude != null && p.longitude != null)
          .toList();
      _applyFilter();
      _loading = false;

      if (position != null) {
        _userPosition = LatLng(position.latitude, position.longitude);
        _hasUserPosition = true;
      }
    });
  }

  void _applyFilter() {
    switch (_selectedFilter) {
      case '< 100€':
        _filteredProperties = _allProperties
            .where((p) => p.prixNuit != null && p.prixNuit! < 100)
            .toList();
        break;
      case 'Luxe':
        _filteredProperties = _allProperties
            .where((p) => p.prixNuit != null && p.prixNuit! >= 200)
            .toList();
        break;
      default:
        _filteredProperties = List.from(_allProperties);
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _centerOnUser() {
    if (_hasUserPosition) {
      _mapController.move(_userPosition, 13);
    }
  }

  void _showPropertyPopup(Property property) {
    showDialog(
      context: context,
      builder: (_) => PropertyPopup(
        property: property,
        dateDebut: widget.dateDebut,
        dateFin: widget.dateFin,
      ),
    );
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${_filteredProperties.length} biens dans cette zone',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredProperties.length,
                itemBuilder: (_, index) {
                  final p = _filteredProperties[index];
                  return _buildBottomSheetItem(p);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetItem(Property p) {
    final isFav = FavoriteService().isFavorite(p.id);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          color: Colors.grey.shade200,
          child: p.photoUrl != null
              ? Image.network(p.photoUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, e, st) =>
                      const Icon(Icons.home, color: Colors.grey))
              : const Icon(Icons.home, color: Colors.grey),
        ),
      ),
      title: Text(p.name,
          style: const TextStyle(
              fontWeight: FontWeight.w600)),
      subtitle: Text(p.commune, style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.prixNuit != null)
            Text('${p.prixNuit!.toStringAsFixed(0)} €',
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() => FavoriteService().toggleFavorite(p.id));
            },
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).pop(); // Ferme le bottom sheet
        _mapController.move(LatLng(p.latitude!, p.longitude!), 15);
        _showPropertyPopup(p);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition,
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.nestvia.nestvia',
              ),
              MarkerLayer(
                markers: [
                  // Position utilisateur
                  if (_hasUserPosition)
                    Marker(
                      point: _userPosition,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withAlpha(80),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Marqueurs des biens avec prix
                  ..._filteredProperties.map((p) => Marker(
                        point: LatLng(p.latitude!, p.longitude!),
                        width: 90,
                        height: 32,
                        child: GestureDetector(
                          onTap: () => _showPropertyPopup(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A3C5E),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              p.prixNuit != null
                                  ? '${p.prixNuit!.toStringAsFixed(0)} €/sem'
                                  : '—',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ],
          ),

          // Barre de recherche + filtres en haut
          SafeArea(
            child: Column(
              children: [
                // Barre de recherche + bouton retour
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.arrow_back,
                                  color: Theme.of(context).colorScheme.onSurface, size: 20),
                            ),
                          ),
                        ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SearchScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.grey.shade400, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Ville, quartier, adresse...',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.tune, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filtres prix
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['Tous', '< 100€', 'Luxe'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _onFilterChanged(filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF10B981) : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(10),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Bouton géolocalisation (Issue #12)
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'geoloc',
              onPressed: _centerOnUser,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.my_location,
                color: _hasUserPosition
                    ? const Color(0xFF1A3C5E)
                    : Colors.grey,
              ),
            ),
          ),

          // Bouton "N biens dans cette zone" (Issue #13)
          if (!_loading)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _showBottomSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3C5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '${_filteredProperties.length} biens dans cette zone',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // Loader
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
