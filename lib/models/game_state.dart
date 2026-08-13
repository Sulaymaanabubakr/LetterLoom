import 'board_cell.dart';
import 'tile.dart';
import 'move_history.dart';
import 'game_settings.dart';
import 'statistics.dart';
import 'multiplayer_game.dart';

class GameState {
  static const int turnDurationSeconds = 120;
  final List<List<BoardCell>> board;
  final List<Tile> playerRack;
  final List<Tile> computerRack;
  final List<Tile> tileBag;
  final int playerScore;
  final int computerScore;
  final String currentTurn; // 'player' or 'computer'
  final String difficulty; // 'easy', 'medium', 'hard'
  final int consecutivePasses;
  final List<MoveHistory> moveHistory;
  final String
  status; // 'playerTurn', 'validatingPlayerMove', 'computerThinking', 'animatingComputerMove', 'gamePaused', 'gameCompleted'
  final GameSettings settings;
  final Statistics statistics;
  final String? lastMoveMessage; // Information about the last move
  final DateTime? turnStartedAt;
  final int? turnSecondsRemaining;
  final Map<String, int> multiplayerScores;
  final List<MultiplayerPlayer> multiplayerPlayers;

  const GameState({
    required this.board,
    required this.playerRack,
    required this.computerRack,
    required this.tileBag,
    required this.playerScore,
    required this.computerScore,
    required this.currentTurn,
    required this.difficulty,
    required this.consecutivePasses,
    required this.moveHistory,
    required this.status,
    required this.settings,
    required this.statistics,
    this.lastMoveMessage,
    this.turnStartedAt,
    this.turnSecondsRemaining,
    this.multiplayerScores = const {},
    this.multiplayerPlayers = const [],
  });

  GameState copyWith({
    List<List<BoardCell>>? board,
    List<Tile>? playerRack,
    List<Tile>? computerRack,
    List<Tile>? tileBag,
    int? playerScore,
    int? computerScore,
    String? currentTurn,
    String? difficulty,
    int? consecutivePasses,
    List<MoveHistory>? moveHistory,
    String? status,
    GameSettings? settings,
    Statistics? statistics,
    String? lastMoveMessage,
    bool clearLastMoveMessage = false,
    DateTime? turnStartedAt,
    int? turnSecondsRemaining,
    bool clearTurnSecondsRemaining = false,
    Map<String, int>? multiplayerScores,
    List<MultiplayerPlayer>? multiplayerPlayers,
  }) {
    return GameState(
      board: board ?? this.board,
      playerRack: playerRack ?? this.playerRack,
      computerRack: computerRack ?? this.computerRack,
      tileBag: tileBag ?? this.tileBag,
      playerScore: playerScore ?? this.playerScore,
      computerScore: computerScore ?? this.computerScore,
      currentTurn: currentTurn ?? this.currentTurn,
      difficulty: difficulty ?? this.difficulty,
      consecutivePasses: consecutivePasses ?? this.consecutivePasses,
      moveHistory: moveHistory ?? this.moveHistory,
      status: status ?? this.status,
      settings: settings ?? this.settings,
      statistics: statistics ?? this.statistics,
      lastMoveMessage: clearLastMoveMessage
          ? null
          : (lastMoveMessage ?? this.lastMoveMessage),
      turnStartedAt: turnStartedAt ?? this.turnStartedAt,
      turnSecondsRemaining: clearTurnSecondsRemaining
          ? null
          : (turnSecondsRemaining ?? this.turnSecondsRemaining),
      multiplayerScores: multiplayerScores ?? this.multiplayerScores,
      multiplayerPlayers: multiplayerPlayers ?? this.multiplayerPlayers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'board': board
          .map((row) => row.map((cell) => cell.toJson()).toList())
          .toList(),
      'playerRack': playerRack.map((t) => t.toJson()).toList(),
      'computerRack': computerRack.map((t) => t.toJson()).toList(),
      'tileBag': tileBag.map((t) => t.toJson()).toList(),
      'playerScore': playerScore,
      'computerScore': computerScore,
      'currentTurn': currentTurn,
      'difficulty': difficulty,
      'consecutivePasses': consecutivePasses,
      'moveHistory': moveHistory.map((m) => m.toJson()).toList(),
      'status': status,
      'settings': settings.toJson(),
      'statistics': statistics.toJson(),
      'lastMoveMessage': lastMoveMessage,
      'turnStartedAt': turnStartedAt?.toIso8601String(),
      'turnSecondsRemaining': turnSecondsRemaining,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    var rawBoard = json['board'] as List;
    List<List<BoardCell>> parsedBoard = rawBoard.map((row) {
      return (row as List).map((cellJson) {
        return BoardCell.fromJson(cellJson as Map<String, dynamic>);
      }).toList();
    }).toList();

    var rawPlayerRack = json['playerRack'] as List;
    List<Tile> parsedPlayerRack = rawPlayerRack
        .map((tJson) => Tile.fromJson(tJson as Map<String, dynamic>))
        .toList();

    var rawComputerRack = json['computerRack'] as List;
    List<Tile> parsedComputerRack = rawComputerRack
        .map((tJson) => Tile.fromJson(tJson as Map<String, dynamic>))
        .toList();

    var rawTileBag = json['tileBag'] as List;
    List<Tile> parsedTileBag = rawTileBag
        .map((tJson) => Tile.fromJson(tJson as Map<String, dynamic>))
        .toList();

    var rawMoveHistory = json['moveHistory'] as List;
    List<MoveHistory> parsedMoveHistory = rawMoveHistory
        .map((mJson) => MoveHistory.fromJson(mJson as Map<String, dynamic>))
        .toList();

    return GameState(
      board: parsedBoard,
      playerRack: parsedPlayerRack,
      computerRack: parsedComputerRack,
      tileBag: parsedTileBag,
      playerScore: json['playerScore'] as int,
      computerScore: json['computerScore'] as int,
      currentTurn: json['currentTurn'] as String,
      difficulty: json['difficulty'] as String? ?? 'easy',
      consecutivePasses: json['consecutivePasses'] as int? ?? 0,
      moveHistory: parsedMoveHistory,
      status: json['status'] as String,
      settings: GameSettings.fromJson(json['settings'] as Map<String, dynamic>),
      statistics: Statistics.fromJson(
        json['statistics'] as Map<String, dynamic>,
      ),
      lastMoveMessage: json['lastMoveMessage'] as String?,
      turnStartedAt: json['turnStartedAt'] == null
          ? null
          : DateTime.tryParse(json['turnStartedAt'] as String),
      turnSecondsRemaining: (json['turnSecondsRemaining'] as num?)?.toInt(),
    );
  }
}
