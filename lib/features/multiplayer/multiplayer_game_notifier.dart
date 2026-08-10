import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../game_engine/game_config.dart';
import '../../game_engine/rules_validator.dart';
import '../../models/board_cell.dart';
import '../../models/game_state.dart';
import '../../models/multiplayer_game.dart';
import '../../models/tile.dart';
import '../game/game_notifier.dart';
import 'multiplayer_repository.dart';

class MultiplayerGameNotifier extends GameNotifier {
  final String gameId;
  final String opponentUserId;
  final MultiplayerRepository _repository;
  StreamSubscription<MultiplayerGame?>? _roomSubscription;

  MultiplayerGameNotifier({
    required this.gameId,
    required this.opponentUserId,
    required GameState initialState,
    MultiplayerRepository? repository,
  }) : _repository = repository ?? MultiplayerRepository(),
       super() {
    state = initialState;
    _roomSubscription = _repository
        .watchGame(gameId)
        .listen(_receiveRoomUpdate);
  }

  Future<void> _receiveRoomUpdate(MultiplayerGame? room) async {
    if (room == null || room.currentTurnUserId == null) return;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final snapshot = await _repository.loadGameState(gameId);
      final myTurn = snapshot.game.currentTurnUserId == currentUserId;
      final hydrated = snapshot.hydrate(state);
      if (snapshot.game.status != 'active') {
        state = hydrated.copyWith(
          currentTurn: 'computer',
          status: 'gamePaused',
          lastMoveMessage: 'This match has ended.',
        );
        return;
      }
      state = hydrated.copyWith(
        currentTurn: myTurn ? 'player' : 'computer',
        status: myTurn ? 'playerTurn' : 'waitingForOpponent',
        lastMoveMessage: myTurn
            ? 'Your turn — place your tiles!'
            : "Opponent's turn",
      );
    } catch (_) {
      // The realtime event can arrive before the private rack is readable.
    }
  }

  @override
  void handleTurnTimeout() {
    if (state.status != 'playerTurn' && state.status != 'waitingForOpponent') {
      return;
    }
    _timeoutTurn();
  }

  Future<void> _timeoutTurn() async {
    try {
      final snapshot = await _repository.timeoutTurn(gameId);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final myTurn = snapshot.game.currentTurnUserId == currentUserId;
      state = snapshot.hydrate(state).copyWith(
        currentTurn: myTurn ? 'player' : 'computer',
        status: myTurn ? 'playerTurn' : 'waitingForOpponent',
        lastMoveMessage: myTurn
            ? 'Your opponent ran out of time. Your turn.'
            : 'Time expired. Opponent\'s turn.',
      );
    } catch (_) {
      // A second client may have claimed the timeout first. Realtime will
      // deliver the authoritative state shortly afterward.
    }
  }

  List<List<BoardCell>> _cloneBoard(List<List<BoardCell>> source) {
    return List.generate(
      GameConfig.boardSize,
      (row) => List.generate(GameConfig.boardSize, (col) => source[row][col]),
    );
  }

  @override
  bool placeTile(Tile tile, int row, int col) {
    if (state.status != 'playerTurn' || state.currentTurn != 'player')
      return false;
    if (row < 0 ||
        row >= GameConfig.boardSize ||
        col < 0 ||
        col >= GameConfig.boardSize)
      return false;
    final cell = state.board[row][col];
    if (cell.tile != null) return false;
    final board = _cloneBoard(state.board);
    board[row][col] = cell.copyWith(tile: tile, isNewPlacement: true);
    final rack = List<Tile>.from(state.playerRack)
      ..removeWhere((item) => item.id == tile.id);
    state = state.copyWith(
      board: board,
      playerRack: rack,
      clearLastMoveMessage: true,
    );
    return true;
  }

  @override
  void setBlankLetter(int row, int col, String letter) {
    final cell = state.board[row][col];
    if (cell.tile == null || !cell.tile!.isBlank || !cell.isNewPlacement)
      return;
    final board = _cloneBoard(state.board);
    board[row][col] = cell.copyWith(
      tile: cell.tile!.copyWith(blankLetter: letter.toUpperCase()),
    );
    state = state.copyWith(board: board);
  }

  @override
  void recallAllNewPlacements() {
    if (state.currentTurn != 'player') return;
    final board = _cloneBoard(state.board);
    final rack = List<Tile>.from(state.playerRack);
    for (var row = 0; row < GameConfig.boardSize; row++) {
      for (var col = 0; col < GameConfig.boardSize; col++) {
        final cell = board[row][col];
        if (cell.tile != null && cell.isNewPlacement) {
          rack.add(
            cell.tile!.isBlank
                ? cell.tile!.copyWith(blankLetter: null)
                : cell.tile!,
          );
          board[row][col] = cell.copyWith(
            clearTile: true,
            isNewPlacement: false,
          );
        }
      }
    }
    state = state.copyWith(board: board, playerRack: rack);
  }

  @override
  void passTurn({bool isTimeout = false}) {
    if (state.currentTurn != 'player' || state.status != 'playerTurn') return;

    recallAllNewPlacements();
    final nextState = state.copyWith(
      consecutivePasses: state.consecutivePasses + 1,
      currentTurn: 'computer',
      status: 'waitingForOpponent',
      lastMoveMessage: "You passed your turn. Opponent's turn.",
    );
    state = nextState;
    _sync(nextState);
  }

  @override
  String? submitPlayerMove() {
    if (state.currentTurn != 'player' || state.status != 'playerTurn')
      return 'It is not your turn.';
    final validation = RulesValidator().validateMove(state.board);
    if (!validation.isValid) return validation.errorMessage;
    final board = _cloneBoard(state.board);
    for (var row = 0; row < GameConfig.boardSize; row++) {
      for (var col = 0; col < GameConfig.boardSize; col++) {
        if (board[row][col].isNewPlacement) {
          board[row][col] = board[row][col].copyWith(isNewPlacement: false);
        }
      }
    }
    final nextState = state.copyWith(
      board: board,
      playerScore: state.playerScore + validation.totalScore,
      currentTurn: 'computer',
      status: 'waitingForOpponent',
      moveHistory: state.moveHistory,
      lastMoveMessage: "Move submitted. Opponent's turn.",
    );
    state = nextState;
    _sync(nextState);
    return null;
  }

  Future<void> _sync(GameState nextState) async {
    try {
      final snapshot = await _repository.syncGameState(
        gameId: gameId,
        state: nextState,
        nextTurnUserId: opponentUserId,
      );
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final myTurn = snapshot.game.currentTurnUserId == currentUserId;
      state = snapshot.hydrate(state).copyWith(
        currentTurn: myTurn ? 'player' : 'computer',
        status: myTurn ? 'playerTurn' : 'waitingForOpponent',
      );
    } catch (_) {
      state = state.copyWith(
        currentTurn: 'player',
        status: 'playerTurn',
        lastMoveMessage: 'Move could not be synchronized.',
      );
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }
}

final multiplayerGameProvider =
    StateNotifierProvider<MultiplayerGameNotifier, GameState>((ref) {
      throw UnimplementedError('Override multiplayerGameProvider for a room.');
    });
