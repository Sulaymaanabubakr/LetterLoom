import 'package:supabase_flutter/supabase_flutter.dart';

import 'multiplayer_repository.dart';

/// Converts transport exceptions into copy that is safe to show to players.
String multiplayerErrorMessage(Object error) {
  if (error is MultiplayerException) return error.message;
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }
    if (error.status == 401 || error.status == 403) {
      return 'Sign in with Google to use Multiplayer.';
    }
    if (error.status == 0) {
      return 'Unable to reach online play. Check your connection and try again.';
    }
  }
  return 'Online play is temporarily unavailable. Please try again.';
}
