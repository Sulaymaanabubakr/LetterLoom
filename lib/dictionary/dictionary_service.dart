import 'dart:collection';
import 'package:flutter/services.dart' show rootBundle;

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  final Set<String> _wordSet = HashSet<String>();
  final List<String> _wordList = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<String> get wordList => _wordList;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      // Read dictionary file from assets
      final String content = await rootBundle.loadString('assets/dictionary/enable1.txt');
      
      // Parse words, filtering out any empty lines or carriage returns
      final List<String> lines = content.split('\n');
      _wordSet.clear();
      _wordList.clear();

      for (var line in lines) {
        final clean = line.trim().toUpperCase();
        if (clean.isNotEmpty) {
          _wordSet.add(clean);
          _wordList.add(clean);
        }
      }

      // Ensure the word list is alphabetically sorted for binary search
      _wordList.sort();
      _isLoaded = true;
    } catch (e) {
      // In case of any load failure, print error and set isLoaded to false.
      // We fall back to a minimal embedded fallback word list for unit tests if required.
      print("Error loading dictionary: $e");
      _isLoaded = false;
      rethrow;
    }
  }

  /// Initialize with a custom list of words (mainly useful for unit testing)
  void loadMock(List<String> mockWords) {
    _wordSet.clear();
    _wordList.clear();
    for (var w in mockWords) {
      final clean = w.trim().toUpperCase();
      if (clean.isNotEmpty) {
        _wordSet.add(clean);
        _wordList.add(clean);
      }
    }
    _wordList.sort();
    _isLoaded = true;
  }

  /// Exact lookup in O(1) time
  bool isValidWord(String word) {
    if (!_isLoaded) return false;
    return _wordSet.contains(word.trim().toUpperCase());
  }

  /// Checks if any word in the dictionary starts with the given prefix in O(log N) time
  bool isValidPrefix(String prefix) {
    if (!_isLoaded) return false;
    final String target = prefix.trim().toUpperCase();
    if (target.isEmpty) return true;

    int low = 0;
    int high = _wordList.length - 1;

    while (low <= high) {
      final int mid = (low + high) >> 1;
      final String midWord = _wordList[mid];
      
      if (midWord.startsWith(target)) {
        return true;
      }
      
      if (midWord.compareTo(target) < 0) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // A secondary check: the binary search might have landed adjacent to the prefix.
    // We check low to see if it starts with the target prefix.
    if (low >= 0 && low < _wordList.length) {
      if (_wordList[low].startsWith(target)) {
        return true;
      }
    }

    return false;
  }

  /// Finds all words in the dictionary matching the prefix
  List<String> getWordsWithPrefix(String prefix, {int limit = 50}) {
    if (!_isLoaded) return [];
    final String target = prefix.trim().toUpperCase();
    final List<String> results = [];
    
    int low = 0;
    int high = _wordList.length - 1;
    int firstMatchIndex = -1;

    while (low <= high) {
      final int mid = (low + high) >> 1;
      final String midWord = _wordList[mid];
      
      if (midWord.startsWith(target)) {
        firstMatchIndex = mid;
        // Search left for the absolute first occurrence
        high = mid - 1;
      } else if (midWord.compareTo(target) < 0) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (firstMatchIndex != -1) {
      for (int i = firstMatchIndex; i < _wordList.length; i++) {
        if (_wordList[i].startsWith(target)) {
          results.add(_wordList[i]);
          if (results.length >= limit) break;
        } else {
          break;
        }
      }
    }
    return results;
  }
}
