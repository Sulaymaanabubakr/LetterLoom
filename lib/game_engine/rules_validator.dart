import '../models/board_cell.dart';
import '../dictionary/dictionary_service.dart';
import 'game_config.dart';

class WordResult {
  final String word;
  final int score;
  final List<BoardCell> cells;

  const WordResult({
    required this.word,
    required this.score,
    required this.cells,
  });
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<WordResult> wordsFormed;
  final int totalScore;
  final bool isBingo;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.wordsFormed = const [],
    this.totalScore = 0,
    this.isBingo = false,
  });

  factory ValidationResult.invalid(String message) {
    return ValidationResult(isValid: false, errorMessage: message);
  }
}

class RulesValidator {
  final DictionaryService _dictionaryService = DictionaryService();

  /// Validates the player's proposed move on the current board.
  /// Returns a detailed [ValidationResult].
  ValidationResult validateMove(List<List<BoardCell>> boardGrid) {
    // 1. Gather all newly placed cells
    final List<BoardCell> newCells = [];
    bool hasLockedTiles = false;

    for (int r = 0; r < GameConfig.boardSize; r++) {
      for (int c = 0; c < GameConfig.boardSize; c++) {
        final cell = boardGrid[r][c];
        if (cell.tile != null) {
          if (cell.isNewPlacement) {
            newCells.add(cell);
          } else {
            hasLockedTiles = true;
          }
        }
      }
    }

    // Rule: At least one new tile must be placed
    if (newCells.isEmpty) {
      return ValidationResult.invalid("You must place at least one tile to make a move.");
    }

    // Rule: First word must cross the centre square (7, 7)
    final bool isFirstMove = !hasLockedTiles;
    if (isFirstMove) {
      final coversCentre = newCells.any((cell) => cell.row == 7 && cell.col == 7);
      if (!coversCentre) {
        return ValidationResult.invalid("The first word placed must cross the centre starting square.");
      }
    }

    // Rule: If placing multiple tiles, they must be in a single straight row or column
    int minRow = 99, maxRow = -1;
    int minCol = 99, maxCol = -1;
    for (var cell in newCells) {
      if (cell.row < minRow) minRow = cell.row;
      if (cell.row > maxRow) maxRow = cell.row;
      if (cell.col < minCol) minCol = cell.col;
      if (cell.col > maxCol) maxCol = cell.col;
    }

    final bool isHorizontal = minRow == maxRow;
    final bool isVertical = minCol == maxCol;

    if (newCells.length > 1 && !isHorizontal && !isVertical) {
      return ValidationResult.invalid("All placed tiles must be aligned in a single row or column.");
    }

    // Rule: No gaps between the new tiles (including intermediate existing tiles)
    if (newCells.length > 1) {
      if (isHorizontal) {
        final int r = minRow;
        for (int c = minCol; c <= maxCol; c++) {
          if (boardGrid[r][c].tile == null) {
            return ValidationResult.invalid("Placed tiles must form a contiguous line without gaps.");
          }
        }
      } else {
        final int c = minCol;
        for (int r = minRow; r <= maxRow; r++) {
          if (boardGrid[r][c].tile == null) {
            return ValidationResult.invalid("Placed tiles must form a contiguous line without gaps.");
          }
        }
      }
    }

    // Rule: Connectivity. Except for first move, at least one placed tile must connect with an existing locked tile
    if (!isFirstMove) {
      bool connects = false;
      for (var cell in newCells) {
        // Check adjacent orthogonal cells
        final adjacents = [
          if (cell.row > 0) boardGrid[cell.row - 1][cell.col],
          if (cell.row < GameConfig.boardSize - 1) boardGrid[cell.row + 1][cell.col],
          if (cell.col > 0) boardGrid[cell.row][cell.col - 1],
          if (cell.col < GameConfig.boardSize - 1) boardGrid[cell.row][cell.col + 1],
        ];
        if (adjacents.any((adj) => adj.tile != null && !adj.isNewPlacement)) {
          connects = true;
          break;
        }
      }
      if (!connects) {
        return ValidationResult.invalid("Your word must connect to at least one existing word on the board.");
      }
    }

    // 2. Extract and score all newly formed words
    final List<WordResult> wordsFormed = [];

    if (newCells.length == 1) {
      // Single tile placed: could form a horizontal word, vertical word, or both.
      final cell = newCells.first;
      final WordResult? hWord = _traceHorizontalWord(boardGrid, cell.row, cell.col);
      final WordResult? vWord = _traceVerticalWord(boardGrid, cell.row, cell.col);

      if (hWord != null) wordsFormed.add(hWord);
      if (vWord != null) wordsFormed.add(vWord);

      if (wordsFormed.isEmpty) {
        // A single tile isolated on the first move is invalid since words must be at least 2 letters
        return ValidationResult.invalid("A word must consist of at least two letters.");
      }
    } else if (isHorizontal) {
      // Horizontal placement: trace the main horizontal word once
      final mainWord = _traceHorizontalWord(boardGrid, minRow, minCol);
      if (mainWord == null || mainWord.word.length < 2) {
        return ValidationResult.invalid("The main word must consist of at least two letters.");
      }
      wordsFormed.add(mainWord);

      // Check perpendicular vertical cross-words for each placed cell
      for (var cell in newCells) {
        final crossWord = _traceVerticalWord(boardGrid, cell.row, cell.col);
        if (crossWord != null) {
          if (crossWord.word.length >= 2) {
            wordsFormed.add(crossWord);
          }
        }
      }
    } else {
      // Vertical placement: trace the main vertical word once
      final mainWord = _traceVerticalWord(boardGrid, minRow, minCol);
      if (mainWord == null || mainWord.word.length < 2) {
        return ValidationResult.invalid("The main word must consist of at least two letters.");
      }
      wordsFormed.add(mainWord);

      // Check perpendicular horizontal cross-words for each placed cell
      for (var cell in newCells) {
        final crossWord = _traceHorizontalWord(boardGrid, cell.row, cell.col);
        if (crossWord != null) {
          if (crossWord.word.length >= 2) {
            wordsFormed.add(crossWord);
          }
        }
      }
    }

    // Rule: Every word formed must be a valid dictionary word
    for (var wr in wordsFormed) {
      if (!_dictionaryService.isValidWord(wr.word)) {
        return ValidationResult.invalid("'${wr.word}' is not a valid word in the dictionary.");
      }
    }

    // 3. Score Calculations
    int totalScore = 0;
    for (var wr in wordsFormed) {
      totalScore += wr.score;
    }

    // Bingo Bonus: 50 points if player used exactly 7 tiles from rack
    final bool isBingo = newCells.length == GameConfig.rackSize;
    if (isBingo) {
      totalScore += GameConfig.bingoBonus;
    }

    return ValidationResult(
      isValid: true,
      wordsFormed: wordsFormed,
      totalScore: totalScore,
      isBingo: isBingo,
    );
  }

