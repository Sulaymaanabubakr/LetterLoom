import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/features/multiplayer/multiplayer_repository.dart';

void main() {
  test('multiplayer snapshots ignore disclosed tile identities', () {
    final snapshot = MultiplayerStateSnapshot.fromJson({
      'game': {
        'id': 'game-1',
        'room_code': 'ABC123',
        'status': 'active',
        'mode': 'casual',
        'created_by_user_id': 'user-1',
        'board': const [],
        'player_one_score': 0,
        'player_two_score': 0,
        'consecutive_passes': 0,
        'move_number': 0,
        'created_at': '2026-08-12T00:00:00.000Z',
        'updated_at': '2026-08-12T00:00:00.000Z',
      },
      'tile_count': 42,
      'tile_bag': [
        {'id': 'secret-z', 'letter': 'Z', 'scoreValue': 10},
      ],
    });

    expect(snapshot.tileCount, 42);
  });
}
