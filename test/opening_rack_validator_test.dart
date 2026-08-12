import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/game_engine/opening_rack_validator.dart';
import 'package:letterloom/models/tile.dart';

void main() {
  Tile tile(String id, String letter) =>
      Tile(id: id, letter: letter, scoreValue: 1, isBlank: letter == ' ');

  test('rejects the unplayable opening rack shown in the game', () {
    final rack = [
      'B',
      'G',
      'R',
      'N',
      'L',
      'H',
      'Q',
    ].indexed.map((entry) => tile('tile_${entry.$1}', entry.$2)).toList();

    expect(
      OpeningRackValidator.hasPlayableWord(
        rack,
        dictionaryWords: const ['AT', 'GO', 'HEN', 'RING'],
      ),
      isFalse,
    );
  });

  test('accepts an opening rack that can form a dictionary word', () {
    final rack = [
      'C',
      'A',
      'T',
      'Z',
      'Z',
      'Z',
      'Z',
    ].indexed.map((entry) => tile('tile_${entry.$1}', entry.$2)).toList();

    expect(
      OpeningRackValidator.hasPlayableWord(
        rack,
        dictionaryWords: const ['CAT'],
      ),
      isTrue,
    );
  });

  test('uses blank tiles to complete an opening word', () {
    final rack = [tile('c', 'C'), tile('blank', ' '), tile('t', 'T')];

    expect(
      OpeningRackValidator.hasPlayableWord(
        rack,
        dictionaryWords: const ['CAT'],
      ),
      isTrue,
    );
  });
}
