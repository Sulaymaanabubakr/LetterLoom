import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_bootstrap.dart';
import '../../storage/persistence_manager.dart';

@immutable
class DailyWord {
  final String clue;
  final String answer;
  final int answerLength;
  final List<String> letters;

  const DailyWord({
    required this.clue,
    required this.answer,
    int? answerLength,
    required this.letters,
  }) : answerLength = answerLength ?? answer.length;
}

@immutable
class DailyChallengeData {
  final String dateStr;
  final String puzzleId;
  final int difficultyTier;
  final List<DailyWord> words;

  const DailyChallengeData({
    required this.dateStr,
    required this.puzzleId,
    required this.difficultyTier,
    required this.words,
  });

  int get targetScore =>
      words.fold<int>(0, (total, word) => total + word.answerLength);
}

class DailyChallengeRemoteException implements Exception {
  final String message;
  const DailyChallengeRemoteException(this.message);

  @override
  String toString() => message;
}

@immutable
class DailyChallengeState {
  final String dateStr;
  final String puzzleId;
  final bool isCompleted;
  final int scoreAchieved;
  final int bestPossibleScore;
  final int starRating;
  final int streakDays;
  final List<int> solvedWordIndexes;
  final List<String> playedPuzzleIds;
  final int remainingSeconds;
  final bool failed;

  const DailyChallengeState({
    required this.dateStr,
    this.puzzleId = '',
    required this.isCompleted,
    required this.scoreAchieved,
    required this.bestPossibleScore,
    required this.starRating,
    required this.streakDays,
    this.solvedWordIndexes = const [],
    this.playedPuzzleIds = const [],
    this.remainingSeconds = 180,
    this.failed = false,
  });

  Map<String, dynamic> toJson() => {
    'dateStr': dateStr,
    'puzzleId': puzzleId,
    'isCompleted': isCompleted,
    'scoreAchieved': scoreAchieved,
    'bestPossibleScore': bestPossibleScore,
    'starRating': starRating,
    'streakDays': streakDays,
    'solvedWordIndexes': solvedWordIndexes,
    'playedPuzzleIds': playedPuzzleIds,
    'remainingSeconds': remainingSeconds,
    'failed': failed,
  };

  factory DailyChallengeState.fromJson(Map<String, dynamic> json) {
    return DailyChallengeState(
      dateStr: json['dateStr'] as String? ?? '',
      puzzleId: json['puzzleId'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      scoreAchieved: (json['scoreAchieved'] as num?)?.toInt() ?? 0,
      bestPossibleScore: (json['bestPossibleScore'] as num?)?.toInt() ?? 0,
      starRating: (json['starRating'] as num?)?.toInt() ?? 0,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      solvedWordIndexes: _intList(json['solvedWordIndexes']),
      playedPuzzleIds: _stringList(json['playedPuzzleIds']),
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 180,
      failed: json['failed'] as bool? ?? false,
    );
  }

  DailyChallengeState copyWith({int? remainingSeconds, bool? failed}) =>
      DailyChallengeState(
        dateStr: dateStr,
        puzzleId: puzzleId,
        isCompleted: isCompleted,
        scoreAchieved: scoreAchieved,
        bestPossibleScore: bestPossibleScore,
        starRating: starRating,
        streakDays: streakDays,
        solvedWordIndexes: solvedWordIndexes,
        playedPuzzleIds: playedPuzzleIds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        failed: failed ?? this.failed,
      );

  static List<int> _intList(Object? value) => value is List
      ? value.whereType<num>().map((item) => item.toInt()).toList()
      : const [];

  static List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}

class DailyChallengeService {
  static final PersistenceManager _persistence = PersistenceManager();
  static const String _saveFileName = 'letterloom_daily_challenge_v2.json';

