// Issue #20 - [CF-NOTIFS] : Page Notifications
// Issue #21 - [CF-NOTIFS] : Dépôt d'avis depuis notification review_request
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../widgets/review_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  int get _unreadCount =>
      _notifications.where((n) => !_isRead(n['is_read'])).length;

  bool _isRead(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value?.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void refresh() => _loadNotifications();

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final notifs = await NotificationService().getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifs;
      _loading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    await NotificationService().markAllAsRead(_notifications);
    if (!mounted) return;
    setState(() {
      for (final n in _notifications) {
        n['is_read'] = 1;
      }
    });
  }

  Future<void> _markAsRead(Map<String, dynamic> notif) async {
    if (_isRead(notif['is_read'])) return;
    final id = notif['id_notification'];
    final intId = id is int ? id : int.parse(id.toString());
    await NotificationService().markAsRead(intId);
    if (!mounted) return;
    setState(() => notif['is_read'] = 1);
  }

  void _removeNotification(int index) {
    setState(() => _notifications.removeAt(index));
  }

  void _openReviewDialog(Map<String, dynamic> notif) {
    final idReservation = notif['id_reservation'];
    if (idReservation == null) return;

    showDialog(
      context: context,
      builder: (_) => ReviewDialog(
        idReservation:
            idReservation is int ? idReservation : int.parse(idReservation.toString()),
        onReviewSubmitted: () {
          _markAsRead(notif);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount NOUVEAU${_unreadCount > 1 ? 'X' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          if (_notifications.any((n) => !_isRead(n['is_read'])))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tout marquer comme lu',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) =>
                        _buildNotificationCard(_notifications[i], i),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous serez notifié des événements importants',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  IconData _getNotifIcon(String? type) {
    switch (type) {
      case 'review_request':
        return Icons.rate_review;
      case 'reservation':
        return Icons.calendar_today;
      case 'payment':
        return Icons.payment;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotifColor(String? type) {
    switch (type) {
      case 'review_request':
        return Colors.orange;
      case 'reservation':
        return const Color(0xFF1A3C5E);
      case 'payment':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, int index) {
    final type = notif['type']?.toString();
    final isRead = _isRead(notif['is_read']);
    final message = notif['message']?.toString() ?? '';

    return Dismissible(
      key: ValueKey(notif['id_notification']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeNotification(index),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isRead ? 0.5 : 2,
        color: isRead ? Theme.of(context).cardColor : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2A3A) : const Color(0xFFF0F4FF)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _markAsRead(notif),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getNotifColor(type).withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getNotifIcon(type),
                        color: _getNotifColor(type),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Contenu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getNotifTitle(type),
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Date + badge non lu
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(notif['date_created']?.toString()),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A3C5E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                // Boutons review_request
                if (type == 'review_request') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _markAsRead(notif),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Plus tard'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openReviewDialog(notif),
                          icon: const Icon(Icons.star, size: 16),
                          label: const Text('Laisser un avis'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getNotifTitle(String? type) {
    switch (type) {
      case 'review_request':
        return 'Donnez votre avis';
      case 'reservation':
        return 'Réservation';
      case 'payment':
        return 'Paiement';
      case 'info':
        return 'Information';
      default:
        return 'Notification';
    }
  }
}
