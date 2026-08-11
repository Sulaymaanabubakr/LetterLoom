import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'post_game_analysis.dart';

class PostGameAnalysisDialog extends StatelessWidget {
  final PostGameSummary summary;
  const PostGameAnalysisDialog({super.key, required this.summary});

  static void show(BuildContext context, PostGameSummary summary) {
    showDialog(
      context: context,
      builder: (context) => PostGameAnalysisDialog(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumDialog(
      title: 'Match Analysis',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(
            'Final Score',
            '${summary.totalPlayerScore} - ${summary.totalOpponentScore}',
          ),
          _buildRow('Average Turn Score', '${summary.averageTurnScore} pts'),
          _buildRow(
            'Best Turn Word',
            '${summary.highestScoringWord} (${summary.highestTurnScore} pts)',
          ),
          _buildRow('Longest Word', summary.longestWord),
          _buildRow('Bingos Played', '${summary.bingoCount}'),
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
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: AppTheme.mutedIvory, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.lora(
              color: AppTheme.shinyGold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
