import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import '../../theme/app_theme.dart';

class WordOfTheDayData {
  final DateTime date;
  final String word;
  final String definition;
  final int tileScore;

  const WordOfTheDayData({
    required this.date,
    required this.word,
    required this.definition,
    required this.tileScore,
  });

  factory WordOfTheDayData.fromJson(Map<String, dynamic> json) {
    return WordOfTheDayData(
      date: DateTime.parse(json['word_date'] as String),
      word: json['word'] as String,
      definition: json['definition'] as String,
      tileScore: (json['tile_score'] as num).toInt(),
    );
  }
}

class WordOfTheDayService {
  static Future<WordOfTheDayData> loadTodayWord() async {
    if (!SupabaseBootstrap.configured) {
      throw StateError('Word of the Day is unavailable in this app build.');
    }
    final response = await Supabase.instance.client.functions.invoke(
      'word-of-the-day',
    );
    final raw = response.data is Map ? response.data['word'] : null;
    if (raw is! Map) throw StateError('Word of the Day is unavailable.');
    return WordOfTheDayData.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<void> showModal(BuildContext context) {
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => const _WordOfTheDayDialog(),
    );
  }
}

class _WordOfTheDayDialog extends StatefulWidget {
  const _WordOfTheDayDialog();

  @override
  State<_WordOfTheDayDialog> createState() => _WordOfTheDayDialogState();
}

class _WordOfTheDayDialogState extends State<_WordOfTheDayDialog> {
  late Future<WordOfTheDayData> _word = WordOfTheDayService.loadTodayWord();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WordOfTheDayData>(
      future: _word,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return PremiumDialog(
            title: 'Word of the Day',
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.shinyGold),
            ),
          );
        }
        if (snapshot.hasError) {
          return PremiumDialog(
            title: 'Word of the Day',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Today\'s word could not be loaded.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.ivoryText),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(
                    () => _word = WordOfTheDayService.loadTodayWord(),
                  ),
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
            actions: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE'),
                ),
              ),
            ],
          );
        }
        final word = snapshot.requireData;
        return PremiumDialog(
          title: 'Word of the Day',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A fresh word, published globally for today.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.mutedIvory,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF021710),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.shinyGold),
                ),
                child: Text(
                  word.word,
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
                'Base Tile Value: ${word.tileScore} points',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emeraldGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                word.definition,
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
        );
      },
    );
  }
}