  /// Traces a horizontal word containing cell at (row, col)
  WordResult? _traceHorizontalWord(List<List<BoardCell>> grid, int row, int col) {
    if (grid[row][col].tile == null) return null;

    // Find starting column
    int startCol = col;
    while (startCol > 0 && grid[row][startCol - 1].tile != null) {
      startCol--;
    }

    // Find ending column
    int endCol = col;
    while (endCol < GameConfig.boardSize - 1 && grid[row][endCol + 1].tile != null) {
      endCol++;
    }

    // If word is only 1 letter, we only return it if it is a single-tile placement turn
    if (startCol == endCol) return null;

    final List<BoardCell> cells = [];
    final StringBuffer sb = StringBuffer();
    int wordMultiplier = 1;
    int scoreSum = 0;

    for (int c = startCol; c <= endCol; c++) {
      final cell = grid[row][c];
      final tile = cell.tile!;
      cells.add(cell);
      sb.write(tile.displayLetter);

      int tileScore = tile.scoreValue; // Note: Blank tiles have 0 scoreValue

      if (cell.isNewPlacement) {
        tileScore *= cell.letterMultiplier;
        wordMultiplier *= cell.wordMultiplier;
      }
      scoreSum += tileScore;
    }

    final int wordScore = scoreSum * wordMultiplier;

    return WordResult(
      word: sb.toString(),
      score: wordScore,
      cells: cells,
    );
  }

  /// Traces a vertical word containing cell at (row, col)
  WordResult? _traceVerticalWord(List<List<BoardCell>> grid, int row, int col) {
    if (grid[row][col].tile == null) return null;

    // Find starting row
    int startRow = row;
    while (startRow > 0 && grid[startRow - 1][col].tile != null) {
      startRow--;
    }

    // Find ending row
    int endRow = row;
    while (endRow < GameConfig.boardSize - 1 && grid[endRow + 1][col].tile != null) {
      endRow++;
    }

    // If word is only 1 letter, we only return it if it is a single-tile placement turn
    if (startRow == endRow) return null;

    final List<BoardCell> cells = [];
    final StringBuffer sb = StringBuffer();
    int wordMultiplier = 1;
    int scoreSum = 0;

    for (int r = startRow; r <= endRow; r++) {
      final cell = grid[r][col];
      final tile = cell.tile!;
      cells.add(cell);
      sb.write(tile.displayLetter);

      int tileScore = tile.scoreValue; // Note: Blank tiles have 0 scoreValue

      if (cell.isNewPlacement) {
        tileScore *= cell.letterMultiplier;
        wordMultiplier *= cell.wordMultiplier;
      }
      scoreSum += tileScore;
    }

    final int wordScore = scoreSum * wordMultiplier;

    return WordResult(
      word: sb.toString(),
      score: wordScore,
      cells: cells,
    );
  }
}