  static const List<_PuzzleTemplate> _catalog = [
    _PuzzleTemplate('garden-01', 0, [
      _WordTemplate('A bright object in the sky', 'SUN'),
      _WordTemplate('A hot morning drink', 'TEA'),
      _WordTemplate('A place you live', 'HOME'),
      _WordTemplate('A shining night shape', 'STAR'),
      _WordTemplate('Something you read', 'BOOK'),
      _WordTemplate('Have fun with a game', 'PLAY'),
    ]),
    _PuzzleTemplate('garden-02', 0, [
      _WordTemplate('A small flying insect', 'BEE'),
      _WordTemplate('Frozen water', 'ICE'),
      _WordTemplate('A young dog', 'PUPPY'),
      _WordTemplate('A colorful sky arc', 'RAINBOW'),
      _WordTemplate('A soft sound', 'WHISPER'),
      _WordTemplate('A place with many trees', 'FOREST'),
    ]),
    _PuzzleTemplate('garden-03', 0, [
      _WordTemplate('A fast land animal', 'HORSE'),
      _WordTemplate('A meal eaten at midday', 'LUNCH'),
      _WordTemplate('A sweet baked treat', 'CAKE'),
      _WordTemplate('A body of flowing water', 'RIVER'),
      _WordTemplate('A bright flash in a storm', 'LIGHTNING'),
      _WordTemplate('A place full of flowers', 'GARDEN'),
    ]),
    _PuzzleTemplate('grove-01', 1, [
      _WordTemplate('A path through a place', 'JOURNEY'),
      _WordTemplate('A clear open area', 'BRIGHT'),
      _WordTemplate('A written message', 'LETTER'),
      _WordTemplate('A cold winter crystal', 'FROST'),
      _WordTemplate('A problem to solve', 'PUZZLE'),
      _WordTemplate('A peaceful outdoor space', 'MEADOW'),
    ]),
    _PuzzleTemplate('grove-02', 1, [
      _WordTemplate('A strong desire to know', 'CURIOSITY'),
      _WordTemplate('A careful plan', 'STRATEGY'),
      _WordTemplate('A sudden bright idea', 'INSIGHT'),
      _WordTemplate('A place where books live', 'LIBRARY'),
      _WordTemplate('A long period of time', 'MOMENT'),
      _WordTemplate('A gentle movement of air', 'BREEZE'),
    ]),
    _PuzzleTemplate('grove-03', 1, [
      _WordTemplate('A treasured memory', 'MOMENT'),
      _WordTemplate('A calm feeling', 'SERENITY'),
      _WordTemplate('A helpful answer', 'SOLUTION'),
      _WordTemplate('A shining quality', 'BRILLIANCE'),
      _WordTemplate('A hidden meaning', 'MYSTERY'),
      _WordTemplate('A careful observer', 'WATCHER'),
    ]),
    _PuzzleTemplate('summit-01', 2, [
      _WordTemplate('A soft evening light', 'TWILIGHT'),
      _WordTemplate('A remarkable wonder', 'MARVEL'),
      _WordTemplate('A difficult puzzle', 'ENIGMA'),
      _WordTemplate('A quiet secret', 'WHISPER'),
      _WordTemplate('A long expedition', 'ADVENTURE'),
      _WordTemplate('A clever solution', 'INGENUITY'),
    ]),
    _PuzzleTemplate('summit-02', 2, [
      _WordTemplate('A language expert', 'LINGUIST'),
      _WordTemplate('A strong contrast', 'PARADOX'),
      _WordTemplate('A thoughtful pause', 'REFLECTION'),
      _WordTemplate('A graceful movement', 'ELEGANCE'),
      _WordTemplate('A hidden route', 'PASSAGE'),
      _WordTemplate('A bold undertaking', 'VENTURE'),
    ]),
    _PuzzleTemplate('summit-03', 2, [
      _WordTemplate('A deep understanding', 'WISDOM'),
      _WordTemplate('A winding maze', 'LABYRINTH'),
      _WordTemplate('A persuasive skill', 'ELOQUENCE'),
      _WordTemplate('A rare discovery', 'TREASURE'),
      _WordTemplate('A complex pattern', 'MOSAIC'),
      _WordTemplate('A thoughtful question', 'INQUIRY'),
    ]),
    _PuzzleTemplate('master-01', 3, [
      _WordTemplate('Unusually difficult to understand', 'OBSCURE'),
      _WordTemplate('A fortunate coincidence', 'SERENDIPITY'),
      _WordTemplate('A person who studies stars', 'ASTRONOMER'),
      _WordTemplate('The art of beautiful writing', 'CALLIGRAPHY'),
      _WordTemplate('A subtle distinction', 'NUANCE'),
      _WordTemplate('A powerful expression', 'RHETORIC'),
    ]),
    _PuzzleTemplate('master-02', 3, [
      _WordTemplate('A complicated explanation', 'ELABORATION'),
      _WordTemplate('A person who loves books', 'BIBLIOPHILE'),
      _WordTemplate('A lack of certainty', 'AMBIGUITY'),
      _WordTemplate('A deep, restful calm', 'TRANQUILITY'),
      _WordTemplate('A clever word trick', 'PUNCTUATION'),
      _WordTemplate('A meaningful conversation', 'DIALOGUE'),
    ]),
  ];

