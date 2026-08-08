import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/models/board_cell.dart';
import 'package:letterloom/models/tile.dart';
import 'package:letterloom/game_engine/game_config.dart';
import 'package:letterloom/dictionary/dictionary_service.dart';
import 'package:letterloom/ai/ai_engine.dart';

void main() {
  setUpAll(() {
    // Initialize mock dictionary
    DictionaryService().loadMock([
      'CAT', 'DOG', 'AT', 'GO', 'LOOM', 'CRAFT', 'OX', 'AX'
    ]);
  });

  List<List<BoardCell>> createEmptyBoard() {
    return List.generate(GameConfig.boardSize, (r) {
      return List.generate(GameConfig.boardSize, (c) {
        return BoardCell(
          row: r,
          col: c,
          type: GameConfig.getCellTypeAt(r, c),
        );
      });
    });
  }

  group('AIEngine Tests', () {
    test('First move on empty board selects centre square', () {
      final board = createEmptyBoard();
      // AI rack has 'C', 'A', 'T', 'Z', 'Z', 'Z', 'Z'
      final rack = [
        const Tile(id: 'r1', letter: 'C', scoreValue: 3),
        const Tile(id: 'r2', letter: 'A', scoreValue: 1),
        const Tile(id: 'r3', letter: 'T', scoreValue: 1),
        const Tile(id: 'r4', letter: 'Z', scoreValue: 10),
        const Tile(id: 'r5', letter: 'Z', scoreValue: 10),
        const Tile(id: 'r6', letter: 'Z', scoreValue: 10),
        const Tile(id: 'r7', letter: 'Z', scoreValue: 10),
      ];

      final args = {
        'board': board.map((row) => row.map((c) => c.toJson()).toList()).toList(),
        'rack': rack.map((t) => t.toJson()).toList(),
        'difficulty': 'hard',
        'wordsList': ['CAT', 'DOG', 'AT', 'GO', 'LOOM', 'CRAFT', 'OX', 'AX'],
      };

      final resultJson = AIEngine.computeMove(args);
      final move = AIMove.fromJson(resultJson);

      expect(move.isPass, false);
      expect(move.isExchange, false);
      expect(move.word, 'CAT');
      
      // Verify that the placements include (7,7)
      final coversCentre = move.placements.any((p) => p.row == 7 && p.col == 7);
      expect(coversCentre, true);
    });

    test('AI uses only letters from its rack or board overlaps', () {
      final board = createEmptyBoard();
      
      // Place existing locked tile 'C' at (7,7)
      board[7][7] = board[7][7].copyWith(
        tile: const Tile(id: 't_c', letter: 'C', scoreValue: 3),
        isNewPlacement: false,
      );

      // AI has rack: 'A', 'T', 'P', 'R', 'R', 'R', 'R' (can form CAT using existing 'C')
      final rack = [
        const Tile(id: 'r1', letter: 'A', scoreValue: 1),
        const Tile(id: 'r2', letter: 'T', scoreValue: 1),
        const Tile(id: 'r3', letter: 'P', scoreValue: 3),
        const Tile(id: 'r4', letter: 'R', scoreValue: 1),
        const Tile(id: 'r5', letter: 'R', scoreValue: 1),
        const Tile(id: 'r6', letter: 'R', scoreValue: 1),
        const Tile(id: 'r7', letter: 'R', scoreValue: 1),
      ];

      final args = {
        'board': board.map((row) => row.map((c) => c.toJson()).toList()).toList(),
        'rack': rack.map((t) => t.toJson()).toList(),
        'difficulty': 'hard',
        'wordsList': ['CAT', 'DOG', 'AT', 'GO', 'LOOM', 'CRAFT', 'OX', 'AX'],
      };

      final resultJson = AIEngine.computeMove(args);
      final move = AIMove.fromJson(resultJson);

      expect(move.isPass, false);
      expect(move.word, 'CAT');
      // Placements should only contain 'A' and 'T' since 'C' was already on the board!
      expect(move.placements.length, 2);
      expect(move.placements.any((p) => p.letter == 'A'), true);
      expect(move.placements.any((p) => p.letter == 'T'), true);
      expect(move.placements.any((p) => p.letter == 'C'), false);
    });

    test('AI returns pass or exchange if no valid words can be formed', () {
      final board = createEmptyBoard();
      board[7][7] = board[7][7].copyWith(
        tile: const Tile(id: 't_c', letter: 'C', scoreValue: 3),
        isNewPlacement: false,
      );

      // Rack has letters that cannot form any words in dictionary (even with C)
      final rack = [
        const Tile(id: 'r1', letter: 'Z', scoreValue: 10),
        const Tile(id: 'r2', letter: 'Z', scoreValue: 10),
        const Tile(id: 'r3', letter: 'Z', scoreValue: 10),
      ];

      final args = {
        'board': board.map((row) => row.map((c) => c.toJson()).toList()).toList(),
        'rack': rack.map((t) => t.toJson()).toList(),
        'difficulty': 'hard',
        'wordsList': ['CAT', 'DOG', 'AT', 'GO', 'LOOM', 'CRAFT', 'OX', 'AX'],
      };

      final resultJson = AIEngine.computeMove(args);
      final move = AIMove.fromJson(resultJson);

      // Should either be pass or exchange
      expect(move.isPass || move.isExchange, true);
    });
  });
}
