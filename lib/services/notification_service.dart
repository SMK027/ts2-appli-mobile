// Issue #20 - [CF-NOTIFS] : Service de gestion des notifications
// Issue #21 - [CF-NOTIFS] : Dépôt d'avis
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _pushedNotificationsKey = 'pushed_notifications';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isPushInitialized = false;

  Future<void> initializeLocalPush() async {
    if (_isPushInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _isPushInitialized = true;
  }

  /// Récupère les notifications de l'utilisateur
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response =
          await ApiService().client.get(ApiConfig.notificationsEndpoint);
      final notifications =
          (response.data as List).cast<Map<String, dynamic>>();
      await _notifyUnreadPush(notifications);
      return notifications;
    } on DioException catch (_) {
      return [];
    }
  }

  Future<void> _notifyUnreadPush(
    List<Map<String, dynamic>> notifications,
  ) async {
    await initializeLocalPush();

    final pushedKeys = await _loadPushedNotificationKeys();

    for (final notif in notifications) {
      final type = notif['type']?.toString();
      final isRead = _isRead(notif['is_read']);
      if (isRead) continue;

      final uniqueKey = _notificationUniqueKey(notif);
      if (pushedKeys.contains(uniqueKey)) continue;

      final notifId = _notificationId(notif);
      final title = _notificationTitle(type);
      final message = _notificationMessage(type, notif);

      await _localNotifications.show(
        notifId,
        title,
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'nestvia_notifications_channel',
            'Notifications Nestvia',
            channelDescription: 'Notifications importantes de l\'application',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );

      pushedKeys.add(uniqueKey);
    }

    await _savePushedNotificationKeys(pushedKeys);
  }

  Future<Set<String>> _loadPushedNotificationKeys() async {
    final raw = await _storage.read(key: _pushedNotificationsKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  Future<void> _savePushedNotificationKeys(Set<String> keys) async {
    await _storage.write(
      key: _pushedNotificationsKey,
      value: jsonEncode(keys.toList()),
    );
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool _isRead(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value?.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  String _notificationUniqueKey(Map<String, dynamic> notif) {
    final id = _toInt(notif['id_notification'] ?? notif['id']);
    if (id != null) return 'id:$id';

    final type = notif['type']?.toString() ?? '';
    final message = notif['message']?.toString() ?? '';
    final created =
        notif['date_created']?.toString() ?? notif['created_at']?.toString() ?? '';
    return 'fallback:$type|$message|$created';
  }

  int _notificationId(Map<String, dynamic> notif) {
    final id = _toInt(notif['id_notification'] ?? notif['id']);
    if (id != null) return id;
    return _notificationUniqueKey(notif).hashCode & 0x7fffffff;
  }

  String _notificationTitle(String? type) {
    switch (type) {
      case 'review_request':
        return 'Nestvia - Avis demandé';
      case 'reservation':
        return 'Nestvia - Réservation';
      case 'payment':
        return 'Nestvia - Paiement';
      default:
        return 'Nestvia - Nouvelle notification';
    }
  }

  String _notificationMessage(String? type, Map<String, dynamic> notif) {
    final message = notif['message']?.toString();
    if (message != null && message.isNotEmpty) return message;
    if (type == 'review_request') {
      return 'Votre location est terminée, laissez un avis sur votre bien meublé.';
    }
    return 'Vous avez reçu une nouvelle notification.';
  }

  /// Nombre de notifications non lues
  Future<int> getUnreadCount() async {
    final notifs = await getNotifications();
    return notifs.where((n) => !_isRead(n['is_read'])).length;
  }

  /// Marquer une notification comme lue (PATCH /notifications/:id/read)
  Future<bool> markAsRead(int idNotification) async {
    try {
      await ApiService().client.patch(
        '${ApiConfig.notificationsEndpoint}/$idNotification/read',
      );
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<void> markAllAsRead(List<Map<String, dynamic>> notifs) async {
    for (final n in notifs) {
      if (!_isRead(n['is_read'])) {
        final id = n['id_notification'];
        if (id != null) {
          await markAsRead(id is int ? id : int.parse(id.toString()));
        }
      }
    }
  }

  /// Créer un avis (POST /reviews)
  Future<Map<String, dynamic>?> createReview({
    required int idBien,
    required int idReservation,
    required int rating,
    String? comment,
  }) async {
    final response = await ApiService().client.post(
      '${ApiConfig.biensEndpoint}/$idBien${ApiConfig.avisEndpoint}',
      data: {
        'id_reservation': idReservation,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return response.data as Map<String, dynamic>?;
  }
}
