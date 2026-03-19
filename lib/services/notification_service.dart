// Issue #20 - [CF-NOTIFS] : Service de gestion des notifications
// Issue #21 - [CF-NOTIFS] : Dépôt d'avis
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Récupère les notifications de l'utilisateur
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response =
          await ApiService().client.get(ApiConfig.notificationsEndpoint);
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (_) {
      return [];
    }
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
