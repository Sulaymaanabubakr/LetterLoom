import 'dart:math';
import '../models/board_cell.dart';
import '../models/tile.dart';
import '../game_engine/rules_validator.dart';
import '../game_engine/game_config.dart';
import '../dictionary/dictionary_service.dart';

class PlacedTileInput {
  final String id;
  final String letter; // Original letter (' ' for blank)
  final int row;
  final int col;
  final bool isBlank;
  final String? blankLetter;

  PlacedTileInput({
    required this.id,
    required this.letter,
    required this.row,
    required this.col,
    required this.isBlank,
    this.blankLetter,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'letter': letter,
      'row': row,
      'col': col,
      'isBlank': isBlank,
      'blankLetter': blankLetter,
    };
  }

  factory PlacedTileInput.fromJson(Map<String, dynamic> json) {
    return PlacedTileInput(
      id: json['id'] as String,
      letter: json['letter'] as String,
      row: json['row'] as int,
      col: json['col'] as int,
      isBlank: json['isBlank'] as bool? ?? false,
      blankLetter: json['blankLetter'] as String?,
    );
  }
}

class AIMove {
  final List<PlacedTileInput> placements;
  final String word;
  final int score;
  final bool isPass;
  final bool isExchange;
  final List<String>? exchangeTileIds;

  const AIMove({
    required this.placements,
    required this.word,
    required this.score,
    this.isPass = false,
    this.isExchange = false,
    this.exchangeTileIds,
  });

  factory AIMove.pass() => const AIMove(placements: [], word: '', score: 0, isPass: true);
  
  factory AIMove.exchange(List<String> ids) => AIMove(
        placements: const [],
        word: '',
        score: 0,
        isExchange: true,
        exchangeTileIds: ids,
      );

  Map<String, dynamic> toJson() {
    return {
      'placements': placements.map((p) => p.toJson()).toList(),
      'word': word,
      'score': score,
      'isPass': isPass,
      'isExchange': isExchange,
      'exchangeTileIds': exchangeTileIds,
    };
  }

  factory AIMove.fromJson(Map<String, dynamic> json) {
    var rawPlacements = json['placements'] as List?;
    List<PlacedTileInput> parsedPlacements = rawPlacements != null
        ? rawPlacements.map((pJson) => PlacedTileInput.fromJson(pJson as Map<String, dynamic>)).toList()
        : [];
    return AIMove(
      placements: parsedPlacements,
      word: json['word'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      isPass: json['isPass'] as bool? ?? false,
      isExchange: json['isExchange'] as bool? ?? false,
      exchangeTileIds: json['exchangeTileIds'] != null
          ? List<String>.from(json['exchangeTileIds'] as List)
          : null,
    );
  }
}

class AIEngine {
  static final RulesValidator _rulesValidator = RulesValidator();
  static final DictionaryService _dictionaryService = DictionaryService();

  /// Computes the AI move. Designed to be run within an Isolate.
  /// Expects raw JSON-like arguments:
  /// `board`: List<List<Map<String, dynamic>>>
  /// `rack`: List<Map<String, dynamic>>
  /// `difficulty`: String
  /// Returns a Map representation of [AIMove].
  static Map<String, dynamic> computeMove(Map<String, dynamic> args) {
    final List<List<BoardCell>> grid = (args['board'] as List).map((row) {
      return (row as List).map((cellJson) => BoardCell.fromJson(cellJson as Map<String, dynamic>)).toList();
    }).toList();

    final List<Tile> rack = (args['rack'] as List)
        .map((tJson) => Tile.fromJson(tJson as Map<String, dynamic>))
        .toList();

    final String difficulty = args['difficulty'] as String? ?? 'easy';

    // Verify dictionary is loaded. In isolate execution, we might need to load mock words
    // if the dictionary wasn't initialized in the isolate. But in Flutter, rootBundle is
    // not directly available inside standard background isolates without setting up BinaryMessenger.
    // However, we pass the loaded words list or load it before starting isolate.
    // Better: We can pass the complete sorted word list or set of words from the main thread
    // if needed, or initialize DictionaryService with custom list.
    // Let's check if the word list was passed.
    if (args.containsKey('wordsList')) {
      final List<String> words = List<String>.from(args['wordsList'] as List);
      _dictionaryService.loadMock(words);
    }

    final AIMove selectedMove = _calculateMove(
      grid,
      rack,
      difficulty,
      deterministic: args['deterministic'] == true,
    );
    return selectedMove.toJson();
  }

