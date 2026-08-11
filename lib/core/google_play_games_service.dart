import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'app_config.dart';

/// Integration wrapper for Google Play Games Services.
///
/// Designed to fail gracefully when Play Games is unconfigured, disabled,
/// or running on unsupported platforms (e.g. iOS / Desktop / Web).
class GooglePlayGamesService {
  static final GooglePlayGamesService _instance =
      GooglePlayGamesService._internal();
  factory GooglePlayGamesService() => _instance;
  GooglePlayGamesService._internal();

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  /// Attempt silent sign in to Google Play Games Services.
  Future<void> signInSilently() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final result = await GameAuth.signIn();
      _isSignedIn = result != null && await GameAuth.isSignedIn;
    } catch (error) {
      _isSignedIn = false;
      debugPrint('[PlayGames] Sign-in unavailable: $error');
    }
  }

  /// Report an unlocked internal achievement to Google Play Games if mapped.
  Future<void> unlockAchievement(String internalAchievementId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final playGamesId =
        AppConfig.playGamesAchievementsMap[internalAchievementId];
    if (playGamesId == null || playGamesId.contains('PLACEHOLDER')) {
      debugPrint(
        '[PlayGames] Achievement $internalAchievementId uses placeholder config.',
      );
      return;
    }

    if (!_isSignedIn) return;
    try {
      await Achievements.unlock(
        achievement: Achievement(androidID: playGamesId),
      );
    } catch (error) {
      debugPrint('[PlayGames] Achievement submission failed: $error');
    }
  }

  /// Submit score to Google Play Games Leaderboard if mapped.
  Future<void> submitLeaderboardScore(String leaderboardKey, int score) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final leaderboardId = AppConfig.playGamesLeaderboardsMap[leaderboardKey];
    if (leaderboardId == null || leaderboardId.contains('PLACEHOLDER')) {
      debugPrint(
        '[PlayGames] Leaderboard $leaderboardKey uses placeholder config.',
      );
      return;
    }

    if (!_isSignedIn) return;
    try {
      await Leaderboards.submitScore(
        score: Score(androidLeaderboardID: leaderboardId, value: score),
      );
    } catch (error) {
      debugPrint('[PlayGames] Leaderboard submission failed: $error');
    }
  }
}
