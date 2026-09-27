import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background FCM notification message handled by Android OS system tray
  if (kDebugMode) {
    print('FCM background message: ${message.messageId} | ${message.notification?.title}');
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  String? _currentToken;
  String? get currentToken => _currentToken;
  bool _initialized = false;

  void Function(RemoteMessage)? onNotificationTapped;
  void Function(RemoteMessage)? onForegroundNotificationReceived;
  void Function(String)? onTokenRefreshed;

  Future<bool> initFirebase() async {
    if (_initialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        const apiKey = String.fromEnvironment(
          'FIREBASE_API_KEY',
          defaultValue: 'AIzaSyD0-opnNKAHXj_Wo7JCLPMSefDFOW8DfNs',
        );
        const appId = String.fromEnvironment(
          'FIREBASE_APP_ID',
          defaultValue: '1:267791632831:android:dbfdd016a7c10ea503f90a',
        );
        const senderId = String.fromEnvironment(
          'FIREBASE_SENDER_ID',
          defaultValue: '267791632831',
        );
        const projectId = String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'registration-a6358',
        );

        try {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: apiKey,
              appId: appId,
              messagingSenderId: senderId,
              projectId: projectId,
              storageBucket: 'registration-a6358.firebasestorage.app',
            ),
          );
        } catch (_) {
          try {
            await Firebase.initializeApp();
          } catch (_) {
            return false;
          }
        }
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _initialized = true;
      return true;
    } catch (e) {
      if (kDebugMode) print('Firebase initialization skipped/failed: $e');
      return false;
    }
  }

  Future<String?> initAndGetToken() async {
    final ready = await initFirebase();
    if (!ready) return null;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request POST_NOTIFICATIONS permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        print('FCM notification permission status: ${settings.authorizationStatus}');
      }

      // 2. Fetch FCM registration token
      _currentToken = await messaging.getToken();

      // 3. Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        onTokenRefreshed?.call(newToken);
      });

      // 4. Foreground message listener (updates in-app notification state without duplicate local alert)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        onForegroundNotificationReceived?.call(message);
      });

      // 5. Notification tapped while app in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        onNotificationTapped?.call(message);
      });

      // 6. Notification tapped from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        onNotificationTapped?.call(initialMessage);
      }

      return _currentToken;
    } catch (e) {
      if (kDebugMode) print('FCM registration skipped/failed: $e');
      return null;
    }
  }
}
