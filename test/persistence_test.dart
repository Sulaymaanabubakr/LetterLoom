import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/models/board_cell.dart';
import 'package:letterloom/models/tile.dart';
import 'package:letterloom/models/game_state.dart';
import 'package:letterloom/models/game_settings.dart';
import 'package:letterloom/models/statistics.dart';
import 'package:letterloom/models/move_history.dart';

void main() {
  group('Save & Serialization Tests', () {
    test('GameState converts to JSON and restores correctly', () {
      final board = List.generate(15, (r) {
        return List.generate(15, (c) {
          return BoardCell(row: r, col: c, type: CellType.normal);
        });
      });

      // Place a tile on the board
      board[7][7] = board[7][7].copyWith(
        tile: const Tile(
          id: 't_centre',
          letter: 'A',
          scoreValue: 1,
          isBlank: false,
        ),
        isNewPlacement: false,
      );

      final state = GameState(
        board: board,
        playerRack: const [
          Tile(id: 'p1', letter: 'X', scoreValue: 8),
          Tile(
            id: 'p2',
            letter: ' ',
            scoreValue: 0,
            isBlank: true,
            blankLetter: 'E',
          ),
        ],
        computerRack: const [Tile(id: 'c1', letter: 'Z', scoreValue: 10)],
        tileBag: const [Tile(id: 'b1', letter: 'O', scoreValue: 1)],
        playerScore: 42,
        computerScore: 24,
        currentTurn: 'player',
        difficulty: 'medium',
        consecutivePasses: 1,
        moveHistory: const [
          MoveHistory(
            player: 'player',
            word: 'AX',
            score: 9,
            timestamp: '12:00',
            tilesUsed: ['A', 'X'],
          ),
        ],
        status: 'playerTurn',
        settings: const GameSettings(soundEnabled: false, hapticEnabled: true),
        statistics: const Statistics(wins: 5, losses: 2),
        turnStartedAt: DateTime.utc(2026, 8, 9, 17, 0),
      );

      // Serialize
      final jsonMap = state.toJson();

      // Deserialize
      final restored = GameState.fromJson(jsonMap);

      // Assertions
      expect(restored.playerScore, 42);
      expect(restored.computerScore, 24);
      expect(restored.difficulty, 'medium');
      expect(restored.consecutivePasses, 1);
      expect(restored.currentTurn, 'player');
      expect(restored.settings.soundEnabled, false);
      expect(restored.settings.hapticEnabled, true);
      expect(restored.statistics.wins, 5);
      expect(restored.statistics.losses, 2);
      expect(restored.turnStartedAt, DateTime.utc(2026, 8, 9, 17, 0));

      // Check board tile restored
      final centreCell = restored.board[7][7];
      expect(centreCell.tile, isNotNull);
      expect(centreCell.tile!.letter, 'A');
      expect(centreCell.tile!.scoreValue, 1);
      expect(centreCell.isNewPlacement, false);

      // Check racks
      expect(restored.playerRack.length, 2);
      expect(restored.playerRack[0].letter, 'X');
      expect(restored.playerRack[1].isBlank, true);
      expect(restored.playerRack[1].blankLetter, 'E');

      expect(restored.computerRack.length, 1);
      expect(restored.computerRack[0].letter, 'Z');

      // Check move history
      expect(restored.moveHistory.length, 1);
      expect(restored.moveHistory[0].word, 'AX');
      expect(restored.moveHistory[0].score, 9);
      expect(restored.moveHistory[0].tilesUsed, ['A', 'X']);
    });

    test('records personal gameplay details', () {
      const initial = Statistics();
      final updated = initial.recordGameEnd(
        result: 'win',
        finalPlayerScore: 184,
        difficulty: 'hard',
        playerMovesThisGame: const [
          {'word': 'LETTER', 'score': 42, 'usedAll': false},
          {'word': 'QUIZZES', 'score': 87, 'usedAll': true},
        ],
      );

      expect(updated.totalGames, 1);
      expect(updated.wins, 1);
      expect(updated.highestGameScore, 184);
      expect(updated.highestSingleTurnScore, 87);
      expect(updated.longestWord, 'QUIZZES');
      expect(updated.totalWordsPlayed, 2);
      expect(updated.sevenTileBonuses, 1);
      expect(updated.winsHard, 1);
    });

    test('loads numeric statistics values regardless of JSON number type', () {
      final restored = Statistics.fromJson(const {
        'totalGames': 2.0,
        'highestGameScore': 184.0,
        'highestSingleTurnScore': 87.0,
        'totalWordsPlayed': 9.0,
      });

      expect(restored.totalGames, 2);
      expect(restored.highestGameScore, 184);
      expect(restored.highestSingleTurnScore, 87);
      expect(restored.totalWordsPlayed, 9);
    });
  });
}
