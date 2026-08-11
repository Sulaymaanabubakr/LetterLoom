import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_config.dart';
import '../../core/google_play_games_service.dart';
import '../../core/supabase_bootstrap.dart';

class LeaderboardEntry {
  final int rank;
  final String username;
  final String displayName;
  final String avatarId;
  final String countryCode;
  final int score;
  final String tier;
  final bool isCurrentPlayer;

  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.displayName,
    required this.avatarId,
    required this.countryCode,
    required this.score,
    required this.tier,
    this.isCurrentPlayer = false,
  });
}

class LeaderboardsService {
  /// Fetches in-app leaderboard entries for specified category.
  static Future<List<LeaderboardEntry>> fetchLeaderboard({
    required String category, // 'rating', 'wins', 'game_score', 'turn_score', 'daily'
    required String currentUserId,
  }) async {
    final List<LeaderboardEntry> results = [];

    if (SupabaseBootstrap.configured) {
      try {
        String column = 'ranked_rating';
        if (category == 'wins') column = 'wins';
        if (category == 'game_score') column = 'highest_score';

        final response = await Supabase.instance.client
            .from('player_profiles')
            .select()
            .order(column, ascending: false)
            .limit(50);

        int pos = 1;
        for (var row in response) {
          final scoreVal = (row[column] as int?) ?? 0;
          final userId = row['id'] as String? ?? '';
          final rating = (row['ranked_rating'] as int?) ?? AppConfig.defaultRankedRating;

          results.add(LeaderboardEntry(
            rank: pos++,
            username: row['username'] as String? ?? 'Gamer',
            displayName: row['display_name'] as String? ?? 'Gamer',
            avatarId: row['avatar_id'] as String? ?? 'avatar_owl',
            countryCode: row['country_code'] as String? ?? 'US',
            score: scoreVal,
            tier: AppConfig.getRankedTier(rating),
            isCurrentPlayer: userId == currentUserId,
          ));
        }
      } catch (e) {
        debugPrint('[Leaderboards] Supabase fetch error: $e');
      }
    }

    // Never present fabricated leaderboard rows as live competitive data.
    return results;
  }

  static Future<void> submitScore(String category, int score) async {
    await GooglePlayGamesService().submitLeaderboardScore(category, score);
  }
}
