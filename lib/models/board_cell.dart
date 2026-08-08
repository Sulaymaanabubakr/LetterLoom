import 'tile.dart';

enum CellType {
  normal,
  doubleLetter,
  tripleLetter,
  doubleWord,
  tripleWord,
  centre,
}

class BoardCell {
  final int row;
  final int col;
  final CellType type;
  final Tile? tile;
  final bool isNewPlacement; // True if placed this turn (can be recalled)

  const BoardCell({
    required this.row,
    required this.col,
    required this.type,
    this.tile,
    this.isNewPlacement = false,
  });

  bool get hasTile => tile != null;

  int get letterMultiplier {
    switch (type) {
      case CellType.doubleLetter:
        return 2;
      case CellType.tripleLetter:
        return 3;
      default:
        return 1;
    }
  }

  int get wordMultiplier {
    switch (type) {
      case CellType.doubleWord:
      case CellType.centre: // Centre square acts as a Double Word multiplier in standard rules
        return 2;
      case CellType.tripleWord:
        return 3;
      default:
        return 1;
    }
  }

  BoardCell copyWith({
    int? row,
    int? col,
    CellType? type,
    Tile? tile,
    bool clearTile = false,
    bool? isNewPlacement,
  }) {
    return BoardCell(
      row: row ?? this.row,
      col: col ?? this.col,
      type: type ?? this.type,
      tile: clearTile ? null : (tile ?? this.tile),
      isNewPlacement: isNewPlacement ?? this.isNewPlacement,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'type': type.name,
      'tile': tile?.toJson(),
      'isNewPlacement': isNewPlacement,
    };
  }

  factory BoardCell.fromJson(Map<String, dynamic> json) {
    return BoardCell(
      row: json['row'] as int,
      col: json['col'] as int,
      type: CellType.values.firstWhere((e) => e.name == json['type']),
      tile: json['tile'] != null
          ? Tile.fromJson(json['tile'] as Map<String, dynamic>)
          : null,
      isNewPlacement: json['isNewPlacement'] as bool? ?? false,
    );
  }
}
