// Issue #22 - [CF-PROFIL] : Page Profil utilisateur
// Issue #24 - [CF-PROFIL] : Déconnexion
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import 'favorites_screen.dart';
import 'landing_screen.dart';
import 'my_reservations_screen.dart';
import 'change_password_screen.dart';
import 'notifications_screen.dart';
import 'personal_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  int _nbReservations = 0;
  int _nbTerminees = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void refresh() => _loadProfile();

  Future<void> _loadProfile() async {
    final service = ProfileService();
    final profile = await service.getProfile();
    final reservations = await service.getReservations();

    final now = DateTime.now();
    int terminees = 0;
    for (final r in reservations) {
      final dateFin = DateTime.tryParse(r['date_fin']?.toString() ?? '');
      if (dateFin != null && dateFin.isBefore(now)) {
        terminees++;
      }
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _nbReservations = reservations.length;
      _nbTerminees = terminees;
      _loading = false;
    });
  }

  String _getInitials() {
    if (_profile == null) return '?';
    final nom = _profile!['nom_locataire']?.toString() ?? '';
    final prenom = _profile!['prenom_locataire']?.toString() ?? '';
    final initN = nom.isNotEmpty ? nom[0].toUpperCase() : '';
    final initP = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    return '$initP$initN'.isEmpty ? '?' : '$initP$initN';
  }

  String _getFullName() {
    if (_profile == null) return '';
    final nom = _profile!['nom_locataire']?.toString() ?? '';
    final prenom = _profile!['prenom_locataire']?.toString() ?? '';
    return '$prenom $nom'.trim();
  }

  String _getAnciennete() {
    final createdAt = _profile?['created_at']?.toString();
    if (createdAt == null) return '';
    final date = DateTime.tryParse(createdAt);
    if (date == null) return '';
    final years = DateTime.now().difference(date).inDays ~/ 365;
    if (years < 1) return 'Membre depuis moins d\'un an';
    return 'Membre depuis $years an${years > 1 ? 's' : ''}';
  }

  void _showSettingsDialog() {
    final themeService = ThemeService();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Paramètres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Apparence',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(
                    ctx, setSheetState, themeService,
                    icon: Icons.brightness_5,
                    label: 'Clair',
                    mode: ThemeMode.light,
                  ),
                  _buildThemeOption(
                    ctx, setSheetState, themeService,
                    icon: Icons.brightness_2,
                    label: 'Sombre',
                    mode: ThemeMode.dark,
                  ),
                  _buildThemeOption(
                    ctx, setSheetState, themeService,
                    icon: Icons.settings_suggest,
                    label: 'Système',
                    mode: ThemeMode.system,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext ctx,
    StateSetter setSheetState,
    ThemeService themeService, {
    required IconData icon,
    required String label,
    required ThemeMode mode,
  }) {
    final selected = themeService.themeMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: selected ? const Color(0xFF10B981) : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? const Color(0xFF10B981) : null,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
          : null,
      onTap: () {
        themeService.setThemeMode(mode);
        setSheetState(() {});
      },
    );
  }

  // Issue #24 - Déconnexion avec confirmation
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion'),
        content:
            const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AuthService().logout();
    FavoriteService().clear();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // En-tête profil
                  _buildProfileHeader(),
                  const SizedBox(height: 20),

                  // Statistiques
                  _buildStatsRow(),
                  const SizedBox(height: 24),

                  // Section MON COMPTE
                  _buildSectionTitle('MON COMPTE'),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    Icons.person_outline,
                    'Informations personnelles',
                    subtitle: _getFullName(),
                    onTap: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => PersonalInfoScreen(
                            initialLastName:
                                _profile?['nom_locataire']?.toString() ?? '',
                            initialFirstName:
                                _profile?['prenom_locataire']?.toString() ?? '',
                            initialStreet:
                              _profile?['rue_locataire']?.toString() ?? '',
                            initialAddressComplement:
                              _profile?['comp_locataire']?.toString() ?? '',
                            initialCommuneName:
                              _profile?['nom_commune']?.toString() ?? '',
                            initialCommuneId: (() {
                              final idCommune = _profile?['id_commune'];
                              if (idCommune is int) return idCommune;
                              return int.tryParse(idCommune?.toString() ?? '');
                            })(),
                          ),
                        ),
                      );

                      if (updated == true) {
                        _loadProfile();
                      }
                    },
                  ),
                  _buildMenuItem(
                    Icons.lock_outline,
                    'Sécurité et connexion',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    Icons.notifications_outlined,
                    'Notifications',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section ACTIVITÉ
                  _buildSectionTitle('ACTIVITÉ'),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    Icons.calendar_today,
                    'Mes réservations',
                    trailing: _nbReservations > 0
                        ? _buildBadge(_nbReservations.toString())
                        : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const MyReservationsScreen()),
                    ),
                  ),
                  _buildMenuItem(
                    Icons.favorite_outline,
                    'Mes favoris',
                    trailing: FavoriteService().favoriteIds.isNotEmpty
                        ? _buildBadge(
                            FavoriteService().favoriteIds.length.toString())
                        : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const FavoritesScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section SUPPORT
                  _buildSectionTitle('SUPPORT'),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    Icons.help_outline,
                    'Centre d\'aide',
                  ),
                  _buildMenuItem(
                    Icons.settings_outlined,
                    'Paramètres',
                    onTap: _showSettingsDialog,
                  ),
                  const SizedBox(height: 24),

                  // Bouton déconnexion
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Déconnexion',
                          style: TextStyle(color: Colors.red, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Version
                  Center(
                    child: Text(
                      'Nestvia v1.0.0',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF1A3C5E),
            child: Text(
              _getInitials(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFullName(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile?['email_locataire']?.toString() ?? '',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Compte vérifié',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            Icons.luggage,
            '$_nbTerminees',
            'Séjours effectués',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            Icons.access_time,
            _getAnciennete().isEmpty ? '-' : _getAnciennete(),
            'Ancienneté',
            small: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label,
      {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: small ? 12 : 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600))
            : null,
        trailing: trailing ??
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C5E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
