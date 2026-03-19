// Issue #8 - [CF-HOME] : Affichage des biens "En vedette" avec carrousel horizontal
// Issue #9 - [CF-HOME] : Affichage des biens "Près de vous" avec géolocalisation GPS
// Issue #10 - [CF-HOME] : Barre de recherche et filtres par catégorie de bien
// Issue #11 - [CF-HOME] : Intégration favoris + navigation carte
// Issue #27 - [PAGE] Page d'accueil connectée (HomePage)
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/favorite_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/property_service.dart';
import 'package:geocoding/geocoding.dart';
import '../widgets/featured_property_card.dart';
import '../widgets/nearby_property_item.dart';
import 'map_screen.dart';
import 'main_nav_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Property> _featuredProperties = [];
  List<Property> _nearbyProperties = [];
  String _locationLabel = 'Chargement...';
  bool _loadingFeatured = true;
  bool _loadingNearby = true;
  int _unreadNotifs = 0;
  String _userInitials = '';
  String _userFirstName = '';
  String _selectedCategory = 'Tous';
  List<String> _categories = ['Tous'];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadFeatured();
    _loadNearby();
    _loadHeaderData();
    _loadCategories();
  }

  void refresh() {
    _loadFavorites();
    _loadFeatured();
    _loadNearby();
    _loadHeaderData();
  }

  Future<void> _loadHeaderData() async {
    final profile = await ProfileService().getProfile();
    final count = await NotificationService().getUnreadCount();
    if (!mounted) return;
    setState(() {
      _unreadNotifs = count;
      if (profile != null) {
        final prenom = profile['prenom_locataire']?.toString() ?? '';
        final nom = profile['nom_locataire']?.toString() ?? '';
        _userFirstName = prenom;
        _userInitials = '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase();
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService().client.get(ApiConfig.typesBienEndpoint);
      final List data = response.data as List;
      final types = data
          .map((e) => (e is Map ? e['des_typebien']?.toString() : e?.toString()) ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _categories = ['Tous', ...types]);
    } on DioException catch (_) {
      // garde la liste par défaut
    }
  }

  Future<void> _loadFavorites() async {
    await FavoriteService().loadFavorites();
  }

  Future<void> _loadFeatured() async {
    final properties = await PropertyService().getFeaturedProperties();
    if (!mounted) return;
    setState(() {
      _featuredProperties = properties;
      _loadingFeatured = false;
    });
  }

  Future<void> _loadNearby() async {
    final position = await LocationService().getCurrentPosition();
    if (!mounted) return;

    if (position == null) {
      setState(() {
        _locationLabel = 'Position indisponible';
        _loadingNearby = false;
      });
      return;
    }

    // Géocodage inverse pour obtenir le nom de la ville
    String label =
        '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
        if (city != null && city.isNotEmpty) {
          label = city;
        }
      }
    } catch (_) {
      // En cas d'échec du géocodage, on garde les coordonnées
    }

    if (!mounted) return;
    setState(() {
      _locationLabel = label;
    });

    final properties = await PropertyService().getNearbyProperties(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    // Calcul de la distance côté client si l'API ne la fournit pas
    final withDistance = properties.map((p) {
      if (p.distanceKm != null) return p;
      if (p.latitude == null || p.longitude == null) return p;
      final meters = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        p.latitude!, p.longitude!,
      );
      return p.copyWith(distanceKm: meters / 1000.0);
    }).toList();

    if (!mounted) return;
    setState(() {
      _nearbyProperties = withDistance;
      _loadingNearby = false;
    });
  }

  List<Property> get _filteredFeatured {
    if (_selectedCategory == 'Tous') return _featuredProperties;
    return _featuredProperties
        .where((p) => p.typeBien.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
  }

  List<Property> get _filteredNearby {
    final nearby = _nearbyProperties
      .where((p) => p.distanceKm != null && p.distanceKm! <= 35.0);
    if (_selectedCategory == 'Tous') return nearby.toList();
    return nearby
        .where((p) => p.typeBien.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
  }

  IconData _categoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower == 'tous') return Icons.home_outlined;
    if (lower.contains('studio')) return Icons.hotel_outlined;
    if (lower.contains('appartement')) return Icons.apartment_outlined;
    if (lower.contains('maison')) return Icons.house_outlined;
    if (lower.contains('villa')) return Icons.villa_outlined;
    return Icons.business_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: () async {
            setState(() {
              _loadingFeatured = true;
              _loadingNearby = true;
            });
            await Future.wait([
              _loadFavorites(),
              _loadFeatured(),
              _loadNearby(),
              _loadHeaderData(),
            ]);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Votre localisation',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _locationLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(Icons.notifications_outlined, color: onSurface),
                          onPressed: () {
                            final navState = context.findAncestorStateOfType<MainNavScreenState>();
                            navState?.switchToTab(3);
                          },
                        ),
                        if (_unreadNotifs > 0)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        final navState = context.findAncestorStateOfType<MainNavScreenState>();
                        navState?.switchToTab(4);
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF10B981),
                        child: Text(
                          _userInitials.isNotEmpty ? _userInitials : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Greeting ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour${_userFirstName.isNotEmpty ? ', $_userFirstName' : ''} 👋',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Trouvez votre logement\n',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                              height: 1.3,
                            ),
                          ),
                          TextSpan(
                            text: 'meublé idéal',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Barre de recherche ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
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

              const SizedBox(height: 16),

              // ── Filtres par type de bien ──
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981) : cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _categoryIcon(cat),
                                size: 16,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Bouton Rechercher ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Rechercher',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Section "En vedette" ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'En vedette ✨',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      ),
                      child: const Text(
                        'Voir tout',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (_loadingFeatured)
                const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                )
              else if (_filteredFeatured.isEmpty)
                const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'Aucun bien en vedette disponible.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _filteredFeatured.length,
                    itemBuilder: (_, index) => FeaturedPropertyCard(
                      property: _filteredFeatured[index],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Section "Près de vous" ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Près de vous 📍',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      ),
                      child: const Text(
                        'Sur la carte',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              if (_loadingNearby)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                )
              else if (_filteredNearby.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Aucun bien trouvé près de chez vous.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: _filteredNearby
                        .map((p) => NearbyPropertyItem(property: p))
                        .toList(),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
