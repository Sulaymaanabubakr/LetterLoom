import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_bootstrap.dart';
import '../../models/achievement.dart';
import '../../models/game_settings.dart';
import '../../models/game_state.dart';
import '../../models/player_profile.dart';
import '../../models/statistics.dart';

@immutable
class AccountProgressSnapshot {
  final Statistics? statistics;
  final GameSettings? settings;
  final GameState? activeGame;
  final List<Map<String, dynamic>> achievements;

  const AccountProgressSnapshot({
    this.statistics,
    this.settings,
    this.activeGame,
    this.achievements = const [],
  });
}

/// Account-scoped persistence for non-competitive local game data. Server-owned
/// wallets, ranked state, daily rewards, and multiplayer state use their own
/// authoritative endpoints and are intentionally not mirrored here.
class AccountProgressService {
  static final AccountProgressService instance = AccountProgressService._();
  AccountProgressService._();

  bool get isAuthenticated {
    final user = SupabaseBootstrap.configured
        ? Supabase.instance.client.auth.currentUser
        : null;
    return user != null && !user.isAnonymous;
  }

  Future<AccountProgressSnapshot?> load() async {
    if (!isAuthenticated) return null;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'player-progress',
        body: const {'action': 'get'},
      );
      final data = response.data;
      if (data is! Map) return null;
      final rawProgress = data['progress'];
      final progress = rawProgress is Map
          ? Map<String, dynamic>.from(rawProgress)
          : null;
      final rawAchievements = data['achievements'];
      final achievements = rawAchievements is List
          ? rawAchievements
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const <Map<String, dynamic>>[];
      if (progress == null && achievements.isEmpty) return null;
      return AccountProgressSnapshot(
        statistics: progress?['statistics'] is Map
            ? Statistics.fromJson(Map<String, dynamic>.from(progress!['statistics'] as Map))
            : null,
        settings: progress?['settings'] is Map
            ? GameSettings.fromJson(Map<String, dynamic>.from(progress!['settings'] as Map))
            : null,
        activeGame: progress?['active_game'] is Map
            ? GameState.fromJson(Map<String, dynamic>.from(progress!['active_game'] as Map))
            : null,
        achievements: achievements,
      );
    } catch (error) {
      debugPrint('[AccountProgress] Load failed: $error');
      return null;
    }
  }

  Future<void> saveProgress({
    required Statistics statistics,
    required GameSettings settings,
    GameState? activeGame,
  }) async {
    if (!isAuthenticated) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'player-progress',
        body: {
          'action': 'save',
          'statistics': statistics.toJson(),
          'settings': settings.toJson(),
          'active_game': activeGame?.toJson(),
        },
      );
    } catch (error) {
      debugPrint('[AccountProgress] Save failed: $error');
    }
  }

  Future<void> saveAchievements(List<Achievement> achievements) async {
    if (!isAuthenticated) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'player-progress',
        body: {
          'action': 'save_achievements',
          'achievements': achievements.map((item) => item.toJson()).toList(),
        },
      );
    } catch (error) {
      debugPrint('[AccountProgress] Achievement save failed: $error');
    }
  }

  Future<PlayerProfile?> recordSoloResult({
    required String eventKey,
    required String result,
    required int score,
    required int xp,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'player-progress',
        body: {
          'action': 'solo_result',
          'event_key': eventKey,
          'result': result,
          'score': score,
          'xp': xp,
        },
      );
      final raw = response.data is Map ? response.data['result'] : null;
      final profile = raw is Map ? raw['profile'] : null;
      return profile is Map
          ? PlayerProfile.fromJson(Map<String, dynamic>.from(profile))
          : null;
    } catch (error) {
      debugPrint('[AccountProgress] Result save failed: $error');
      return null;
    }
  }

  Future<PlayerProfile?> grantXp({
    required String eventKey,
    required int amount,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'player-progress',
        body: {'action': 'grant_xp', 'event_key': eventKey, 'amount': amount},
      );
      final raw = response.data is Map ? response.data['result'] : null;
      final profile = raw is Map ? raw['profile'] : null;
      return profile is Map
          ? PlayerProfile.fromJson(Map<String, dynamic>.from(profile))
          : null;
    } catch (error) {
      debugPrint('[AccountProgress] XP save failed: $error');
      return null;
    }
  }
}
