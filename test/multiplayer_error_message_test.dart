import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:letterloom/features/multiplayer/multiplayer_error_message.dart';

void main() {
  test('uses the backend player-safe error message', () {
    expect(
      multiplayerErrorMessage(
        const FunctionsHttpException(
          status: 400,
          details: {'error': 'Sign in with Google to use online features.'},
        ),
      ),
      'Sign in with Google to use online features.',
    );
  });

  test('does not expose a raw transport error', () {
    expect(
      multiplayerErrorMessage(
        const FunctionsHttpException(status: 401, details: {'reason': 'bad'}),
      ),
      'Sign in with Google to use Multiplayer.',
    );
  });
}
