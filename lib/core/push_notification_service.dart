import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundPushMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(handleBackgroundPushMessage);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) {
        if (Supabase.instance.client.auth.currentUser != null) {
          await _registerToken(token);
        } else {
          final authSubscription = Supabase
              .instance
              .client
              .auth
              .onAuthStateChange
              .listen((event) async {
                if (event.session != null) {
                  await _registerToken(token);
                }
              });
          unawaited(
            Future<void>.delayed(
              const Duration(minutes: 2),
              authSubscription.cancel,
            ),
          );
        }
      }
      messaging.onTokenRefresh.listen(_registerToken);
    } catch (error) {
      debugPrint('Push notification setup unavailable: $error');
    }
  }

  static Future<void> _registerToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    await Supabase.instance.client.from('push_devices').upsert({
      'user_id': user.id,
      'token': token,
      'platform': platform,
      'app_id': 'letterloom',
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }
}