  static String getTodayString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<DailyServerSnapshot?> syncRemote({
    String action = 'get',
  }) async {
    if (!SupabaseBootstrap.configured) return null;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'daily-word-mosaic',
        body: {'action': action},
      );
      final payload = response.data;
      if (payload is Map && payload['available'] == false) {
        return DailyServerSnapshot.unavailable(
          releaseAt: DateTime.tryParse(payload['release_at'] as String? ?? ''),
          serverNow: DateTime.tryParse(payload['server_now'] as String? ?? ''),
        );
      }
      if (payload is! Map ||
          payload['puzzle'] is! Map ||
          payload['progress'] is! Map)
        return null;
      final puzzle = Map<String, dynamic>.from(payload['puzzle'] as Map);
      final progress = Map<String, dynamic>.from(payload['progress'] as Map);
      final words = _parseRemoteWords(puzzle['words']);
      final date = puzzle['date'] as String? ?? getTodayString();
      final solved = (progress['solved_word_indexes'] as List? ?? const [])
          .whereType<num>()
          .map((item) => item.toInt())
          .toList();
      return DailyServerSnapshot(
        data: DailyChallengeData(
          dateStr: date,
          puzzleId: puzzle['puzzle_id'] as String? ?? '',
          difficultyTier: (puzzle['difficulty_tier'] as num?)?.toInt() ?? 0,
          words: words,
        ),
        state: DailyChallengeState(
          dateStr: date,
          puzzleId: puzzle['puzzle_id'] as String? ?? '',
          isCompleted: progress['completed'] as bool? ?? false,
          scoreAchieved: (progress['score'] as num?)?.toInt() ?? 0,
          bestPossibleScore: (puzzle['target_score'] as num?)?.toInt() ?? 0,
          starRating: progress['completed'] == true
              ? 3
              : solved.isNotEmpty
              ? 1
              : 0,
          streakDays: (progress['streak_days'] as num?)?.toInt() ?? 0,
          solvedWordIndexes: solved,
          remainingSeconds:
              (progress['remaining_seconds'] as num?)?.toInt() ?? 180,
          failed: progress['failed'] as bool? ?? false,
        ),
      );
    } catch (error) {
      debugPrint('[DailyChallenge] Remote sync unavailable: $error');
      return null;
    }
  }

  static bool get hasRemoteAccount {
    if (!SupabaseBootstrap.configured) return false;
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  static Future<DailyServerSnapshot> submitRemoteWord({
    required int wordIndex,
    required List<String> letters,
  }) async {
    if (!hasRemoteAccount) {
      throw const DailyChallengeRemoteException(
        'Sign in to sync and submit the Daily Challenge.',
      );
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'daily-word-mosaic',
        body: {'action': 'submit', 'word_index': wordIndex, 'letters': letters},
      );
      final payload = response.data;
      if (payload is! Map) {
        throw const DailyChallengeRemoteException(
          'The Daily Challenge server returned an incomplete response.',
        );
      }
      if (payload['accepted'] != true) {
        throw DailyChallengeRemoteException(
          payload['error'] as String? ??
              'The Daily Challenge could not verify that word. Refresh and try again.',
        );
      }
      final snapshot = _snapshotFromPayload(Map<String, dynamic>.from(payload));
      if (snapshot == null) {
        throw const DailyChallengeRemoteException(
          'The Daily Challenge progress response was incomplete.',
        );
      }
      return snapshot;
    } catch (error) {
      if (error is DailyChallengeRemoteException) rethrow;
      debugPrint('[DailyChallenge] Remote word submission failed: $error');
      throw const DailyChallengeRemoteException(
        'Unable to verify the word right now. Check your connection and try again.',
      );
    }
  }

  static DailyServerSnapshot? _snapshotFromPayload(
    Map<String, dynamic> payload,
  ) {
    if (payload['puzzle'] is! Map || payload['progress'] is! Map) return null;
    final puzzle = Map<String, dynamic>.from(payload['puzzle'] as Map);
    final progress = Map<String, dynamic>.from(payload['progress'] as Map);
    final words = _parseRemoteWords(puzzle['words']);
    final date = puzzle['date'] as String? ?? getTodayString();
    final puzzleId = puzzle['puzzle_id'] as String? ?? '';
    final solved = (progress['solved_word_indexes'] as List? ?? const [])
        .whereType<num>()
        .map((item) => item.toInt())
        .toList();
    return DailyServerSnapshot(
      data: DailyChallengeData(
        dateStr: date,
        puzzleId: puzzleId,
        difficultyTier: (puzzle['difficulty_tier'] as num?)?.toInt() ?? 0,
        words: words,
      ),
      state: DailyChallengeState(
        dateStr: date,
        puzzleId: puzzleId,
        isCompleted: progress['completed'] as bool? ?? false,
        scoreAchieved: (progress['score'] as num?)?.toInt() ?? 0,
        bestPossibleScore: (puzzle['target_score'] as num?)?.toInt() ?? 0,
        starRating: progress['completed'] == true
            ? 3
            : solved.isNotEmpty
            ? 1
            : 0,
        streakDays: (progress['streak_days'] as num?)?.toInt() ?? 0,
        solvedWordIndexes: solved,
        remainingSeconds:
            (progress['remaining_seconds'] as num?)?.toInt() ?? 180,
        failed: progress['failed'] as bool? ?? false,
      ),
      available: true,
      releaseAt: DateTime.tryParse(payload['release_at'] as String? ?? ''),
      serverNow: DateTime.tryParse(payload['server_now'] as String? ?? ''),
    );
  }

  static List<DailyWord> _parseRemoteWords(Object? rawWords) {
    return (rawWords as List? ?? const []).whereType<Map>().map((item) {
      final word = Map<String, dynamic>.from(item);
      return DailyWord(
        clue: word['clue'] as String? ?? '',
        answer: word['solved_answer'] as String? ?? '',
        answerLength: (word['answer_length'] as num?)?.toInt() ?? 0,
        letters: (word['letters'] as List? ?? const [])
            .whereType<String>()
            .toList(),
      );
    }).toList();
  }

  static DailyChallengeData generatePuzzle(
    String dateStr, {
    int streakDays = 0,
    String? puzzleId,
    List<String> excludedPuzzleIds = const [],
  }) {
    final tier = _difficultyTier(streakDays);
    final eligible = _catalog.where((p) => p.tier <= tier).toList();
    final candidates = eligible
        .where((p) => !excludedPuzzleIds.contains(p.id))
        .toList();
    final pool = candidates.isEmpty ? eligible : candidates;
    final seed = _stableHash('$dateStr:$streakDays');
    final selected = puzzleId == null
        ? pool[seed % pool.length]
        : _catalog.firstWhere(
            (p) => p.id == puzzleId,
            orElse: () => pool[seed % pool.length],
          );
    final random = Random(seed);
    return DailyChallengeData(
      dateStr: dateStr,
      puzzleId: selected.id,
      difficultyTier: tier,
      words: selected.words
          .map(
            (word) => DailyWord(
              clue: word.clue,
              answer: word.answer,
              letters: _scrambledLetters(word.answer, random, tier),
            ),
          )
          .toList(),
    );
  }

  static int _difficultyTier(int streakDays) {
    if (streakDays >= 10) return 3;
    if (streakDays >= 5) return 2;
    if (streakDays >= 2) return 1;
    return 0;
  }

  static List<String> _scrambledLetters(
    String answer,
    Random random,
    int tier,
  ) {
    final letters = answer.split('');
    final decoys = tier >= 2 ? 2 : 1;
    const decoyLetters = 'AEIOULMNRST';
    for (var i = 0; i < decoys; i++) {
      letters.add(decoyLetters[random.nextInt(decoyLetters.length)]);
    }
    letters.shuffle(random);
    return letters;
  }

  static int _stableHash(String value) {
    var seed = 2166136261;
    for (final codeUnit in value.codeUnits) {
      seed = ((seed ^ codeUnit) * 16777619) & 0x7fffffff;
    }
    return seed;
  }

  static Future<DailyChallengeState> loadState() async {
    final todayStr = getTodayString();
    final json = await _persistence.loadJsonData(_saveFileName);
    if (json != null) {
      final state = DailyChallengeState.fromJson(json);
      if (state.dateStr == todayStr) return state;
      final isYesterday = _isYesterday(state.dateStr);
      return DailyChallengeState(
        dateStr: todayStr,
        isCompleted: false,
        streakDays: isYesterday ? state.streakDays : 0,
        scoreAchieved: 0,
        bestPossibleScore: 0,
        starRating: 0,
        playedPuzzleIds: state.playedPuzzleIds,
      );
    }
    return const DailyChallengeState(
      dateStr: '',
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
      final prev = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      return today.difference(prev).inDays == 1;
    } catch (_) {
      return false;
    }
  }
}

class DailyServerSnapshot {
  final DailyChallengeData? data;
  final DailyChallengeState? state;
  final bool available;
  final DateTime? releaseAt;
  final DateTime? serverNow;

  const DailyServerSnapshot({
    required this.data,
    required this.state,
    this.available = true,
    this.releaseAt,
    this.serverNow,
  });

  const DailyServerSnapshot.unavailable({this.releaseAt, this.serverNow})
    : data = null,
      state = null,
      available = false;
}

class _PuzzleTemplate {
  final String id;
  final int tier;
  final List<_WordTemplate> words;
  const _PuzzleTemplate(this.id, this.tier, this.words);
}

class _WordTemplate {
  final String clue;
  final String answer;
  const _WordTemplate(this.clue, this.answer);
}
