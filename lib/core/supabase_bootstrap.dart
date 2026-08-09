import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static bool configured = false;

  static Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

    if (url.isEmpty || publishableKey.isEmpty) {
      debugPrint('Supabase is not configured. Multiplayer is disabled.');
      return;
    }

    await Supabase.initialize(url: url, publishableKey: publishableKey);
    configured = true;

    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        await Supabase.instance.client.auth.signInAnonymously();
      }
    } catch (error) {
      debugPrint('Supabase anonymous auth unavailable: $error');
    }
  }
}
