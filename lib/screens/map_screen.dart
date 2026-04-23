// Issue #12 - [CF-CARTE] : Carte interactive avec marqueurs de prix des biens
// Issue #13 - [CF-CARTE] : Filtres par prix et bottom sheet liste des biens
// Issue #14 - [CF-CARTE] : Popup fiche d'un bien sur la carte avec bouton Réserver
import 'dart:async';
import 'dart:io';
import 'dart:math' show sqrt;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/property.dart';
import '../services/property_service.dart';
import '../services/location_service.dart';
import '../services/favorite_service.dart';
import '../widgets/property_popup.dart';
import 'search_screen.dart';

class _Cluster {
  final List<Property> properties;

  _Cluster(this.properties);

  int get count => properties.length;
  bool get isSingle => properties.length == 1;

  LatLng get center {
    final lat = properties.map((p) => p.latitude!).reduce((a, b) => a + b) / properties.length;
    final lng = properties.map((p) => p.longitude!).reduce((a, b) => a + b) / properties.length;
    return LatLng(lat, lng);
  }
}

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
  double _userLat = 46.603354; // Centre France
  double _userLng = 1.888334;
  bool _hasUserPosition = false;
  bool _mapReady = false;
  StreamSubscription<MapEvent>? _mapEventSub;
  List<_Cluster> _clusters = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refresh() => _loadData();

  @override
  void dispose() {
    _mapEventSub?.cancel();
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
        _userLat = position.latitude;
        _userLng = position.longitude;
        _hasUserPosition = true;
      }
    });
    _recalculateClusters();
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
    _recalculateClusters();
  }

  List<_Cluster> _buildClusters(List<Property> properties, MapCamera camera) {
    const double clusterRadiusPx = 50.0;
    final List<_Cluster> clusters = [];
    final Set<int> assigned = {};

    for (int i = 0; i < properties.length; i++) {
      if (assigned.contains(i)) continue;
      final pi = camera.latLngToScreenPoint(
        LatLng(properties[i].latitude!, properties[i].longitude!),
      );
      final List<Property> group = [properties[i]];
      assigned.add(i);

      for (int j = i + 1; j < properties.length; j++) {
        if (assigned.contains(j)) continue;
        final pj = camera.latLngToScreenPoint(
          LatLng(properties[j].latitude!, properties[j].longitude!),
        );
        final dx = pi.x - pj.x;
        final dy = pi.y - pj.y;
        if (sqrt(dx * dx + dy * dy) <= clusterRadiusPx) {
          group.add(properties[j]);
          assigned.add(j);
        }
      }

      clusters.add(_Cluster(group));
    }

    return clusters;
  }

  void _recalculateClusters() {
    if (!mounted || !_mapReady) return;
    try {
      final camera = _mapController.camera;
      final newClusters = _buildClusters(_filteredProperties, camera);
      setState(() => _clusters = newClusters);
    } catch (_) {}
  }

  Widget _buildSingleMarker() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C5E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterMarker(int count) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C5E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _centerOnUser() {
    if (_hasUserPosition) {
      _mapController.move(LatLng(_userLat, _userLng), 13);
    }
  }

  void _showPropertyPopup(Property property) {
    showDialog(
      context: context,
      builder: (_) => PropertyPopup(
        property: property,
        dateDebut: widget.dateDebut,
        dateFin: widget.dateFin,
        userLatitude: _hasUserPosition ? _userLat : null,
        userLongitude: _hasUserPosition ? _userLng : null,
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
            Text('${p.prixNuit!.toStringAsFixed(0)} €/nuit',
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              final double targetLat = p.latitude!;
              final double targetLng = p.longitude!;
              final String encodedLabel = Uri.encodeComponent(p.name);
              final Uri uri;
              if (Platform.isIOS) {
                uri = Uri.parse('https://maps.apple.com/?ll=$targetLat,$targetLng&q=$encodedLabel');
              } else if (Platform.isAndroid) {
                uri = Uri.parse('geo:$targetLat,$targetLng?q=$targetLat,$targetLng($encodedLabel)');
              } else {
                uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$targetLat,$targetLng');
              }
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Icon(Icons.directions, color: Color(0xFF1A3C5E), size: 20),
          ),
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
        Navigator.of(context).pop();
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
          // Carte OpenStreetMap via flutter_map (sans clé API)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_userLat, _userLng),
              initialZoom: 6,
              minZoom: 4,
              onMapReady: () {
                _mapReady = true;
                _mapEventSub = _mapController.mapEventStream.listen((_) {
                  _recalculateClusters();
                });
                _recalculateClusters();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.nestvia.nestvia',
              ),
              MarkerLayer(
                markers: [
                  if (_hasUserPosition)
                    Marker(
                      point: LatLng(_userLat, _userLng),
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
                  ..._clusters.map((cluster) {
                    final double size = cluster.isSingle ? 20 : (cluster.count >= 10 ? 44 : 36);
                    return Marker(
                      point: cluster.center,
                      width: size,
                      height: size,
                      child: GestureDetector(
                        onTap: () {
                          if (cluster.isSingle) {
                            _showPropertyPopup(cluster.properties.first);
                          } else {
                            _mapController.move(
                              cluster.center,
                              _mapController.camera.zoom + 2,
                            );
                          }
                        },
                        child: cluster.isSingle
                            ? _buildSingleMarker()
                            : _buildClusterMarker(cluster.count),
                      ),
                    );
                  }),
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

          // Bouton géolocalisation
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
