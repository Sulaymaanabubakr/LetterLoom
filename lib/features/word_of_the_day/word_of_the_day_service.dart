import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class WordOfTheDayData {
  final String word;
  final String definition;
  final int tileScore;

  const WordOfTheDayData({
    required this.word,
    required this.definition,
    required this.tileScore,
  });
}

class WordOfTheDayService {
  static const List<WordOfTheDayData> curatedWords = [
    WordOfTheDayData(
      word: 'JAZZ',
      definition:
          'A type of music of African-American origin characterized by improvisation and syncopation.',
      tileScore: 29,
    ),
    WordOfTheDayData(
      word: 'LOOM',
      definition: 'An apparatus for weaving thread into fabric.',
      tileScore: 6,
    ),
    WordOfTheDayData(
      word: 'QUARTZ',
      definition:
          'A hard mineral consisting of silica, often occurring in hexagonal prisms.',
      tileScore: 24,
    ),
    WordOfTheDayData(
      word: 'ZEPHYR',
      definition: 'A gentle, mild breeze.',
      tileScore: 20,
    ),
    WordOfTheDayData(
      word: 'KINETIC',
      definition: 'Relating to or resulting from motion.',
      tileScore: 13,
    ),
    WordOfTheDayData(
      word: 'VALIANT',
      definition: 'Possessing or showing courage or determination.',
      tileScore: 10,
    ),
    WordOfTheDayData(
      word: 'EMERALD',
      definition:
          'A bright green precious stone consisting of a variety of beryl.',
      tileScore: 12,
    ),
    WordOfTheDayData(
      word: 'NEXUS',
      definition:
          'A connection or series of connections linking two or more things.',
      tileScore: 12,
    ),
  ];

  static WordOfTheDayData getTodayWord() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return curatedWords[dayOfYear % curatedWords.length];
  }

  static void showModal(BuildContext context) {
    final wordData = getTodayWord();
    showDialog(
      context: context,
      builder: (context) => PremiumDialog(
        title: 'Word of the Day',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF021710),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.shinyGold),
              ),
              child: Text(
                wordData.word,
                style: GoogleFonts.lora(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Base Tile Value: ${wordData.tileScore} points',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.emeraldGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              wordData.definition,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.ivoryText, height: 1.4),
            ),
          ],
        ),
        actions: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.shinyGold,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ),
        ],
      ),
    );
  }
}
