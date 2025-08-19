import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level function to handle notification tap when app is in the background
/// or terminated.
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(
    NotificationResponse notificationResponse,
    ) => NotificationService().onClickToNotification(
  notificationResponse.payload,
);

/// Service class for handling local notifications.
class NotificationService {
  /// Plugin instance
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Initialize local notifications
  Future<void> initializeLocalNotifications() async {
    // Android initialization with default launcher icon
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const DarwinInitializationSettings initializationSettingsMacOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS,
    );

    // Request iOS permissions
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Initialize plugin and set tap handlers
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveBackgroundNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
  }

  /// Display a notification from a Firebase message
  Future<void> showNotification({required RemoteMessage message}) async {
    log('local notification remote message: ${message.toMap()}');

    const String channelId = 'wellness_channel';
    const String channelName = 'Wellness Notifications';
    const String channelDesc = 'Notifications for wellness updates';

    // Unique ID
    final int notificationId =
        DateTime.now().millisecondsSinceEpoch % 2147483647;

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher', // ✅ Required for Android
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      message.notification?.title ?? message.data['title'] ?? '',
      message.notification?.body ?? message.data['body'] ?? '',
      platformChannelSpecifics,
      payload: json.encode(message.data),
    );
  }

  /// Handle notification tap
  void onClickToNotification(String? data) {
    log("notification payload: $data");
  }
}
