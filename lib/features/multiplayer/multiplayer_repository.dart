import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_bootstrap.dart';
import '../../models/multiplayer_game.dart';
import '../../models/game_state.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';

class MultiplayerRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> ensureSignedIn() async {
    if (!SupabaseBootstrap.configured) {
      throw const MultiplayerException(
        'Online play is not configured for this build.',
      );
    }
    if (_client.auth.currentSession == null) {
      AuthResponse response;
      try {
        response = await _client.auth.signInAnonymously();
      } on AuthException catch (error) {
        if (error.code == 'anonymous_provider_disabled') {
          throw const MultiplayerException(
            'Online play needs Anonymous Sign-Ins enabled in the LetterLoom Supabase project.',
          );
        }
        throw MultiplayerException(error.message);
      }
      if (response.user == null) {
        throw const MultiplayerException(
          'Could not start your online session.',
        );
      }
    }
  }

  Future<MultiplayerGame> createGame(String displayName) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'create-multiplayer-game',
      body: {'display_name': displayName.trim()},
    );
    return _readGame(response.data);
  }

  Future<MultiplayerRooms> loadRooms() async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'list-multiplayer-games',
      body: const {},
    );
    final data = response.data;
    if (data is! Map) {
      throw const MultiplayerException(
        'The room list response was incomplete.',
      );
    }
    return MultiplayerRooms.fromJson(Map<String, dynamic>.from(data));
  }

  Future<MultiplayerGame?> manageRoom(String gameId, String action) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'manage-multiplayer-room',
      body: {'game_id': gameId, 'action': action},
    );
    final data = response.data;
    if (action == 'delete' || action == 'leave') return null;
    if (data is Map && data['game'] is Map) {
      return MultiplayerGame.fromJson(
        Map<String, dynamic>.from(data['game'] as Map),
      );
    }
    throw const MultiplayerException(
      'The room update response was incomplete.',
    );
  }

  Future<MultiplayerStateSnapshot> loadGameState(String gameId) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {'game_id': gameId, 'action': 'get'},
    );
    return MultiplayerStateSnapshot.fromJson(response.data);
  }

  Future<MultiplayerStateSnapshot> initializeGameState(
    String gameId,
    GameState state,
  ) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {
        'game_id': gameId,
        'action': 'initialize',
        'state': state.toJson(),
      },
    );
    return MultiplayerStateSnapshot.fromJson(response.data);
  }

  Future<MultiplayerStateSnapshot> restartGameState(
    String gameId,
    GameState state,
  ) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {'game_id': gameId, 'action': 'restart', 'state': state.toJson()},
    );
    return MultiplayerStateSnapshot.fromJson(response.data);
  }

  Future<MultiplayerStateSnapshot> syncGameState({
    required String gameId,
    required GameState state,
    required String nextTurnUserId,
  }) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {
        'game_id': gameId,
        'action': 'sync',
        'state': state.toJson(),
        'next_turn_user_id': nextTurnUserId,
      },
    );
    return MultiplayerStateSnapshot.fromJson(response.data);
  }

  Future<MultiplayerStateSnapshot> timeoutTurn(String gameId) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {'game_id': gameId, 'action': 'timeout'},
    );
    return MultiplayerStateSnapshot.fromJson(response.data);
  }

  Future<MultiplayerGame> joinGame(String roomCode, String displayName) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'join-multiplayer-game',
      body: {
        'room_code': roomCode.trim().toUpperCase(),
        'display_name': displayName.trim(),
      },
    );
    return _readGame(response.data);
  }

  Stream<MultiplayerGame?> watchGame(String gameId) {
    return _client
        .from('multiplayer_games')
        .stream(primaryKey: ['id'])
        .eq('id', gameId)
        .map(
          (rows) => rows.isEmpty ? null : MultiplayerGame.fromJson(rows.first),
        );
  }

  MultiplayerGame _readGame(dynamic data) {
    if (data is! Map || data['game'] is! Map) {
      throw const MultiplayerException(
        'The online game response was incomplete.',
      );
    }
    return MultiplayerGame.fromJson(
      Map<String, dynamic>.from(data['game'] as Map),
    );
  }
}

class MultiplayerRooms {
  final List<MultiplayerGame> myGames;
  final List<MultiplayerGame> availableGames;

  const MultiplayerRooms({required this.myGames, required this.availableGames});

  factory MultiplayerRooms.fromJson(Map<String, dynamic> json) {
    List<MultiplayerGame> read(String key) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) => MultiplayerGame.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    return MultiplayerRooms(
      myGames: read('my_games'),
      availableGames: read('available_games'),
    );
  }
}

class MultiplayerStateSnapshot {
  final MultiplayerGame game;
  final GameState? state;
  final List<dynamic> rack;
  final List<dynamic> tileBag;
  final List<dynamic> players;

  const MultiplayerStateSnapshot({
    required this.game,
    this.state,
    this.rack = const [],
    this.tileBag = const [],
    this.players = const [],
  });

  factory MultiplayerStateSnapshot.fromJson(dynamic raw) {
    if (raw is! Map || raw['game'] is! Map) {
      throw const MultiplayerException(
        'The multiplayer board response was incomplete.',
      );
    }
    return MultiplayerStateSnapshot(
      game: MultiplayerGame.fromJson(
        Map<String, dynamic>.from(raw['game'] as Map),
      ),
      rack: raw['rack'] is List
          ? List<dynamic>.from(raw['rack'] as List)
          : const [],
      tileBag: raw['tile_bag'] is List
          ? List<dynamic>.from(raw['tile_bag'] as List)
          : const [],
      players: raw['players'] is List
          ? List<dynamic>.from(raw['players'] as List)
          : const [],
    );
  }

  GameState hydrate(GameState template) {
    final board = game.board
        .whereType<List>()
        .map(
          (row) => row
              .whereType<Map>()
              .map(
                (cell) => BoardCell.fromJson(Map<String, dynamic>.from(cell)),
              )
              .toList(),
        )
        .toList();
    final rackTiles = rack
        .whereType<Map>()
        .map((tile) => Tile.fromJson(Map<String, dynamic>.from(tile)))
        .toList();
    final bagTiles = tileBag
        .whereType<Map>()
        .map((tile) => Tile.fromJson(Map<String, dynamic>.from(tile)))
        .toList();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isPlayerOne = currentUserId == game.createdByUserId;
    final isMyTurn = game.currentTurnUserId == currentUserId;
    return template.copyWith(
      board: board.length == 15 ? board : template.board,
      playerRack: rackTiles,
      tileBag: bagTiles,
      playerScore: isPlayerOne ? game.playerOneScore : game.playerTwoScore,
      computerScore: isPlayerOne ? game.playerTwoScore : game.playerOneScore,
      consecutivePasses: game.consecutivePasses,
      currentTurn: isMyTurn ? 'player' : 'computer',
      status: game.status == 'active'
          ? (isMyTurn ? 'playerTurn' : 'waitingForOpponent')
          : 'gamePaused',
      lastMoveMessage: game.status == 'active'
          ? (isMyTurn ? 'Your turn — place your tiles!' : "Opponent's turn")
          : template.lastMoveMessage,
      turnStartedAt: game.turnStartedAt,
    );
  }
}

class MultiplayerException implements Exception {
  final String message;
  const MultiplayerException(this.message);
  @override
  String toString() => message;
}