  static AIMove _calculateMove(
    List<List<BoardCell>> grid,
    List<Tile> rack,
    String difficulty, {
    bool deterministic = false,
  }) {
    final List<AIMove> candidates = [];
    bool hasLockedTiles = false;

    // Check if board is empty
    for (int r = 0; r < GameConfig.boardSize; r++) {
      for (int c = 0; c < GameConfig.boardSize; c++) {
        if (grid[r][c].tile != null && !grid[r][c].isNewPlacement) {
          hasLockedTiles = true;
          break;
        }
      }
    }

    // 1. Generate horizontal and vertical candidates
    _searchLines(grid, rack, candidates, hasLockedTiles, isHorizontal: true);
    _searchLines(grid, rack, candidates, hasLockedTiles, isHorizontal: false);

    if (candidates.isEmpty) {
      // No moves found. Attempt tile exchange if tile bag is not empty.
      // We can exchange tiles or pass.
      // If AI cannot play, it should try to exchange if rack is not empty, otherwise pass.
      if (rack.isNotEmpty) {
        // Exchange up to all tiles
        final idsToExchange = rack.map((t) => t.id).toList();
        return AIMove.exchange(idsToExchange);
      }
      return AIMove.pass();
    }

    // Sort candidates by score descending
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final random = Random();
    if (difficulty == 'hard') {
      // Daily Challenge passes deterministic=true so its advertised optimum
      // is stable across runs. Normal hard AI retains variety.
      if (deterministic) return candidates.first;
      final limit = min(3, candidates.length);
      return candidates[random.nextInt(limit)];
    } else if (difficulty == 'medium') {
      // Pick a moderately scoring move (middle tier: 40th to 80th percentile)
      final int start = (candidates.length * 0.2).toInt();
      final int end = (candidates.length * 0.6).toInt();
      final int range = max(1, end - start);
      final int index = start + random.nextInt(range);
      return candidates[index < candidates.length ? index : candidates.length - 1];
    } else {
      // Easy difficulty: Prefer simple, short words with lower scores (0th to 30th percentile)
      final int start = (candidates.length * 0.6).toInt();
      final int end = candidates.length - 1;
      final int range = max(1, end - start);
      final int index = start + random.nextInt(range);
      return candidates[index < candidates.length ? index : candidates.length - 1];
    }
  }

  static void _searchLines(
    List<List<BoardCell>> grid,
    List<Tile> rack,
    List<AIMove> candidates,
    bool hasLockedTiles, {
    required bool isHorizontal,
  }) {
    // Traverse each line of the board
    for (int i = 0; i < GameConfig.boardSize; i++) {
      // Extract the line cells
      final List<BoardCell> line = [];
      for (int j = 0; j < GameConfig.boardSize; j++) {
        line.add(isHorizontal ? grid[i][j] : grid[j][i]);
      }

      // Find possible word intervals [start, end]
      for (int start = 0; start < GameConfig.boardSize; start++) {
        // Left/top cell before the word must be empty
        if (start > 0 && line[start - 1].tile != null) continue;

        for (int end = start + 1; end < GameConfig.boardSize; end++) {
          // Right/bottom cell after the word must be empty
          if (end < GameConfig.boardSize - 1 && line[end + 1].tile != null) continue;

          // Check if this interval overlaps with at least one anchor cell
          bool hasAnchor = false;
          int emptyCount = 0;
          for (int idx = start; idx <= end; idx++) {
            final cell = line[idx];
            if (cell.tile == null) {
              emptyCount++;
              // Check if cell is an anchor
              if (!hasLockedTiles) {
                // First turn: centre square (7,7) is the anchor
                if (isHorizontal) {
                  if (i == 7 && idx == 7) hasAnchor = true;
                } else {
                  if (idx == 7 && i == 7) hasAnchor = true;
                }
              } else {
                // Standard turn: check perpendicular or adjacent neighbors for locked tiles
                final r = isHorizontal ? i : idx;
                final c = isHorizontal ? idx : i;
                final neighbors = [
                  if (r > 0) grid[r - 1][c],
                  if (r < GameConfig.boardSize - 1) grid[r + 1][c],
                  if (c > 0) grid[r][c - 1],
                  if (c < GameConfig.boardSize - 1) grid[r][c + 1],
                ];
                if (neighbors.any((n) => n.tile != null && !n.isNewPlacement)) {
                  hasAnchor = true;
                }
              }
            }
          }

          // We must place at least 1 tile and cannot place more than our rack size
          if (emptyCount < 1 || emptyCount > rack.length) continue;
          if (!hasAnchor && hasLockedTiles) continue; // Must connect if not first move

          // Run backtracking search to fill empty cells in this interval
          _backtrackFill(
            grid: grid,
            line: line,
            rack: rack,
            startIdx: start,
            endIdx: end,
            currentIdx: start,
            currentPrefix: '',
            usedRackIndices: {},
            placements: [],
            candidates: candidates,
            isHorizontal: isHorizontal,
            lineIndex: i,
          );
        }
      }
    }
  }

