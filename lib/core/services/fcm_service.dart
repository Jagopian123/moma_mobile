import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';
import 'notification_navigator.dart';
import 'notification_service.dart';

// Handler background — harus top-level function
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // System otomatis tampilkan notifikasi di tray — tidak perlu action manual
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Foreground: FCM tidak auto-tampil → tampilkan manual via local notifications
    FirebaseMessaging.onMessage.listen((message) {
      final notif = message.notification;
      if (notif == null) return;
      NotificationService.showInstantNotification(
        title: notif.title ?? '',
        body: notif.body ?? '',
        payload: message.data['route'] as String?,
      );
    });

    // App di background → navigate via home agar shell ter-render dulu
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationNavigator.handleRoute(message.data['route'] as String?);
    });

    // App di-kill → shell belum siap → queue, dikonsumsi HomePage setelah shell siap
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      NotificationNavigator.queueRoute(initial.data['route'] as String?);
    }

    // Token bisa berubah — kirim ulang ke server kalau berubah
    _messaging.onTokenRefresh.listen((token) {
      _sendTokenToServer(token);
    });
  }

  static Future<void> sendTokenToServer() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _sendTokenToServer(token);
  }

  static Future<void> deleteTokenFromServer() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await ApiService().delete('/fcm/token', data: {'token': token});
      }
    } catch (_) {}
    await _messaging.deleteToken();
  }

  static Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiService().post('/fcm/token', data: {'token': token});
    } catch (_) {}
  }
}
