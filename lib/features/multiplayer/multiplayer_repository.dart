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
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const MultiplayerException(
        'Sign in with Google to use Multiplayer.',
      );
    }
  }

  Future<MultiplayerGame> createGame(
    String displayName, {
    int maxPlayers = 2,
  }) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'create-multiplayer-game',
      body: {
        'display_name': displayName.trim(),
        'max_players': maxPlayers.clamp(2, 4),
      },
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
      body: {'game_id': gameId, 'action': 'initialize'},
    );
    return MultiplayerStateSnapshot.fromJson(response.data);
  }

  Future<MultiplayerStateSnapshot> submitMove({
    required String gameId,
    required String clientActionId,
    required String moveType,
    List<Map<String, dynamic>> placements = const [],
    List<String> exchangeIds = const [],
  }) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {
        'game_id': gameId,
        'action': 'move',
        'client_action_id': clientActionId,
        'move_type': moveType,
        'placements': placements,
        'exchange_ids': exchangeIds,
      },
    );
    if (response.data is! Map || response.data['move'] is! Map) {
      throw const MultiplayerException(
        'The authoritative move response was incomplete.',
      );
    }
    return loadGameState(gameId);
  }

  Future<MultiplayerStateSnapshot> timeoutTurn(String gameId) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {'game_id': gameId, 'action': 'timeout'},
    );
    return MultiplayerStateSnapshot.fromJson(response.data);
  }

  Future<void> pauseGame(String gameId) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {'game_id': gameId, 'action': 'pause'},
    );
    if (response.data is! Map || response.data['pause'] == null) {
      throw const MultiplayerException('The match could not be paused.');
    }
  }

  Future<void> resumeGame(String gameId) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'multiplayer-game-state',
      body: {'game_id': gameId, 'action': 'resume'},
    );
    if (response.data is! Map || response.data['pause'] == null) {
      throw const MultiplayerException('The match could not be resumed.');
    }
  }

  Future<RankedMatchmakingResult> rankedMatchmaking({
    required String action,
    String? displayName,
  }) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'ranked-matchmaking',
      body: {
        'action': action,
        if (displayName != null) 'display_name': displayName.trim(),
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw const MultiplayerException(
        'The ranked queue response was incomplete.',
      );
    }
    return RankedMatchmakingResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> settleRankedMatch(String gameId) async {
    await ensureSignedIn();
    await _client.functions.invoke(
      'settle-ranked-match',
      body: {'game_id': gameId},
    );
  }

  Future<AgoraVoiceCredentials> requestVoiceToken(String gameId) async {
    await ensureSignedIn();
    final response = await _client.functions.invoke(
      'agora-voice-token',
      body: {'game_id': gameId},
    );
    if (response.data is! Map)
      throw const MultiplayerException('Voice chat is unavailable.');
    final data = Map<String, dynamic>.from(response.data as Map);
    return AgoraVoiceCredentials(
      appId: data['app_id'] as String,
      channel: data['channel'] as String,
      token: data['token'] as String,
      uid: (data['uid'] as num).toInt(),
      expiresAt: DateTime.parse(data['expires_at'] as String),
    );
  }

  Future<void> updateVoicePresence(
    String gameId, {
    required bool connected,
    required bool micEnabled,
  }) async {
    try {
      await _client.functions.invoke(
        'multiplayer-presence',
        body: {
          'game_id': gameId,
          'connected': connected,
          'mic_enabled': micEnabled,
        },
      );
    } catch (_) {
      // Presence is cosmetic and must never interrupt the board.
    }
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

class RankedMatchmakingResult {
  final String status;
  final MultiplayerGame? game;

  const RankedMatchmakingResult({required this.status, this.game});

  factory RankedMatchmakingResult.fromJson(Map<String, dynamic> json) {
    return RankedMatchmakingResult(
      status: json['status'] as String? ?? 'waiting',
      game: json['game'] is Map
          ? MultiplayerGame.fromJson(
              Map<String, dynamic>.from(json['game'] as Map),
            )
          : null,
    );
  }
}

class MultiplayerStateSnapshot {
  final MultiplayerGame game;
  final GameState? state;
  final List<dynamic> rack;
  final int tileCount;
  final List<dynamic> players;

  const MultiplayerStateSnapshot({
    required this.game,
    this.state,
    this.rack = const [],
    this.tileCount = 0,
    this.players = const [],
  });

  factory MultiplayerStateSnapshot.fromJson(dynamic raw) {
    if (raw is! Map || raw['game'] is! Map) {
      throw const MultiplayerException(
        'The multiplayer board response was incomplete.',
      );
    }
    final gameJson = Map<String, dynamic>.from(raw['game'] as Map);
    final rawPlayers = raw['players'] is List
        ? List<dynamic>.from(raw['players'] as List)
        : const <dynamic>[];
    gameJson['players'] = rawPlayers;
    return MultiplayerStateSnapshot(
      game: MultiplayerGame.fromJson(gameJson),
      rack: raw['rack'] is List
          ? List<dynamic>.from(raw['rack'] as List)
          : const [],
      tileCount: (raw['tile_count'] as num?)?.toInt() ?? 0,
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
    // GameState retains a bag collection for count-based UI and exchange
    // eligibility. These opaque placeholders deliberately carry no server
    // tile identity, order, letter, or score information.
    final bagTiles = List<Tile>.generate(
      tileCount,
      (index) => Tile(id: 'server-hidden-$index', letter: '?', scoreValue: 0),
      growable: false,
    );
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isPlayerOne = currentUserId == game.createdByUserId;
    final myScore = currentUserId == null
        ? 0
        : (game.playerScores[currentUserId] ??
              (isPlayerOne ? game.playerOneScore : game.playerTwoScore));
    final opponentScore = isPlayerOne
        ? game.playerTwoScore
        : game.playerOneScore;
    final isMyTurn = game.currentTurnUserId == currentUserId;
    return template.copyWith(
      board: board.length == 15 ? board : template.board,
      playerRack: rackTiles,
      tileBag: bagTiles,
      playerScore: myScore,
      computerScore: opponentScore,
      multiplayerScores: game.playerScores,
      multiplayerPlayers: game.players,
      multiplayerTurnUserId: game.currentTurnUserId,
      consecutivePasses: game.consecutivePasses,
      currentTurn: isMyTurn ? 'player' : 'computer',
      status: game.pausedAt != null
          ? 'gamePaused'
          : game.status == 'completed'
          ? 'gameCompleted'
          : game.status == 'active'
          ? (isMyTurn ? 'playerTurn' : 'waitingForOpponent')
          : 'gamePaused',
      lastMoveMessage: game.status == 'active'
          ? (isMyTurn ? 'Your turn: place your tiles!' : "Opponent's turn")
          : template.lastMoveMessage,
      turnStartedAt: game.turnStartedAt,
    );
  }
}

class AgoraVoiceCredentials {
  final String appId;
  final String channel;
  final String token;
  final int uid;
  final DateTime expiresAt;
  const AgoraVoiceCredentials({
    required this.appId,
    required this.channel,
    required this.token,
    required this.uid,
    required this.expiresAt,
  });
}

class MultiplayerException implements Exception {
  final String message;
  const MultiplayerException(this.message);
  @override
  String toString() => message;
}
