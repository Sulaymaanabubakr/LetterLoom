class Tile {
  final String id;
  final String letter; // ' ' for blank, uppercase letters otherwise
  final int scoreValue;
  final bool isBlank;
  final String? blankLetter; // E.g., 'A' if representing 'A'

  const Tile({
    required this.id,
    required this.letter,
    required this.scoreValue,
    this.isBlank = false,
    this.blankLetter,
  });

  String get displayLetter => isBlank ? (blankLetter ?? ' ') : letter;

  Tile copyWith({
    String? id,
    String? letter,
    int? scoreValue,
    bool? isBlank,
    String? blankLetter,
  }) {
    return Tile(
      id: id ?? this.id,
      letter: letter ?? this.letter,
      scoreValue: scoreValue ?? this.scoreValue,
      isBlank: isBlank ?? this.isBlank,
      blankLetter: blankLetter ?? this.blankLetter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'letter': letter,
      'scoreValue': scoreValue,
      'isBlank': isBlank,
      'blankLetter': blankLetter,
    };
  }

  factory Tile.fromJson(Map<String, dynamic> json) {
    return Tile(
      id: json['id'] as String,
      letter: json['letter'] as String,
      scoreValue: json['scoreValue'] as int,
      isBlank: json['isBlank'] as bool? ?? false,
      blankLetter: json['blankLetter'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tile &&
        other.id == id &&
        other.letter == letter &&
        other.scoreValue == scoreValue &&
        other.isBlank == isBlank &&
        other.blankLetter == blankLetter;
  }

  @override
  int get hashCode => Object.hash(id, letter, scoreValue, isBlank, blankLetter);
}