  static void _backtrackFill({
    required List<List<BoardCell>> grid,
    required List<BoardCell> line,
    required List<Tile> rack,
    required int startIdx,
    required int endIdx,
    required int currentIdx,
    required String currentPrefix,
    required Set<int> usedRackIndices,
    required List<PlacedTileInput> placements,
    required List<AIMove> candidates,
    required bool isHorizontal,
    required int lineIndex,
  }) {
    if (currentIdx > endIdx) {
      // We filled the interval! Validate word in dictionary first
      if (_dictionaryService.isValidWord(currentPrefix)) {
        // Construct a mock grid with these placements to run full RulesValidator check
        final mockGrid = List.generate(GameConfig.boardSize, (r) {
          return List.generate(GameConfig.boardSize, (c) => grid[r][c]);
        });

        for (var p in placements) {
          final mockTile = Tile(
            id: p.id,
            letter: p.letter,
            scoreValue: p.isBlank ? 0 : GameConfig.letterScores[p.letter] ?? 0,
            isBlank: p.isBlank,
            blankLetter: p.blankLetter,
          );
          mockGrid[p.row][p.col] = mockGrid[p.row][p.col].copyWith(
            tile: mockTile,
            isNewPlacement: true,
          );
        }

        final validation = _rulesValidator.validateMove(mockGrid);
        if (validation.isValid) {
          candidates.add(AIMove(
            placements: List.from(placements),
            word: currentPrefix,
            score: validation.totalScore,
          ));
        }
      }
      return;
    }

    final cell = line[currentIdx];
    final row = isHorizontal ? lineIndex : currentIdx;
    final col = isHorizontal ? currentIdx : lineIndex;

    if (cell.tile != null) {
      // Must use existing tile letter
      final String nextPrefix = currentPrefix + cell.tile!.displayLetter;
      if (_dictionaryService.isValidPrefix(nextPrefix)) {
        _backtrackFill(
          grid: grid,
          line: line,
          rack: rack,
          startIdx: startIdx,
          endIdx: endIdx,
          currentIdx: currentIdx + 1,
          currentPrefix: nextPrefix,
          usedRackIndices: usedRackIndices,
          placements: placements,
          candidates: candidates,
          isHorizontal: isHorizontal,
          lineIndex: lineIndex,
        );
      }
    } else {
      // Try placing each unused tile from the rack
      for (int i = 0; i < rack.length; i++) {
        if (usedRackIndices.contains(i)) continue;

        final tile = rack[i];
        if (tile.isBlank) {
          // Blank tile: can stand for any letter A..Z
          for (var code = 65; code <= 90; code++) {
            final String letter = String.fromCharCode(code);
            final String nextPrefix = currentPrefix + letter;
            if (_dictionaryService.isValidPrefix(nextPrefix)) {
              usedRackIndices.add(i);
              placements.add(PlacedTileInput(
                id: tile.id,
                letter: ' ',
                row: row,
                col: col,
                isBlank: true,
                blankLetter: letter,
              ));

              _backtrackFill(
                grid: grid,
                line: line,
                rack: rack,
                startIdx: startIdx,
                endIdx: endIdx,
                currentIdx: currentIdx + 1,
                currentPrefix: nextPrefix,
                usedRackIndices: usedRackIndices,
                placements: placements,
                candidates: candidates,
                isHorizontal: isHorizontal,
                lineIndex: lineIndex,
              );

              placements.removeLast();
              usedRackIndices.remove(i);
            }
          }
        } else {
          // Normal tile
          final String nextPrefix = currentPrefix + tile.letter;
          if (_dictionaryService.isValidPrefix(nextPrefix)) {
            usedRackIndices.add(i);
            placements.add(PlacedTileInput(
              id: tile.id,
              letter: tile.letter,
              row: row,
              col: col,
              isBlank: false,
            ));

            _backtrackFill(
              grid: grid,
              line: line,
              rack: rack,
              startIdx: startIdx,
              endIdx: endIdx,
              currentIdx: currentIdx + 1,
              currentPrefix: nextPrefix,
              usedRackIndices: usedRackIndices,
              placements: placements,
              candidates: candidates,
              isHorizontal: isHorizontal,
              lineIndex: lineIndex,
            );

            placements.removeLast();
            usedRackIndices.remove(i);
          }
        }
      }
    }
  }
}
