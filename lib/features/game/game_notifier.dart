import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_state.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../models/move_history.dart';
import '../../models/game_settings.dart';
import '../../models/statistics.dart';
import '../../game_engine/game_config.dart';
import '../../game_engine/rules_validator.dart';
import '../../dictionary/dictionary_service.dart';
import '../../ai/ai_isolate.dart';
import '../../ai/ai_engine.dart';
import '../../storage/persistence_manager.dart';
import '../../core/music_manager.dart';

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});

class GameNotifier extends StateNotifier<GameState> {
  final PersistenceManager _persistence = PersistenceManager();
  final RulesValidator _rulesValidator = RulesValidator();
  final DictionaryService _dictionary = DictionaryService();
  Timer? _aiAnimationTimer;

  GameState get currentState => state;

  GameNotifier()
    : super(
        GameState(
          board: _createEmptyBoard(),
          playerRack: const [],
          computerRack: const [],
          tileBag: const [],
          playerScore: 0,
          computerScore: 0,
          currentTurn: 'player',
          difficulty: 'easy',
          consecutivePasses: 0,
          moveHistory: const [],
          status: 'playerTurn',
          settings: const GameSettings(),
          statistics: const Statistics(),
        ),
      ) {
    _init();
  }

  static List<List<BoardCell>> _createEmptyBoard() {
    return List.generate(GameConfig.boardSize, (r) {
      return List.generate(GameConfig.boardSize, (c) {
        return BoardCell(row: r, col: c, type: GameConfig.getCellTypeAt(r, c));
      });
    });
  }

  Future<void> _init() async {
    final settings = await _persistence.loadSettings();
    final stats = await _persistence.loadStatistics();

    state = state.copyWith(settings: settings, statistics: stats);

    unawaited(MusicManager.instance.init(settings.musicEnabled));
  }

  // --- External Actions ---

  Future<bool> hasSavedGame() async {
    return await _persistence.hasSavedGame();
  }

