import '../../models/game_state.dart';

class PostGameSummary {
  final int totalPlayerScore;
  final int totalOpponentScore;
  final int totalPlayerTurns;
  final double averageTurnScore;
  final String highestScoringWord;
  final int highestTurnScore;
  final String longestWord;
  final int bingoCount;

  const PostGameSummary({
    required this.totalPlayerScore,
    required this.totalOpponentScore,
    required this.totalPlayerTurns,
    required this.averageTurnScore,
    required this.highestScoringWord,
    required this.highestTurnScore,
    required this.longestWord,
    required this.bingoCount,
  });

  factory PostGameSummary.fromGameState(GameState state) {
    final playerMoves = state.moveHistory.where((m) => m.player == 'player' && !m.isPass && !m.isExchange).toList();
    if (playerMoves.isEmpty) {
      return PostGameSummary(
        totalPlayerScore: state.playerScore,
        totalOpponentScore: state.computerScore,
        totalPlayerTurns: 0,
        averageTurnScore: 0.0,
        highestScoringWord: '-',
        highestTurnScore: 0,
        longestWord: '-',
        bingoCount: 0,
      );
    }

    int highestScore = 0;
    String highestWord = '-';
    String longestW = '-';
    int maxLen = 0;
    int bingos = 0;

    for (var m in playerMoves) {
      if (m.score > highestScore) {
        highestScore = m.score;
        highestWord = m.word;
      }
      if (m.word.length > maxLen) {
        maxLen = m.word.length;
        longestW = m.word;
      }
      if (m.tilesUsed.length == 7) {
        bingos++;
      }
    }

    final double avg = playerMoves.isNotEmpty ? state.playerScore / playerMoves.length : 0.0;

    return PostGameSummary(
      totalPlayerScore: state.playerScore,
      totalOpponentScore: state.computerScore,
      totalPlayerTurns: playerMoves.length,
      averageTurnScore: double.parse(avg.toStringAsFixed(1)),
      highestScoringWord: highestWord,
      highestTurnScore: highestScore,
      longestWord: longestW,
      bingoCount: bingos,
    );
  }
}
