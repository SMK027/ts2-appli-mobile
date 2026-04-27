// Issue #23 - [CF-PROFIL] : Page "Mes réservations" avec filtres et gestion
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/profile_service.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

enum ReservationFilter { tout, aVenir, enCours, passees }

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  ReservationFilter _filter = ReservationFilter.tout;
  final Set<int> _cancellingReservationIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _loading = true);
    final reservations = await ProfileService().getReservations();
    if (!mounted) return;
    setState(() {
      _reservations = reservations;
      _loading = false;
    });
  }

  String _getStatus(Map<String, dynamic> r) {
    final now = DateTime.now();
    final debut = DateTime.tryParse(r['date_debut']?.toString() ?? '');
    final fin = DateTime.tryParse(r['date_fin']?.toString() ?? '');
    if (debut == null || fin == null) return 'inconnu';
    if (debut.isAfter(now)) return 'a_venir';
    if (fin.isBefore(now)) return 'terminee';
    return 'en_cours';
  }

  List<Map<String, dynamic>> get _filteredReservations {
    return _reservations.where((r) {
      final status = _getStatus(r);
      switch (_filter) {
        case ReservationFilter.tout:
          return true;
        case ReservationFilter.aVenir:
          return status == 'a_venir';
        case ReservationFilter.enCours:
          return status == 'en_cours';
        case ReservationFilter.passees:
          return status == 'terminee';
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReservations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filtres
          _buildFilterChips(),
          // Liste
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadReservations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              _buildReservationCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ReservationFilter.values.map((f) {
            final selected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected,
                label: Text(_filterLabel(f)),
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _filterLabel(ReservationFilter f) {
    switch (f) {
      case ReservationFilter.tout:
        return 'Tout';
      case ReservationFilter.aVenir:
        return 'À venir';
      case ReservationFilter.enCours:
        return 'En cours';
      case ReservationFilter.passees:
        return 'Passées';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucune réservation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos réservations apparaîtront ici',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'a_venir':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'À VENIR';
      case 'en_cours':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'EN COURS';
      case 'terminee':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = 'TERMINÉ';
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey;
        label = 'INCONNU';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
  }

  int? _getReservationId(Map<String, dynamic> r) {
    final rawId = r['id_reservations'] ?? r['id_reservation'] ?? r['id'];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? '');
  }

  Future<void> _cancelReservation(Map<String, dynamic> r) async {
    final id = _getReservationId(r);
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'identifier la réservation.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Annuler la réservation'),
        content: const Text(
          'Voulez-vous vraiment annuler cette réservation ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Annuler la réservation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _cancellingReservationIds.add(id));
    final success = await ProfileService().cancelReservation(id);
    if (!mounted) return;

    setState(() => _cancellingReservationIds.remove(id));

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'annulation de la réservation.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réservation annulée avec succès.')),
    );
    await _loadReservations();
  }

  Widget _buildReservationCard(Map<String, dynamic> r) {
    final status = _getStatus(r);
    final canCancel = status == 'a_venir' || status == 'en_cours';
    final reservationId = _getReservationId(r);
    final isCancelling = reservationId != null && _cancellingReservationIds.contains(reservationId);
    final nomBien = r['nom_bien']?.toString() ?? 'Bien';
    final commune = r['nom_commune']?.toString() ?? r['com_bien']?.toString() ?? '';
    final debut = _formatDate(r['date_debut']?.toString());
    final fin = _formatDate(r['date_fin']?.toString());
    final montant = r['montant_total'];
    final montantStr = montant != null
        ? '${double.tryParse(montant.toString())?.toStringAsFixed(2) ?? montant} €'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : badge statut + montant
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBadge(status),
                Text(
                  montantStr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Nom du bien
            Text(
              nomBien,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Commune
            if (commune.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(commune,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            const SizedBox(height: 8),

            // Dates
            Row(
              children: [
                const Icon(Icons.date_range,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '$debut → $fin',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDetail(r),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Détails'),
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isCancelling ? null : () => _cancelReservation(r),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isCancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Annuler'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> r) {
    final nomBien = r['nom_bien']?.toString() ?? 'Bien';
    final debut = _formatDate(r['date_debut']?.toString());
    final fin = _formatDate(r['date_fin']?.toString());
    final montant = r['montant_total'];
    final tarif = r['tarif'];
    final saison = r['libelle_saison']?.toString();
    final commune = r['nom_commune']?.toString() ?? r['com_bien']?.toString() ?? '';
    final dDebut = DateTime.tryParse(r['date_debut']?.toString() ?? '');
    final dFin = DateTime.tryParse(r['date_fin']?.toString() ?? '');
    final nbNuits = (dDebut != null && dFin != null)
        ? dFin.difference(dDebut).inDays
        : 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
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
            Text(
              nomBien,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            if (commune.isNotEmpty)
              Text(commune,
                  style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            _detailRow('Dates', '$debut → $fin'),
            if (nbNuits > 0)
              _detailRow('Nombre de nuits', '$nbNuits'),
            if (saison != null) _detailRow('Saison', saison),
            if (tarif != null)
              _detailRow('Tarif semaine', '$tarif €'),
            if (montant != null)
              _detailRow(
                'Montant total',
                '${double.tryParse(montant.toString())?.toStringAsFixed(2) ?? montant} €',
                bold: true,
              ),
            const SizedBox(height: 16),
            _buildStatusBadge(_getStatus(r)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

}
