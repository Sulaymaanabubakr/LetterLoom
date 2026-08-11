class MultiplayerGame {
  final String id;
  final String roomCode;
  final String status;
  final String? currentTurnUserId;
  final int playerOneScore;
  final int playerTwoScore;
  final int consecutivePasses;
  final int moveNumber;
  final int playerCount;
  final String? createdByUserId;
  final bool isOwner;
  final List<dynamic> board;
  final DateTime? turnStartedAt;
  final DateTime? pausedAt;
  final String? pausedByUserId;
  final String mode;

  const MultiplayerGame({
    required this.id,
    required this.roomCode,
    required this.status,
    required this.currentTurnUserId,
    required this.playerOneScore,
    required this.playerTwoScore,
    this.consecutivePasses = 0,
    required this.moveNumber,
    this.playerCount = 0,
    this.createdByUserId,
    this.isOwner = false,
    this.board = const [],
    this.turnStartedAt,
    this.pausedAt,
    this.pausedByUserId,
    this.mode = 'casual',
  });

  factory MultiplayerGame.fromJson(Map<String, dynamic> json) {
    return MultiplayerGame(
      id: json['id'] as String,
      roomCode: json['room_code'] as String,
      status: json['status'] as String? ?? 'waiting',
      currentTurnUserId: json['current_turn_user_id'] as String?,
      playerOneScore: json['player_one_score'] as int? ?? 0,
      playerTwoScore: json['player_two_score'] as int? ?? 0,
      consecutivePasses: json['consecutive_passes'] as int? ?? 0,
      moveNumber: json['move_number'] as int? ?? 0,
      playerCount: json['player_count'] as int? ?? 0,
      createdByUserId: json['created_by_user_id'] as String?,
      isOwner: json['is_owner'] as bool? ?? false,
      board: json['board'] is List ? List<dynamic>.from(json['board'] as List) : const [],
      turnStartedAt: json['turn_started_at'] == null
          ? null
          : DateTime.tryParse(json['turn_started_at'] as String),
      pausedAt: json['paused_at'] == null
          ? null
          : DateTime.tryParse(json['paused_at'] as String),
      pausedByUserId: json['paused_by_user_id'] as String?,
      mode: json['mode'] as String? ?? 'casual',
    );
  }

  MultiplayerGame copyWith({bool? isOwner}) {
    return MultiplayerGame(
      id: id,
      roomCode: roomCode,
      status: status,
      currentTurnUserId: currentTurnUserId,
      playerOneScore: playerOneScore,
      playerTwoScore: playerTwoScore,
      consecutivePasses: consecutivePasses,
      moveNumber: moveNumber,
      playerCount: playerCount,
      createdByUserId: createdByUserId,
      isOwner: isOwner ?? this.isOwner,
      board: board,
      turnStartedAt: turnStartedAt,
      pausedAt: pausedAt,
      pausedByUserId: pausedByUserId,
      mode: mode,
    );
  }
}
