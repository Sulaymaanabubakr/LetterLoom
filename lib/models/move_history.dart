class MoveHistory {
  final String player; // 'player' or 'computer'
  final String word;
  final int score;
  final String timestamp;
  final List<String> tilesUsed;
  final bool isPass;
  final bool isExchange;

  const MoveHistory({
    required this.player,
    required this.word,
    required this.score,
    required this.timestamp,
    required this.tilesUsed,
    this.isPass = false,
    this.isExchange = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'player': player,
      'word': word,
      'score': score,
      'timestamp': timestamp,
      'tilesUsed': tilesUsed,
      'isPass': isPass,
      'isExchange': isExchange,
    };
  }

  factory MoveHistory.fromJson(Map<String, dynamic> json) {
    return MoveHistory(
      player: json['player'] as String,
      word: json['word'] as String,
      score: json['score'] as int,
      timestamp: json['timestamp'] as String,
      tilesUsed: List<String>.from(json['tilesUsed'] as List),
      isPass: json['isPass'] as bool? ?? false,
      isExchange: json['isExchange'] as bool? ?? false,
    );
  }
}
