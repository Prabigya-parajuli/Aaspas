// Notification service placeholder
// Real notifications handled by fcm_service.dart
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
}