import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../game_engine/game_config.dart';
import '../../ai/ai_engine.dart';
import '../../storage/persistence_manager.dart';

@immutable
class DailyChallengeState {
  final String dateStr;
  final bool isCompleted;
  final int scoreAchieved;
  final int bestPossibleScore;
  final int starRating;
  final int streakDays;

  const DailyChallengeState({
    required this.dateStr,
    required this.isCompleted,
    required this.scoreAchieved,
    required this.bestPossibleScore,
    required this.starRating,
    required this.streakDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'dateStr': dateStr,
      'isCompleted': isCompleted,
      'scoreAchieved': scoreAchieved,
      'bestPossibleScore': bestPossibleScore,
      'starRating': starRating,
      'streakDays': streakDays,
    };
  }

  factory DailyChallengeState.fromJson(Map<String, dynamic> json) {
    return DailyChallengeState(
      dateStr: json['dateStr'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      scoreAchieved: json['scoreAchieved'] as int? ?? 0,
      bestPossibleScore: json['bestPossibleScore'] as int? ?? 0,
      starRating: json['starRating'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
    );
  }
}

class DailyChallengeData {
  final String dateStr;
  final List<List<BoardCell>> boardGrid;
  final List<Tile> rack;
  final int optimalScore;

  const DailyChallengeData({
    required this.dateStr,
    required this.boardGrid,
    required this.rack,
    required this.optimalScore,
  });
}

class DailyChallengeService {
  static final PersistenceManager _persistence = PersistenceManager();
  static const String _saveFileName = 'letterloom_daily_challenge_v1.json';

  static String getTodayString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Generates the deterministic daily challenge puzzle for the given date string.
  static DailyChallengeData generatePuzzle([String? customDateStr]) {
    final dateStr = customDateStr ?? getTodayString();
    // String.hashCode is not a persistence/interop contract. Use a stable
    // 32-bit hash so every client generates the same puzzle for a date.
    var seed = 2166136261;
    for (final codeUnit in dateStr.codeUnits) {
      seed = ((seed ^ codeUnit) * 16777619) & 0x7fffffff;
    }
    final rand = Random(seed);

    // Initial empty board grid
    final grid = List.generate(GameConfig.boardSize, (r) {
      return List.generate(GameConfig.boardSize, (c) {
        return BoardCell(
          row: r,
          col: c,
          type: GameConfig.getCellTypeAt(r, c),
        );
      });
    });

    // Place a deterministic seed word on center (e.g. 'LOOM')
    const seedWord = 'LOOM';
    for (int i = 0; i < seedWord.length; i++) {
      final letter = seedWord[i];
      grid[7][6 + i] = grid[7][6 + i].copyWith(
        tile: Tile(
          id: 'seed_$i',
          letter: letter,
          scoreValue: GameConfig.letterScores[letter] ?? 1,
        ),
        isNewPlacement: false,
      );
    }

    // Generate deterministic 7-tile rack
    const vowels = ['A', 'E', 'I', 'O', 'U'];
    const consonants = ['B', 'C', 'D', 'F', 'G', 'H', 'L', 'M', 'N', 'P', 'R', 'S', 'T', 'W'];

    final rack = <Tile>[];
    for (int i = 0; i < 3; i++) {
      final l = vowels[rand.nextInt(vowels.length)];
      rack.add(Tile(id: 'rack_v_$i', letter: l, scoreValue: GameConfig.letterScores[l] ?? 1));
    }
    for (int i = 0; i < 4; i++) {
      final l = consonants[rand.nextInt(consonants.length)];
      rack.add(Tile(id: 'rack_c_$i', letter: l, scoreValue: GameConfig.letterScores[l] ?? 1));
    }

    // Compute optimal move score using AI solver
    final aiMoveRaw = AIEngine.computeMove({
      'board': grid.map((r) => r.map((c) => c.toJson()).toList()).toList(),
      'rack': rack.map((t) => t.toJson()).toList(),
      'difficulty': 'hard',
      'deterministic': true,
    });

    final aiMove = AIMove.fromJson(aiMoveRaw);
    final optimalScore = aiMove.isPass || aiMove.isExchange ? 0 : aiMove.score;

    return DailyChallengeData(
      dateStr: dateStr,
      boardGrid: grid,
      rack: rack,
      optimalScore: optimalScore,
    );
  }

  static Future<DailyChallengeState> loadState() async {
    final todayStr = getTodayString();
    final json = await _persistence.loadJsonData(_saveFileName);
    if (json != null) {
      final state = DailyChallengeState.fromJson(json);
      if (state.dateStr == todayStr) {
        return state;
      } else {
        // New day: maintain streak if consecutive
        final isYesterday = _isYesterday(state.dateStr);
        final streak = isYesterday ? state.streakDays : 0;
        return DailyChallengeState(
          dateStr: todayStr,
          isCompleted: false,
          scoreAchieved: 0,
          bestPossibleScore: 0,
          starRating: 0,
          streakDays: streak,
        );
      }
    }
    return DailyChallengeState(
      dateStr: todayStr,
      isCompleted: false,
      scoreAchieved: 0,
      bestPossibleScore: 0,
      starRating: 0,
      streakDays: 0,
    );
  }

  static Future<void> saveState(DailyChallengeState state) async {
    await _persistence.saveJsonData(_saveFileName, state.toJson());
  }

  static bool _isYesterday(String prevDateStr) {
    try {
      final parts = prevDateStr.split('-');
      final prev = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now().toUtc();
      final diff = DateTime(now.year, now.month, now.day).difference(prev).inDays;
      return diff == 1;
    } catch (_) {
      return false;
    }
  }
}
