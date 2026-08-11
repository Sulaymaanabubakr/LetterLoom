import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../ai/ai_engine.dart';

class HintResult {
  final String hintType; // 'move', 'letter', 'strong'
  final String word;
  final int score;
  final int row;
  final int col;
  final bool isHorizontal;
  final String maskedPattern; // e.g., "_ A _ E"
  final List<PlacedTileInput> placements;

  const HintResult({
    required this.hintType,
    required this.word,
    required this.score,
    required this.row,
    required this.col,
    required this.isHorizontal,
    required this.maskedPattern,
    required this.placements,
  });
}

class HintEngine {
  /// Analyzes current board and rack to compute a valid legal move hint.
  /// Returns `null` if no valid move can be generated.
  static HintResult? generateHint({
    required List<List<BoardCell>> boardGrid,
    required List<Tile> playerRack,
    required String hintType, // 'move', 'letter', 'strong'
  }) {
    if (playerRack.isEmpty) return null;

    final args = <String, dynamic>{
      'board': boardGrid.map((row) => row.map((cell) => cell.toJson()).toList()).toList(),
      'rack': playerRack.map((t) => t.toJson()).toList(),
      'difficulty': 'hard', // Find high quality move for hints
    };

    final rawMove = AIEngine.computeMove(args);
    final aiMove = AIMove.fromJson(rawMove);

    if (aiMove.isPass || aiMove.isExchange || aiMove.placements.isEmpty || aiMove.word.isEmpty) {
      return null;
    }

    final firstPlacement = aiMove.placements.first;
    final row = firstPlacement.row;
    final col = firstPlacement.col;
    final isHorizontal = aiMove.placements.length > 1
        ? aiMove.placements.first.row == aiMove.placements[1].row
        : true;

    final word = aiMove.word;
    final StringBuffer maskBuffer = StringBuffer();
    for (int i = 0; i < word.length; i++) {
      if (i == 1 || i == word.length - 2) {
        maskBuffer.write('${word[i]} ');
      } else {
        maskBuffer.write('_ ');
      }
    }

    return HintResult(
      hintType: hintType,
      word: word,
      score: aiMove.score,
      row: row,
      col: col,
      isHorizontal: isHorizontal,
      maskedPattern: maskBuffer.toString().trim(),
      placements: aiMove.placements,
    );
  }
}