  Future<void> loadSavedGame() async {
    try {
      final saved = await _persistence.loadGame();
      if (saved != null) {
        state = saved.copyWith(
          // Ensure we sync the latest settings and statistics
          settings: state.settings,
          statistics: state.statistics,
        );

        // If we loaded and it was computer's turn, resume computer move
        if (state.currentTurn == 'computer' &&
            state.status == 'computerThinking') {
          _runComputerTurn();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSavedGame() async {
    await _persistence.deleteGameSave();
  }

  void startNewGame(String difficulty, {bool persist = true}) {
    // 1. Generate full tile bag
    final List<Tile> bag = [];
    int tileIdCounter = 0;
    GameConfig.letterDistributions.forEach((letter, count) {
      final score = GameConfig.letterScores[letter] ?? 0;
      for (int i = 0; i < count; i++) {
        bag.add(
          Tile(
            id: 'tile_${tileIdCounter++}',
            letter: letter,
            scoreValue: score,
            isBlank: letter == ' ',
          ),
        );
      }
    });

    // Shuffle the bag
    bag.shuffle();

    // 2. Draw 7 tiles for player and computer
    final List<Tile> pRack = [];
    final List<Tile> cRack = [];

    for (int i = 0; i < GameConfig.rackSize; i++) {
      if (bag.isNotEmpty) pRack.add(bag.removeLast());
      if (bag.isNotEmpty) cRack.add(bag.removeLast());
    }

    state = GameState(
      board: _createEmptyBoard(),
      playerRack: pRack,
      computerRack: cRack,
      tileBag: bag,
      playerScore: 0,
      computerScore: 0,
      currentTurn: 'player',
      difficulty: difficulty,
      consecutivePasses: 0,
      moveHistory: const [],
      status: 'playerTurn',
      settings: state.settings,
      statistics: state.statistics,
      lastMoveMessage: "New game started! Your turn first.",
    );

    if (persist) {
      _persistence.saveGame(state);
    }
  }

  Future<void> abandonGame() async {
    await _persistence.deleteGameSave();

    // Record as loss if in progress
    if (state.status != 'gameCompleted') {
      final updatedStats = state.statistics.copyWith(
        totalGames: state.statistics.totalGames + 1,
        losses: state.statistics.losses + 1,
      );
      state = state.copyWith(
        status: 'playerTurn',
        board: _createEmptyBoard(),
        playerRack: const [],
        computerRack: const [],
        tileBag: const [],
        playerScore: 0,
        computerScore: 0,
        statistics: updatedStats,
      );
      await _persistence.saveStatistics(updatedStats);
    }
  }

  // --- Tile Movement Actions ---

  /// Place a tile from the player rack to a board coordinate
  bool placeTile(Tile tile, int row, int col) {
    if (state.status != 'playerTurn') return false;
    if (row < 0 ||
        row >= GameConfig.boardSize ||
        col < 0 ||
        col >= GameConfig.boardSize)
      return false;

    final cell = state.board[row][col];
    if (cell.tile != null) return false; // Cell already occupied

    // Update board
    final newBoard = _cloneBoardGrid(state.board);
    newBoard[row][col] = cell.copyWith(tile: tile, isNewPlacement: true);

    // Update player rack
    final newRack = List<Tile>.from(state.playerRack)
      ..removeWhere((t) => t.id == tile.id);

    state = state.copyWith(
      board: newBoard,
      playerRack: newRack,
      clearLastMoveMessage: true,
    );
    return true;
  }

  /// Set the character representing a blank tile
  void setBlankLetter(int row, int col, String letter) {
    final cell = state.board[row][col];
    if (cell.tile != null && cell.tile!.isBlank && cell.isNewPlacement) {
      final newBoard = _cloneBoardGrid(state.board);
      newBoard[row][col] = cell.copyWith(
        tile: cell.tile!.copyWith(blankLetter: letter.toUpperCase()),
      );
      state = state.copyWith(board: newBoard);
    }
  }

  /// Move a temporarily placed tile between coordinates
  bool movePlacedTile(int fromRow, int fromCol, int toRow, int toCol) {
    if (state.status != 'playerTurn') return false;
    if (fromRow == toRow && fromCol == toCol) return true;

    final fromCell = state.board[fromRow][fromCol];
    final toCell = state.board[toRow][toCol];

    if (!fromCell.isNewPlacement || fromCell.tile == null) return false;
    if (toCell.tile != null) return false; // Target cell is occupied

    final newBoard = _cloneBoardGrid(state.board);

    // Clear from position
    newBoard[fromRow][fromCol] = fromCell.copyWith(
      clearTile: true,
      isNewPlacement: false,
    );
    // Put on to position
    newBoard[toRow][toCol] = toCell.copyWith(
      tile: fromCell.tile,
      isNewPlacement: true,
    );

    state = state.copyWith(board: newBoard);
    return true;
  }

  /// Recall a single temporarily placed tile back to rack
  void recallTileAt(int row, int col) {
    if (state.status != 'playerTurn') return;
    final cell = state.board[row][col];
    if (cell.tile == null || !cell.isNewPlacement) return;

    final newBoard = _cloneBoardGrid(state.board);
    newBoard[row][col] = cell.copyWith(clearTile: true, isNewPlacement: false);

    // Return the clean blank tile if it was blank
    final returnedTile = cell.tile!.isBlank
        ? cell.tile!.copyWith(blankLetter: null)
        : cell.tile!;

    state = state.copyWith(
      board: newBoard,
      playerRack: List<Tile>.from(state.playerRack)..add(returnedTile),
    );
  }

  /// Recall all new placements back to rack
  void recallAllNewPlacements() {
    if (state.status != 'playerTurn') return;

    final List<Tile> recalled = [];
    final newBoard = _cloneBoardGrid(state.board);

    for (int r = 0; r < GameConfig.boardSize; r++) {
      for (int c = 0; c < GameConfig.boardSize; c++) {
        final cell = newBoard[r][c];
        if (cell.tile != null && cell.isNewPlacement) {
          final returnedTile = cell.tile!.isBlank
              ? cell.tile!.copyWith(blankLetter: null)
              : cell.tile!;
          recalled.add(returnedTile);
          newBoard[r][c] = cell.copyWith(
            clearTile: true,
            isNewPlacement: false,
          );
        }
      }
    }

    if (recalled.isEmpty) return;

    state = state.copyWith(
      board: newBoard,
      playerRack: List<Tile>.from(state.playerRack)..addAll(recalled),
    );
  }

  void shuffleRack() {
    final shuffled = List<Tile>.from(state.playerRack)..shuffle();
    state = state.copyWith(playerRack: shuffled);
  }

  // --- Move Actions (Pass, Exchange, Submit) ---

  void passTurn() {
    if (state.status != 'playerTurn') return;
    recallAllNewPlacements();

    final nextPasses = state.consecutivePasses + 1;
    final timestamp = DateTime.now().toIso8601String().substring(
      11,
      16,
    ); // HH:MM

    final newHistory = List<MoveHistory>.from(state.moveHistory)
      ..add(
        MoveHistory(
          player: 'player',
          word: 'PASSED',
          score: 0,
          timestamp: timestamp,
          tilesUsed: const [],
          isPass: true,
        ),
      );

    state = state.copyWith(
      consecutivePasses: nextPasses,
      moveHistory: newHistory,
      currentTurn: 'computer',
      status: 'computerThinking',
      lastMoveMessage: "You passed your turn.",
    );

    _persistence.saveGame(state);

    if (_checkGameOver()) return;

    _runComputerTurn();
  }

  bool exchangeTiles(List<Tile> tilesToExchange) {
    if (state.status != 'playerTurn') return false;
    if (tilesToExchange.isEmpty) return false;
    if (state.tileBag.length < GameConfig.rackSize)
      return false; // Rule: Must have >= 7 tiles in bag to exchange

    recallAllNewPlacements();

    // 1. Put tiles back in the bag
    final List<Tile> bag = List<Tile>.from(state.tileBag);
    final List<Tile> rack = List<Tile>.from(state.playerRack);

    for (var tile in tilesToExchange) {
      rack.removeWhere((t) => t.id == tile.id);
      // Ensure we clear blank selections when placing back to bag
      final cleanTile = tile.isBlank ? tile.copyWith(blankLetter: null) : tile;
      bag.add(cleanTile);
    }

    // Shuffle the bag
    bag.shuffle();

    // 2. Draw new tiles
    final List<Tile> drawn = [];
    for (int i = 0; i < tilesToExchange.length; i++) {
      if (bag.isNotEmpty) {
        drawn.add(bag.removeLast());
      }
    }

    rack.addAll(drawn);

    final timestamp = DateTime.now().toIso8601String().substring(11, 16);
    final newHistory = List<MoveHistory>.from(state.moveHistory)
      ..add(
        MoveHistory(
          player: 'player',
          word: 'EXCHANGED',
          score: 0,
          timestamp: timestamp,
          tilesUsed: tilesToExchange.map((t) => t.displayLetter).toList(),
          isExchange: true,
        ),
      );

    state = state.copyWith(
      playerRack: rack,
      tileBag: bag,
      consecutivePasses: state.consecutivePasses + 1,
      moveHistory: newHistory,
      currentTurn: 'computer',
      status: 'computerThinking',
      lastMoveMessage: "You exchanged ${tilesToExchange.length} tiles.",
    );

    _persistence.saveGame(state);

    if (_checkGameOver()) return false;

    _runComputerTurn();
    return true;
  }

  /// Validates and submits the player's current board placements
  String? submitPlayerMove() {
    if (state.status != 'playerTurn') return "It is not your turn.";

    // Run rules engine validation
    final validation = _rulesValidator.validateMove(state.board);
    if (!validation.isValid) {
      return validation.errorMessage;
    }

    // Move is valid! Let's lock placements
    final newBoard = _cloneBoardGrid(state.board);
    final List<String> lettersUsed = [];
    for (int r = 0; r < GameConfig.boardSize; r++) {
      for (int c = 0; c < GameConfig.boardSize; c++) {
        final cell = newBoard[r][c];
        if (cell.tile != null && cell.isNewPlacement) {
          newBoard[r][c] = cell.copyWith(isNewPlacement: false);
          lettersUsed.add(cell.tile!.displayLetter);
        }
      }
    }

    // Refill player rack
    final List<Tile> rack = List<Tile>.from(state.playerRack);
    final List<Tile> bag = List<Tile>.from(state.tileBag);
    final int tilesNeeded = GameConfig.rackSize - rack.length;

    for (int i = 0; i < tilesNeeded; i++) {
      if (bag.isNotEmpty) {
        rack.add(bag.removeLast());
      }
    }

    final newScore = state.playerScore + validation.totalScore;
    final timestamp = DateTime.now().toIso8601String().substring(11, 16);
    final primaryWord = validation.wordsFormed.first.word;

    final newHistory = List<MoveHistory>.from(state.moveHistory)
      ..add(
        MoveHistory(
          player: 'player',
          word: primaryWord,
          score: validation.totalScore,
          timestamp: timestamp,
          tilesUsed: lettersUsed,
        ),
      );

    state = state.copyWith(
      board: newBoard,
      playerRack: rack,
      tileBag: bag,
      playerScore: newScore,
      consecutivePasses: 0, // Reset pass counter
      moveHistory: newHistory,
      currentTurn: 'computer',
      status: 'computerThinking',
      lastMoveMessage:
          "You played $primaryWord for ${validation.totalScore} pts!",
    );

    _persistence.saveGame(state);

    if (_checkGameOver()) return null;

    _runComputerTurn();
    return null;
  }

  // --- Computer Opponent Core Flow ---

  Future<void> _runComputerTurn() async {
    final stopwatch = Stopwatch()..start();

    if (!_dictionary.isLoaded) {
      await _dictionary.load();
    }

    final List<String> wordsList = _dictionary.wordList;

    try {
      final aiMove = await AIService.calculateMove(
        board: state.board,
        rack: state.computerRack,
        difficulty: state.difficulty,
        dictionaryWords: wordsList,
      );

      // Check if task wasn't cancelled or status changed while thinking (e.g. game abandoned)
      if (state.status != 'computerThinking') return;

      // Enforce a minimum delay of 1.2 seconds for realistic opponent thinking feel
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 1200) {
        await Future.delayed(Duration(milliseconds: 1200 - elapsed));
      }

      if (state.status != 'computerThinking') return;

      if (aiMove.isPass) {
        _applyComputerPass();
      } else if (aiMove.isExchange) {
        _applyComputerExchange(aiMove.exchangeTileIds ?? []);
      } else {
        _animateComputerMove(aiMove);
      }
    } catch (e) {
      debugPrint("AI Isolate Error: $e");
      // Enforce delay even on error
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 1200) {
        await Future.delayed(Duration(milliseconds: 1200 - elapsed));
      }
      if (state.status == 'computerThinking') {
        _applyComputerPass();
      }
    }
  }

  void _applyComputerPass() {
    final nextPasses = state.consecutivePasses + 1;
    final timestamp = DateTime.now().toIso8601String().substring(11, 16);

    final newHistory = List<MoveHistory>.from(state.moveHistory)
      ..add(
        MoveHistory(
          player: 'computer',
          word: 'PASSED',
          score: 0,
          timestamp: timestamp,
          tilesUsed: const [],
          isPass: true,
        ),
      );

    state = state.copyWith(
      consecutivePasses: nextPasses,
      moveHistory: newHistory,
      currentTurn: 'player',
      status: 'playerTurn',
      lastMoveMessage: "Computer passed its turn.",
    );

    _persistence.saveGame(state);
    _checkGameOver();
  }

  void _applyComputerExchange(List<String> exchangeTileIds) {
    if (exchangeTileIds.isEmpty || state.tileBag.length < GameConfig.rackSize) {
      _applyComputerPass();
      return;
    }

    final List<Tile> bag = List<Tile>.from(state.tileBag);
    final List<Tile> rack = List<Tile>.from(state.computerRack);
    final List<String> lettersExchanged = [];

    for (var id in exchangeTileIds) {
      final idx = rack.indexWhere((t) => t.id == id);
      if (idx != -1) {
        final tile = rack.removeAt(idx);
        final cleanTile = tile.isBlank
            ? tile.copyWith(blankLetter: null)
            : tile;
        bag.add(cleanTile);
        lettersExchanged.add(tile.displayLetter);
      }
    }

    bag.shuffle();

    // Draw replacements
    for (int i = 0; i < exchangeTileIds.length; i++) {
      if (bag.isNotEmpty) {
        rack.add(bag.removeLast());
      }
    }

    final timestamp = DateTime.now().toIso8601String().substring(11, 16);
    final newHistory = List<MoveHistory>.from(state.moveHistory)
      ..add(
        MoveHistory(
          player: 'computer',
          word: 'EXCHANGED',
          score: 0,
          timestamp: timestamp,
          tilesUsed: lettersExchanged,
          isExchange: true,
        ),
      );

    state = state.copyWith(
      computerRack: rack,
      tileBag: bag,
      consecutivePasses: state.consecutivePasses + 1,
      moveHistory: newHistory,
      currentTurn: 'player',
      status: 'playerTurn',
      lastMoveMessage: "Computer exchanged ${exchangeTileIds.length} tiles.",
    );

    _persistence.saveGame(state);
    _checkGameOver();
  }

  void _animateComputerMove(AIMove aiMove) {
    state = state.copyWith(status: 'animatingComputerMove');

    final placements = aiMove.placements;
    int currentIndex = 0;

    // Standard timer duration adjusted by settings speed
    final int delayMs = (300 * state.settings.animationSpeed).toInt();

    _aiAnimationTimer = Timer.periodic(Duration(milliseconds: delayMs), (
      timer,
    ) {
      if (currentIndex >= placements.length) {
        timer.cancel();
        _finalizeComputerMove(aiMove);
        return;
      }

      final p = placements[currentIndex];

      // Update board with single animated tile
      final newBoard = _cloneBoardGrid(state.board);
      final animatedTile = Tile(
        id: p.id,
        letter: p.letter,
        scoreValue: p.isBlank ? 0 : GameConfig.letterScores[p.letter] ?? 0,
        isBlank: p.isBlank,
        blankLetter: p.blankLetter,
      );

      newBoard[p.row][p.col] = newBoard[p.row][p.col].copyWith(
        tile: animatedTile,
        isNewPlacement:
            true, // Show highlighted highlight in UI during animation
      );

      state = state.copyWith(board: newBoard);
      currentIndex++;
    });
  }

  void _finalizeComputerMove(AIMove aiMove) {
    // 1. Lock computer placed tiles on board
    final newBoard = _cloneBoardGrid(state.board);
    for (var p in aiMove.placements) {
      newBoard[p.row][p.col] = newBoard[p.row][p.col].copyWith(
        isNewPlacement: false,
      );
    }

    // 2. Remove placed tiles from computer's rack
    final List<Tile> cRack = List<Tile>.from(state.computerRack);
    for (var p in aiMove.placements) {
      cRack.removeWhere((t) => t.id == p.id);
    }

    // Refill computer rack
    final List<Tile> bag = List<Tile>.from(state.tileBag);
    final int tilesNeeded = GameConfig.rackSize - cRack.length;
    for (int i = 0; i < tilesNeeded; i++) {
      if (bag.isNotEmpty) {
        cRack.add(bag.removeLast());
      }
    }

    final newScore = state.computerScore + aiMove.score;
    final timestamp = DateTime.now().toIso8601String().substring(11, 16);

    final newHistory = List<MoveHistory>.from(state.moveHistory)
      ..add(
        MoveHistory(
          player: 'computer',
          word: aiMove.word,
          score: aiMove.score,
          timestamp: timestamp,
          tilesUsed: aiMove.placements
              .map((p) => p.blankLetter ?? p.letter)
              .toList(),
        ),
      );

    state = state.copyWith(
      board: newBoard,
      computerRack: cRack,
      tileBag: bag,
      computerScore: newScore,
      consecutivePasses: 0,
      moveHistory: newHistory,
      currentTurn: 'player',
      status: 'playerTurn',
      lastMoveMessage:
          "Computer played ${aiMove.word} for ${aiMove.score} pts!",
    );

    _persistence.saveGame(state);

    if (_checkGameOver()) return;
  }

  // --- Endgame calculations ---

  bool _checkGameOver() {
    // Game over Condition 1: 6 consecutive passes (3 turns of both passing/exchanging)
    bool sixPasses = state.consecutivePasses >= 6;

    // Game over Condition 2: A player's rack is empty and the bag is empty
    bool playerFinished = state.playerRack.isEmpty && state.tileBag.isEmpty;
    bool computerFinished = state.computerRack.isEmpty && state.tileBag.isEmpty;

    if (sixPasses || playerFinished || computerFinished) {
      _applyEndgameScoreDeductions();
      return true;
    }
    return false;
  }

  void _applyEndgameScoreDeductions() {
    int pScore = state.playerScore;
    int cScore = state.computerScore;

    final int playerRackValue = state.playerRack.fold(
      0,
      (sum, t) => sum + t.scoreValue,
    );
    final int computerRackValue = state.computerRack.fold(
      0,
      (sum, t) => sum + t.scoreValue,
    );

    String deductionMessage = "";

    if (state.playerRack.isEmpty && state.tileBag.isEmpty) {
      // Player gets points of computer's remaining rack
      pScore += computerRackValue;
      cScore -= computerRackValue;
      deductionMessage =
          "You used all tiles! Added +$computerRackValue, Computer deducted -$computerRackValue.";
    } else if (state.computerRack.isEmpty && state.tileBag.isEmpty) {
      // Computer gets points of player's remaining rack
      cScore += playerRackValue;
      pScore -= playerRackValue;
      deductionMessage =
          "Computer used all tiles! Added +$playerRackValue, you deducted -$playerRackValue.";
    } else {
      // Both deduct remaining tiles
      pScore -= playerRackValue;
      cScore -= computerRackValue;
      deductionMessage =
          "Game ended by passes! Deductions: You -$playerRackValue, Computer -$computerRackValue.";
    }

    // Clamp scores to 0
    pScore = max(0, pScore);
    cScore = max(0, cScore);

    // Determine winner
    String result = 'tie';
    if (pScore > cScore) result = 'win';
    if (pScore < cScore) result = 'loss';

    // Map list of moves for player to stats
    final List<Map<String, dynamic>> playerMoves = state.moveHistory
        .where((m) => m.player == 'player' && !m.isPass && !m.isExchange)
        .map(
          (m) => {
            'word': m.word,
            'score': m.score,
            'usedAll': m.tilesUsed.length == GameConfig.rackSize,
          },
        )
        .toList();

    // Record stats
    final updatedStats = state.statistics.recordGameEnd(
      result: result,
      finalPlayerScore: pScore,
      difficulty: state.difficulty,
      playerMovesThisGame: playerMoves,
    );

    state = state.copyWith(
      playerScore: pScore,
      computerScore: cScore,
      statistics: updatedStats,
      status: 'gameCompleted',
      lastMoveMessage:
          "Game Over! $deductionMessage Winner: ${result.toUpperCase()}.",
    );

    _persistence.saveStatistics(updatedStats);
    _persistence.deleteGameSave(); // Clear active save
  }

  // --- Setting updates ---

  void toggleSound(bool enabled) {
    final updated = state.settings.copyWith(soundEnabled: enabled);
    state = state.copyWith(settings: updated);
    _persistence.saveSettings(updated);
  }

  void toggleHaptics(bool enabled) {
    final updated = state.settings.copyWith(hapticEnabled: enabled);
    state = state.copyWith(settings: updated);
    _persistence.saveSettings(updated);
  }

  void toggleMusic(bool enabled) {
    final updated = state.settings.copyWith(musicEnabled: enabled);
    state = state.copyWith(settings: updated);
    _persistence.saveSettings(updated);
    MusicManager.instance.updateMusicState(enabled);
  }

  void setAnimationSpeed(double speed) {
    final updated = state.settings.copyWith(animationSpeed: speed);
    state = state.copyWith(settings: updated);
    _persistence.saveSettings(updated);
  }

  void resetStatistics() {
    const freshStats = Statistics();
    state = state.copyWith(statistics: freshStats);
    _persistence.saveStatistics(freshStats);
  }

  // --- Helpers ---

  List<List<BoardCell>> _cloneBoardGrid(List<List<BoardCell>> source) {
    return List.generate(GameConfig.boardSize, (r) {
      return List.generate(GameConfig.boardSize, (c) => source[r][c]);
    });
  }

  @override
  void dispose() {
    _aiAnimationTimer?.cancel();
    AIService.cancelCurrentTask();
    super.dispose();
  }
}
