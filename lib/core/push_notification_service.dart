import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'toast_utils.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundPushMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationPreferences {
  const NotificationPreferences({
    this.multiplayerTurns = true,
    this.rankedMatches = true,
    this.dailyReminders = true,
  });

  final bool multiplayerTurns;
  final bool rankedMatches;
  final bool dailyReminders;

  factory NotificationPreferences.fromJson(Map<String, dynamic>? json) {
    return NotificationPreferences(
      multiplayerTurns: json?['multiplayer_turns'] as bool? ?? true,
      rankedMatches: json?['ranked_matches'] as bool? ?? true,
      dailyReminders: json?['daily_reminders'] as bool? ?? true,
    );
  }

  Map<String, bool> toJson() => {
    'multiplayer_turns': multiplayerTurns,
    'ranked_matches': rankedMatches,
    'daily_reminders': dailyReminders,
  };

  NotificationPreferences copyWith({
    bool? multiplayerTurns,
    bool? rankedMatches,
    bool? dailyReminders,
  }) => NotificationPreferences(
    multiplayerTurns: multiplayerTurns ?? this.multiplayerTurns,
    rankedMatches: rankedMatches ?? this.rankedMatches,
    dailyReminders: dailyReminders ?? this.dailyReminders,
  );
}

class PushNavigation {
  const PushNavigation({required this.event, this.gameId});

  final String event;
  final String? gameId;

  factory PushNavigation.fromMessage(RemoteMessage message) => PushNavigation(
    event: message.data['event'] ?? '',
    gameId: message.data['game_id'],
  );
}

/// Owns the device token and notification settings. The server remains the
/// source of truth for which game events may result in a notification.
class PushNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final ValueNotifier<PushNavigation?> pendingNavigation =
      ValueNotifier<PushNavigation?>(null);

  static StreamSubscription<AuthState>? _authSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static String? _token;
  static bool _initialized = false;

  static bool get isSignedIn {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      return user != null && !user.isAnonymous;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(handleBackgroundPushMessage);
      final messaging = FirebaseMessaging.instance;

      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((event) async {
            if (event.event == AuthChangeEvent.signedOut) {
              await _removeCurrentDeviceToken();
              return;
            }
            if (event.session?.user.isAnonymous == false) {
              await _ensurePermissionAndRegister();
            }
          });
      _tokenSubscription = messaging.onTokenRefresh.listen((token) async {
        _token = token;
        await _registerCurrentToken();
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotice,
      );

      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpenedMessage(initial);
      await _registerCurrentToken();
    } catch (error) {
      // Notifications are optional; the rest of the game must remain usable.
      debugPrint('Push notification setup unavailable: $error');
    }
  }

  static Future<NotificationSettings> permissionStatus() =>
      FirebaseMessaging.instance.getNotificationSettings();

  static Future<bool> requestPermissionAndRegister() async {
    if (!isSignedIn) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) await _registerCurrentToken();
      return granted;
    } catch (error) {
      debugPrint('Unable to request notifications: $error');
      return false;
    }
  }

  static Future<void> _ensurePermissionAndRegister() async {
    if (!isSignedIn) return;
    final settings = await permissionStatus();
    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (allowed) {
      await _registerCurrentToken();
      return;
    }
    await requestPermissionAndRegister();
  }

  static Future<NotificationPreferences> loadPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous)
      return const NotificationPreferences();
    final row = await Supabase.instance.client
        .from('notification_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return NotificationPreferences.fromJson(row);
  }

  static Future<void> savePreferences(
    NotificationPreferences preferences,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    await Supabase.instance.client.from('notification_preferences').upsert({
      'user_id': user.id,
      ...preferences.toJson(),
    }, onConflict: 'user_id');
  }

  /// Must run while the user still has an authenticated Supabase session.
  static Future<void> unregisterCurrentDevice() => _removeCurrentDeviceToken();

  static Future<void> _registerCurrentToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    _token ??= await FirebaseMessaging.instance.getToken();
    if (_token == null) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    await Supabase.instance.client.from('push_devices').upsert({
      'user_id': user.id,
      'token': _token,
      'platform': platform,
      'app_id': 'letterloom',
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  static Future<void> _removeCurrentDeviceToken() async {
    _token ??= await FirebaseMessaging.instance.getToken();
    if (_token == null) return;
    try {
      await Supabase.instance.client
          .from('push_devices')
          .delete()
          .eq('token', _token!);
    } catch (error) {
      debugPrint('Unable to unregister push device: $error');
    }
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    pendingNavigation.value = PushNavigation.fromMessage(message);
  }

  static void _showForegroundNotice(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    final notification = message.notification;
    if (context == null || notification == null) return;
    ToastUtils.showNotification(
      context,
      notification.body ?? notification.title ?? 'New LetterLoom update',
      onOpen: () => _handleOpenedMessage(message),
    );
  }

  static void dispose() {
    _authSubscription?.cancel();
    _tokenSubscription?.cancel();
    _openedSubscription?.cancel();
    _foregroundSubscription?.cancel();
  }
}
