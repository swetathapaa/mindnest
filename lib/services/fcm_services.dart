import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

/// Top-level function to handle background messages.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('🔕 [Background] Title: ${message.notification?.title}');
  log('🔕 [Background] Body: ${message.notification?.body}');
  log('📦 [Background] Data: ${message.data}');
  await NotificationService().showNotification(message: message);
}

/// A service class for managing Firebase Cloud Messaging (FCM) operations.
class FCMServices {
  /// Initializes Firebase Cloud Messaging (FCM) for the current device.
  Future<void> initializeCloudMessaging() => Future.wait([
    FirebaseMessaging.instance.requestPermission(),
    FirebaseMessaging.instance.setAutoInitEnabled(true),
  ]);

  /// Retrieves the default FCM token for the current device.
  Future<String?> getFCMToken() => FirebaseMessaging.instance.getToken();

  /// Sets up listeners for Firebase Cloud Messaging (FCM) messages.
  void listenFCMMessage(BackgroundMessageHandler handler) {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleFCMMessage);

    // Background/terminated messages
    FirebaseMessaging.onBackgroundMessage(handler);

    // When user taps on notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log("📲 [OpenedApp] Title: ${message.notification?.title}");
      log("📲 [OpenedApp] Body: ${message.notification?.body}");
      log("📲 [OpenedApp] Data: ${message.data}");
      NotificationService().onClickToNotification(
        jsonEncode({
          'title': message.notification?.title,
          'body': message.notification?.body,
        }),
      );
    });
  }

  /// Handles foreground FCM messages.
  Future<void> _handleFCMMessage(RemoteMessage message) async {
    log('🔔 [Foreground] Title: ${message.notification?.title}');
    log('🔔 [Foreground] Body: ${message.notification?.body}');
    log('📦 [Foreground] Data: ${message.data}');
    await NotificationService().showNotification(message: message);
  }
}
