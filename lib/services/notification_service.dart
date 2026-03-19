// Issue #20 - [CF-NOTIFS] : Service de gestion des notifications
// Issue #21 - [CF-NOTIFS] : Dépôt d'avis
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

  static const _pushedReviewNotificationsKey = 'pushed_review_notifications';

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
      await _notifyReviewRequestPush(notifications);
      return notifications;
    } on DioException catch (_) {
      return [];
    }
  }

  Future<void> _notifyReviewRequestPush(
    List<Map<String, dynamic>> notifications,
  ) async {
    await initializeLocalPush();

    final pushedIds = await _loadPushedReviewIds();

    for (final notif in notifications) {
      final type = notif['type']?.toString();
      final isRead = notif['is_read'] == 1;
      if (type != 'review_request' || isRead) continue;

      final idRaw = notif['id_notification'];
      final notifId = _toInt(idRaw);
      if (notifId == null || pushedIds.contains(notifId)) continue;

      final message = notif['message']?.toString() ??
          'Votre location est terminée, laissez un avis sur votre bien meublé.';

      await _localNotifications.show(
        notifId,
        'Nestvia - Avis demandé',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'review_request_channel',
            'Demandes d\'avis',
            channelDescription:
                'Notifications de fin de location pour laisser un avis',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );

      pushedIds.add(notifId);
    }

    await _savePushedReviewIds(pushedIds);
  }

  Future<Set<int>> _loadPushedReviewIds() async {
    final raw = await _storage.read(key: _pushedReviewNotificationsKey);
    if (raw == null || raw.trim().isEmpty) return <int>{};

    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  Future<void> _savePushedReviewIds(Set<int> ids) async {
    final serialized = ids.join(',');
    await _storage.write(key: _pushedReviewNotificationsKey, value: serialized);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// Nombre de notifications non lues
  Future<int> getUnreadCount() async {
    final notifs = await getNotifications();
    return notifs.where((n) => n['is_read'] == 0).length;
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
      if (n['is_read'] == 0) {
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
