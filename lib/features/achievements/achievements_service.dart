import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/achievement.dart';
import '../../storage/persistence_manager.dart';
import '../../core/google_play_games_service.dart';
import '../progression/progression_service.dart';
import '../../core/supabase_bootstrap.dart';
import 'achievements_registry.dart';

final achievementsProvider =
    StateNotifierProvider<AchievementsNotifier, List<Achievement>>((ref) {
  return AchievementsNotifier(ref);
});

class AchievementsNotifier extends StateNotifier<List<Achievement>> {
  final Ref _ref;
  final PersistenceManager _persistence = PersistenceManager();
  static const String _saveFileName = 'letterloom_achievements_v1.json';

  AchievementsNotifier(this._ref) : super(AchievementsRegistry.allAchievements) {
    _init();
  }

  bool get _isAuthenticatedAccount {
    final user = SupabaseBootstrap.configured
        ? Supabase.instance.client.auth.currentUser
        : null;
    return user != null && !user.isAnonymous;
  }

  Future<void> _init() async {
    final savedData = await _persistence.loadJsonData(_saveFileName);
    if (savedData != null && savedData['achievements'] is List) {
      final List rawList = savedData['achievements'] as List;
      final Map<String, dynamic> map = {
        for (var item in rawList.whereType<Map>())
          item['id'] as String: Map<String, dynamic>.from(item)
      };

      state = AchievementsRegistry.allAchievements.map((tmpl) {
        if (map.containsKey(tmpl.id)) {
          return Achievement.fromJson(map[tmpl.id]!, tmpl);
        }
        return tmpl;
      }).toList();
    }
  }

  Future<void> _save() async {
    final data = {
      'achievements': state.map((a) => a.toJson()).toList(),
    };
    await _persistence.saveJsonData(_saveFileName, data);
  }

  Future<void> _unlock(Achievement achievement) async {
    if (achievement.isUnlocked) return;

    final updated = achievement.copyWith(
      currentValue: achievement.targetValue,
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );

    state = [
      for (final a in state)
        if (a.id == achievement.id) updated else a,
    ];

    await _save();
    await _ref.read(progressionProvider).addXP(
          achievement.xpReward,
          reason: 'Achievement Unlocked: ${achievement.title}',
        );
    await GooglePlayGamesService().unlockAchievement(achievement.id);
  }

  Future<void> _incrementProgress(String id, int delta) async {
    final index = state.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final a = state[index];
    if (a.isUnlocked) return;

    final newCurrent = a.currentValue + delta;
    if (newCurrent >= a.targetValue) {
      await _unlock(a);
    } else {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) a.copyWith(currentValue: newCurrent) else state[i],
      ];
      await _save();
    }
  }

  /// Triggers evaluation when a player turn is placed.
  Future<void> recordTurn({
    required int score,
    required bool isBingo,
    required int validWordsFormed,
  }) async {
    if (_isAuthenticatedAccount) return;
    if (isBingo) {
      final bingoAch = state.firstWhere((a) => a.id == 'first_bingo');
      await _unlock(bingoAch);
      await _incrementProgress('bingo_master', 1);
    }

    if (score >= 50) {
      final bigMoveAch = state.firstWhere((a) => a.id == 'big_move');
      await _unlock(bigMoveAch);
    }

    if (validWordsFormed > 0) {
      await _incrementProgress('wordsmith', validWordsFormed);
    }
  }

  /// Triggers evaluation when a game completes.
  Future<void> recordGameFinished({
    required bool isWin,
    required int playerScore,
    required int opponentScore,
    required String difficulty,
    required bool isRanked,
    required bool wasTrailing30,
    required int currentWinStreak,
  }) async {
    if (_isAuthenticatedAccount) return;
    await _incrementProgress('veteran', 1);

    if (playerScore >= 300) {
      final tripleCentury = state.firstWhere((a) => a.id == 'triple_century');
      await _unlock(tripleCentury);
    }

    if (isRanked) {
      final rankedDebut = state.firstWhere((a) => a.id == 'ranked_debut');
      await _unlock(rankedDebut);
    }

    if (isWin) {
      final firstVic = state.firstWhere((a) => a.id == 'first_victory');
      await _unlock(firstVic);

      await _incrementProgress('champion', 1);
      await _incrementProgress('century_champion', 1);

      if (difficulty.toLowerCase() == 'hard') {
        final hardEarned = state.firstWhere((a) => a.id == 'hard_earned');
        await _unlock(hardEarned);
      }

      if ((playerScore - opponentScore).abs() <= 5) {
        final closeCall = state.firstWhere((a) => a.id == 'close_call');
        await _unlock(closeCall);
      }

      if (wasTrailing30) {
        final comeback = state.firstWhere((a) => a.id == 'comeback');
        await _unlock(comeback);
      }

      if (currentWinStreak >= 5) {
        final streakAch = state.firstWhere((a) => a.id == 'winning_streak');
        await _unlock(streakAch);
      }
    }
  }

  Future<void> recordStreak(int streakDays) async {
    if (_isAuthenticatedAccount) return;
    if (streakDays >= 7) {
      final sevenDay = state.firstWhere((a) => a.id == 'seven_day_streak');
      await _unlock(sevenDay);
    }
  }

  Future<void> recordRankedPromotion() async {
    if (_isAuthenticatedAccount) return;
    final promotionAch = state.firstWhere((a) => a.id == 'moving_up');
    await _unlock(promotionAch);
  }
}
