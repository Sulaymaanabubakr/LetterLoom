class MultiplayerGame {
  final String id;
  final String roomCode;
  final String status;
  final String? currentTurnUserId;
  final int playerOneScore;
  final int playerTwoScore;
  final int moveNumber;
  final int playerCount;
  final String? createdByUserId;
  final bool isOwner;
  final List<dynamic> board;

  const MultiplayerGame({
    required this.id,
    required this.roomCode,
    required this.status,
    required this.currentTurnUserId,
    required this.playerOneScore,
    required this.playerTwoScore,
    required this.moveNumber,
    this.playerCount = 0,
    this.createdByUserId,
    this.isOwner = false,
    this.board = const [],
  });

  factory MultiplayerGame.fromJson(Map<String, dynamic> json) {
    return MultiplayerGame(
      id: json['id'] as String,
      roomCode: json['room_code'] as String,
      status: json['status'] as String? ?? 'waiting',
      currentTurnUserId: json['current_turn_user_id'] as String?,
      playerOneScore: json['player_one_score'] as int? ?? 0,
      playerTwoScore: json['player_two_score'] as int? ?? 0,
      moveNumber: json['move_number'] as int? ?? 0,
      playerCount: json['player_count'] as int? ?? 0,
      createdByUserId: json['created_by_user_id'] as String?,
      isOwner: json['is_owner'] as bool? ?? false,
      board: json['board'] is List ? List<dynamic>.from(json['board'] as List) : const [],
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
      moveNumber: moveNumber,
      playerCount: playerCount,
      createdByUserId: createdByUserId,
      isOwner: isOwner ?? this.isOwner,
      board: board,
    );
  }
}
