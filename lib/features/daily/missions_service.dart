import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../storage/persistence_manager.dart';
import '../../core/supabase_bootstrap.dart';
import '../progression/progression_service.dart';
import '../hints/hint_service.dart';

@immutable
class Mission {
  final String id;
  final String title;
  final String description;
  final bool isWeekly;
  final int targetValue;
  final int currentValue;
  final bool isCompleted;
  final int xpReward;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.isWeekly,
    required this.targetValue,
    this.currentValue = 0,
    this.isCompleted = false,
    required this.xpReward,
  });

  Mission copyWith({
    int? currentValue,
    bool? isCompleted,
  }) {
    return Mission(
      id: id,
      title: title,
      description: description,
      isWeekly: isWeekly,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      isCompleted: isCompleted ?? this.isCompleted,
      xpReward: xpReward,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'currentValue': currentValue,
        'isCompleted': isCompleted,
      };
}

final missionsProvider = StateNotifierProvider<MissionsNotifier, List<Mission>>((ref) {
  return MissionsNotifier(ref);
});

class MissionsNotifier extends StateNotifier<List<Mission>> {
  final Ref _ref;
  final PersistenceManager _persistence = PersistenceManager();
  static const String _saveFileName = 'letterloom_missions_v1.json';

  static const List<Mission> defaultMissions = [
    Mission(
      id: 'daily_words',
      title: 'Vocabulary Builder',
      description: 'Play 15 valid words.',
      isWeekly: false,
      targetValue: 15,
      xpReward: 75,
    ),
    Mission(
      id: 'daily_game',
      title: 'Active Loomer',
      description: 'Complete a full match.',
      isWeekly: false,
      targetValue: 1,
      xpReward: 75,
    ),
    Mission(
      id: 'daily_high_turn',
      title: 'High Scorer',
      description: 'Score at least 30 points in one turn.',
      isWeekly: false,
      targetValue: 1,
      xpReward: 75,
    ),
    Mission(
      id: 'weekly_wins',
      title: 'Weekly Master',
      description: 'Win 5 games this week.',
      isWeekly: true,
      targetValue: 5,
      xpReward: 200,
    ),
  ];

  MissionsNotifier(this._ref) : super(defaultMissions) {
    _init();
  }

  Future<void> _init() async {
    final savedData = await _persistence.loadJsonData(_saveFileName);
    if (savedData != null && savedData['missions'] is List) {
      final List rawList = savedData['missions'] as List;
      final Map<String, dynamic> map = {
        for (var item in rawList.whereType<Map>())
          item['id'] as String: Map<String, dynamic>.from(item)
      };

      state = defaultMissions.map((tmpl) {
        if (map.containsKey(tmpl.id)) {
          final m = map[tmpl.id]!;
          return tmpl.copyWith(
            currentValue: m['currentValue'] as int? ?? 0,
            isCompleted: m['isCompleted'] as bool? ?? false,
          );
        }
        return tmpl;
      }).toList();
    }
  }

  Future<void> _save() async {
    await _persistence.saveJsonData(_saveFileName, {
      'missions': state.map((m) => m.toJson()).toList(),
    });
  }

  Future<void> recordProgress(String id, int delta) async {
    final user = SupabaseBootstrap.configured
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (user != null && !user.isAnonymous) return;
    final index = state.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final m = state[index];
    if (m.isCompleted) return;

    final newCurrent = m.currentValue + delta;
    if (newCurrent >= m.targetValue) {
      final completedMission = m.copyWith(currentValue: m.targetValue, isCompleted: true);
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) completedMission else state[i],
      ];
      await _save();
      await _ref.read(progressionProvider).addXP(m.xpReward, reason: 'Mission Completed: ${m.title}');
      await _ref.read(hintServiceProvider.notifier).addPurchasedHints('move', 1);
    } else {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) m.copyWith(currentValue: newCurrent) else state[i],
      ];
      await _save();
    }
  }
}
