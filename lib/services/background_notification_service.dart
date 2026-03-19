import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import '../config/api_config.dart';

class BackgroundNotificationService {
  static const String periodicTaskName = 'nestvia_notifications_periodic_check';
  static const String _pushedNotificationsKey = 'pushed_notifications';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Minimum Android: 15 minutes.
    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != BackgroundNotificationService.periodicTaskName) {
      return true;
    }

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await localNotifications.initialize(settings);

    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final token = await _loadAccessTokenWithRefresh();
    if (token == null || token.isEmpty) return true;

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    try {
      final response = await dio.get(ApiConfig.notificationsEndpoint);
      final raw = response.data;
      if (raw is! List) return true;

      final notifications = raw.cast<Map<String, dynamic>>();
      final pushedKeys = await _loadPushedNotificationKeys();

      for (final notif in notifications) {
        if (_isRead(notif['is_read'])) continue;

        final uniqueKey = _notificationUniqueKey(notif);
        if (pushedKeys.contains(uniqueKey)) continue;

        final id = _notificationId(notif);
        final type = notif['type']?.toString();
        final title = _notificationTitle(type);
        final message = _notificationMessage(type, notif);

        await localNotifications.show(
          id,
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
    } catch (_) {
      // Le worker ne doit pas échouer bruyamment; on retentera au prochain cycle.
    }

    return true;
  });
}

Future<String?> _loadAccessTokenWithRefresh() async {
  final token = await BackgroundNotificationService._storage.read(
    key: BackgroundNotificationService._tokenKey,
  );
  if (token != null && token.isNotEmpty) return token;

  final refreshToken = await BackgroundNotificationService._storage.read(
    key: BackgroundNotificationService._refreshTokenKey,
  );
  if (refreshToken == null || refreshToken.isEmpty) return null;

  final dioNoAuth = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  try {
    final response = await dioNoAuth.post(
      ApiConfig.refreshEndpoint,
      data: {'refresh_token': refreshToken},
    );
    final data = response.data;
    if (data is! Map) return null;

    final newToken = data['token']?.toString();
    final newRefreshToken = data['refresh_token']?.toString();
    final refreshExpiresAt = data['refresh_expires_at']?.toString();

    if (newToken == null || newToken.isEmpty) return null;

    await BackgroundNotificationService._storage.write(
      key: BackgroundNotificationService._tokenKey,
      value: newToken,
    );
    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      await BackgroundNotificationService._storage.write(
        key: BackgroundNotificationService._refreshTokenKey,
        value: newRefreshToken,
      );
    }
    if (refreshExpiresAt != null && refreshExpiresAt.isNotEmpty) {
      await BackgroundNotificationService._storage.write(
        key: 'refresh_expires_at',
        value: refreshExpiresAt,
      );
    }

    return newToken;
  } catch (_) {
    return null;
  }
}

Future<Set<String>> _loadPushedNotificationKeys() async {
  final raw = await BackgroundNotificationService._storage.read(
    key: BackgroundNotificationService._pushedNotificationsKey,
  );
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
  await BackgroundNotificationService._storage.write(
    key: BackgroundNotificationService._pushedNotificationsKey,
    value: jsonEncode(keys.toList()),
  );
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

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
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
