import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings);
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> show({required int id, required String title, required String body}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'academy_updates',
        'Academy updates',
        channelDescription: 'New files, videos and academy updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await plugin.show(id, title, body, details);
  }
}
