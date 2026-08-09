import 'dart:math';

class Statistics {
  final int totalGames;
  final int wins;
  final int losses;
  final int ties;
  final int highestGameScore;
  final int highestSingleTurnScore;
  final String longestWord;
  final int totalWordsPlayed;
  final int sevenTileBonuses;
  final int winsEasy;
  final int winsMedium;
  final int winsHard;

  const Statistics({
    this.totalGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.highestGameScore = 0,
    this.highestSingleTurnScore = 0,
    this.longestWord = '',
    this.totalWordsPlayed = 0,
    this.sevenTileBonuses = 0,
    this.winsEasy = 0,
    this.winsMedium = 0,
    this.winsHard = 0,
  });

  double get winPercentage => totalGames == 0 ? 0.0 : (wins / totalGames) * 100;

  Statistics copyWith({
    int? totalGames,
    int? wins,
    int? losses,
    int? ties,
    int? highestGameScore,
    int? highestSingleTurnScore,
    String? longestWord,
    int? totalWordsPlayed,
    int? sevenTileBonuses,
    int? winsEasy,
    int? winsMedium,
    int? winsHard,
  }) {
    return Statistics(
      totalGames: totalGames ?? this.totalGames,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      ties: ties ?? this.ties,
      highestGameScore: highestGameScore ?? this.highestGameScore,
      highestSingleTurnScore: highestSingleTurnScore ?? this.highestSingleTurnScore,
      longestWord: longestWord ?? this.longestWord,
      totalWordsPlayed: totalWordsPlayed ?? this.totalWordsPlayed,
      sevenTileBonuses: sevenTileBonuses ?? this.sevenTileBonuses,
      winsEasy: winsEasy ?? this.winsEasy,
      winsMedium: winsMedium ?? this.winsMedium,
      winsHard: winsHard ?? this.winsHard,
    );
  }

  Statistics recordGameEnd({
    required String result, // 'win', 'loss', 'tie'
    required int finalPlayerScore,
    required String difficulty,
    required List<Map<String, dynamic>> playerMovesThisGame, // list of moves containing word & score
  }) {
    int maxTurnScore = highestSingleTurnScore;
    String longest = longestWord;
    int bonusCount = sevenTileBonuses;

    for (var move in playerMovesThisGame) {
      final int mScore = (move['score'] as num?)?.toInt() ?? 0;
      final String mWord = move['word'] as String? ?? '';
      final bool usedAll = move['usedAll'] as bool? ?? false;

      maxTurnScore = max(maxTurnScore, mScore);
      if (mWord.length > longest.length) {
        longest = mWord;
      }
      if (usedAll) {
        bonusCount++;
      }
    }

    return copyWith(
      totalGames: totalGames + 1,
      wins: wins + (result == 'win' ? 1 : 0),
      losses: losses + (result == 'loss' ? 1 : 0),
      ties: ties + (result == 'tie' ? 1 : 0),
      highestGameScore: max(highestGameScore, finalPlayerScore),
      highestSingleTurnScore: maxTurnScore,
      longestWord: longest,
      totalWordsPlayed: totalWordsPlayed + playerMovesThisGame.length,
      sevenTileBonuses: bonusCount,
      winsEasy: winsEasy + (result == 'win' && difficulty == 'easy' ? 1 : 0),
      winsMedium: winsMedium + (result == 'win' && difficulty == 'medium' ? 1 : 0),
      winsHard: winsHard + (result == 'win' && difficulty == 'hard' ? 1 : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalGames': totalGames,
      'wins': wins,
      'losses': losses,
      'ties': ties,
      'highestGameScore': highestGameScore,
      'highestSingleTurnScore': highestSingleTurnScore,
      'longestWord': longestWord,
      'totalWordsPlayed': totalWordsPlayed,
      'sevenTileBonuses': sevenTileBonuses,
      'winsEasy': winsEasy,
      'winsMedium': winsMedium,
      'winsHard': winsHard,
    };
  }

  factory Statistics.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return Statistics(
      totalGames: readInt('totalGames'),
      wins: readInt('wins'),
      losses: readInt('losses'),
      ties: readInt('ties'),
      highestGameScore: readInt('highestGameScore'),
      highestSingleTurnScore: readInt('highestSingleTurnScore'),
      longestWord: json['longestWord'] as String? ?? '',
      totalWordsPlayed: readInt('totalWordsPlayed'),
      sevenTileBonuses: readInt('sevenTileBonuses'),
      winsEasy: readInt('winsEasy'),
      winsMedium: readInt('winsMedium'),
      winsHard: readInt('winsHard'),
    );
  }
}
