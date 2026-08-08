import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/models/board_cell.dart';
import 'package:letterloom/models/tile.dart';
import 'package:letterloom/game_engine/game_config.dart';
import 'package:letterloom/game_engine/rules_validator.dart';
import 'package:letterloom/dictionary/dictionary_service.dart';

void main() {
  setUpAll(() {
    // Load a minimal mock dictionary so test validations succeed immediately
    DictionaryService().loadMock([
      'HELLO', 'WORLD', 'CAT', 'DOG', 'AT', 'GO', 'LOOM', 'CRAFT', 'OX', 'AX', 'GOT', 'AAAAAAA'
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

  group('RulesValidator Tests', () {
    final validator = RulesValidator();

    test('Tile creation and attributes are immutable', () {
      const tile = Tile(id: 't1', letter: 'A', scoreValue: 1);
      expect(tile.letter, 'A');
      expect(tile.scoreValue, 1);
      expect(tile.isBlank, false);

      final copy = tile.copyWith(blankLetter: 'E', isBlank: true);
      expect(copy.letter, 'A');
      expect(copy.isBlank, true);
      expect(copy.blankLetter, 'E');
      expect(copy.displayLetter, 'E');
    });

    test('Reject move with no tiles placed', () {
      final board = createEmptyBoard();
      final result = validator.validateMove(board);
      expect(result.isValid, false);
      expect(result.errorMessage, contains('at least one tile'));
    });

    test('First move must cover center square (7,7)', () {
      final board = createEmptyBoard();
      
      // Place "CAT" not crossing center
      board[2][2] = board[2][2].copyWith(tile: const Tile(id: '1', letter: 'C', scoreValue: 3), isNewPlacement: true);
      board[2][3] = board[2][3].copyWith(tile: const Tile(id: '2', letter: 'A', scoreValue: 1), isNewPlacement: true);
      board[2][4] = board[2][4].copyWith(tile: const Tile(id: '3', letter: 'T', scoreValue: 1), isNewPlacement: true);

      final result = validator.validateMove(board);
      expect(result.isValid, false);
      expect(result.errorMessage, contains('centre starting square'));
    });

    test('Valid first move scoring and center DW multiplier', () {
      final board = createEmptyBoard();
      
      // Place "CAT" crossing (7,7) at (7,6), (7,7), (7,8)
      // C(3) + A(1) + T(1) = 5
      // (7,7) is centre (Double Word), so total score should be 5 * 2 = 10
      board[7][6] = board[7][6].copyWith(tile: const Tile(id: '1', letter: 'C', scoreValue: 3), isNewPlacement: true);
      board[7][7] = board[7][7].copyWith(tile: const Tile(id: '2', letter: 'A', scoreValue: 1), isNewPlacement: true);
      board[7][8] = board[7][8].copyWith(tile: const Tile(id: '3', letter: 'T', scoreValue: 1), isNewPlacement: true);

      final result = validator.validateMove(board);
      expect(result.isValid, true);
      expect(result.wordsFormed.first.word, 'CAT');
      expect(result.totalScore, 10);
    });

    test('Reject vertical placements with gaps', () {
      final board = createEmptyBoard();

      // Placed vertically on (7,7) and (9,7), leaving (8,7) empty
      board[7][7] = board[7][7].copyWith(tile: const Tile(id: '1', letter: 'G', scoreValue: 2), isNewPlacement: true);
      board[9][7] = board[9][7].copyWith(tile: const Tile(id: '2', letter: 'O', scoreValue: 1), isNewPlacement: true);

      final result = validator.validateMove(board);
      expect(result.isValid, false);
      expect(result.errorMessage, contains('without gaps'));
    });

    test('Adjacency connectivity requirement after first turn', () {
      final board = createEmptyBoard();

      // Lock an existing word "CAT" on the board
      board[7][6] = board[7][6].copyWith(tile: const Tile(id: '1', letter: 'C', scoreValue: 3), isNewPlacement: false);
      board[7][7] = board[7][7].copyWith(tile: const Tile(id: '2', letter: 'A', scoreValue: 1), isNewPlacement: false);
      board[7][8] = board[7][8].copyWith(tile: const Tile(id: '3', letter: 'T', scoreValue: 1), isNewPlacement: false);

      // Place a new word "DOG" elsewhere without connecting to "CAT"
      board[2][2] = board[2][2].copyWith(tile: const Tile(id: '4', letter: 'D', scoreValue: 2), isNewPlacement: true);
      board[2][3] = board[2][3].copyWith(tile: const Tile(id: '5', letter: 'O', scoreValue: 1), isNewPlacement: true);
      board[2][4] = board[2][4].copyWith(tile: const Tile(id: '6', letter: 'G', scoreValue: 2), isNewPlacement: true);

      final result = validator.validateMove(board);
      expect(result.isValid, false);
      expect(result.errorMessage, contains('must connect to at least one existing word'));
    });

    test('Correct cross-word formation and scoring', () {
      final board = createEmptyBoard();

      // Lock "CAT" horizontally at (7,6)-(7,8)
      board[7][6] = board[7][6].copyWith(tile: const Tile(id: '1', letter: 'C', scoreValue: 3), isNewPlacement: false);
      board[7][7] = board[7][7].copyWith(tile: const Tile(id: '2', letter: 'A', scoreValue: 1), isNewPlacement: false);
      board[7][8] = board[7][8].copyWith(tile: const Tile(id: '3', letter: 'T', scoreValue: 1), isNewPlacement: false);

      // Place vertical word "GO" crossing "CAT"'s 'O' at (6,7) and (8,7)
      // Wait, A is at (7,7), so if we place 'G' at (6,7) and 'O' at (8,7)
      // we form "GAO" which is not valid, let's place 'D' at (6,7) and 'O' at (5,7) to form "DOC" if C was at (7,7)
      // Or simply: lock "AT" horizontally at (7,7)-(7,8).
      // Then place "GO" vertically at (6,8)-(5,8) to cross 'T' at (7,8) -> forms "GOT" vertically!
      // Let's verify: G(2) at (5,8), O(1) at (6,8), T(1) at (7,8) -> word GOT score: G(2) + O(1) + T(1) = 4
      board[5][8] = board[5][8].copyWith(tile: const Tile(id: '4', letter: 'G', scoreValue: 2), isNewPlacement: true);
      board[6][8] = board[6][8].copyWith(tile: const Tile(id: '5', letter: 'O', scoreValue: 1), isNewPlacement: true);

      final result = validator.validateMove(board);
      expect(result.isValid, true);
      expect(result.wordsFormed.length, 1);
      expect(result.wordsFormed.first.word, 'GOT');
      expect(result.totalScore, 5);
    });

    test('Blank tile score calculation is zero', () {
      final board = createEmptyBoard();

      // Place "HELLO" crossing center. H is a blank tile representing 'H'.
      // E(1) + L(1) + L(1) + O(1) = 4 points.
      // (7,7) is center (DW) -> total score should be 4 * 2 = 8 points.
      board[7][5] = board[7][5].copyWith(
        tile: const Tile(id: '1', letter: ' ', scoreValue: 0, isBlank: true, blankLetter: 'H'),
        isNewPlacement: true,
      );
      board[7][6] = board[7][6].copyWith(tile: const Tile(id: '2', letter: 'E', scoreValue: 1), isNewPlacement: true);
      board[7][7] = board[7][7].copyWith(tile: const Tile(id: '3', letter: 'L', scoreValue: 1), isNewPlacement: true);
      board[7][8] = board[7][8].copyWith(tile: const Tile(id: '4', letter: 'L', scoreValue: 1), isNewPlacement: true);
      board[7][9] = board[7][9].copyWith(tile: const Tile(id: '5', letter: 'O', scoreValue: 1), isNewPlacement: true);

      final result = validator.validateMove(board);
      expect(result.isValid, true);
      // H behaves as 'H'
      expect(result.wordsFormed.first.word, 'HELLO');
      expect(result.totalScore, 8);
    });

    test('Bingo 50-point bonus', () {
      final board = createEmptyBoard();

      // Place 7 letters crossing center.
      // A(1) + A(1) + A(1) + A(1) + A(1) + A(1) + A(1) = 7.
      // Centre is DW -> (6 + 1*2) = 8.
      // Plus 50-point Bingo = 58 points.
      for (int c = 4; c <= 10; c++) {
        board[7][c] = board[7][c].copyWith(
          tile: Tile(id: 't_$c', letter: 'A', scoreValue: 1),
          isNewPlacement: true,
        );
      }

      final result = validator.validateMove(board);
      expect(result.isValid, true);
      expect(result.isBingo, true);
      expect(result.totalScore, 64);
    });
  });
}
