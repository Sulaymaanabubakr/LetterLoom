import '../dictionary/dictionary_service.dart';
import '../models/tile.dart';

/// Checks whether a new rack can make at least one valid opening word.
///
/// The first turn has no board letters to build from, so dealing an
/// unplayable rack would make both the player and the help system stall.
class OpeningRackValidator {
  OpeningRackValidator._();

  static bool hasPlayableWord(
    List<Tile> rack, {
    List<String>? dictionaryWords,
  }) {
    final words = dictionaryWords ?? DictionaryService().wordList;

    // Do not reject a new game while the dictionary is still loading. The
    // splash screen loads it before Home, and this preserves a safe fallback
    // for tests or an unexpected asset-loading failure.
    if (words.isEmpty) return true;

    final letterCounts = <String, int>{};
    var blankCount = 0;
    for (final tile in rack) {
      if (tile.isBlank) {
        blankCount++;
      } else {
        letterCounts[tile.letter] = (letterCounts[tile.letter] ?? 0) + 1;
      }
    }

    for (final word in words) {
      if (word.length < 2 || word.length > rack.length) continue;

      final required = <String, int>{};
      for (final letter in word.split('')) {
        required[letter] = (required[letter] ?? 0) + 1;
      }

      var blanksNeeded = 0;
      for (final entry in required.entries) {
        final available = letterCounts[entry.key] ?? 0;
        if (entry.value > available) {
          blanksNeeded += entry.value - available;
        }
      }
      if (blanksNeeded <= blankCount) return true;
    }

    return false;
  }
}
