import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../game/game_notifier.dart';
import '../../core/haptic_utils.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final stats = gameState.statistics;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistics',
          style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.darkCharcoal),
          onPressed: () {
            HapticUtils.trigger(HapticType.tap, gameState.settings);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // General record overview card
            Card(
              color: AppTheme.forestGreen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: Column(
                  children: [
                    const Text(
                      'Win Rate',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.winPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Lora',
                        color: AppTheme.shinyGold,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildRecordMetric('GAMES', stats.totalGames),
                        _buildRecordMetric('WINS', stats.wins),
                        _buildRecordMetric('LOSSES', stats.losses),
                        _buildRecordMetric('TIES', stats.ties),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // High scores and word records
            const Text(
              'Personal Records',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.forestGreen,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTextStatRow('Highest Game Score', '${stats.highestGameScore} pts'),
                    const Divider(height: 20),
                    _buildTextStatRow('Best Single-Turn Score', '${stats.highestSingleTurnScore} pts'),
                    const Divider(height: 20),
                    _buildTextStatRow('Longest Word Played', stats.longestWord.isEmpty ? '-' : stats.longestWord),
                    const Divider(height: 20),
                    _buildTextStatRow('Total Words Submitted', '${stats.totalWordsPlayed}'),
                    const Divider(height: 20),
                    _buildTextStatRow('7-Tile Bingo Bonuses', '${stats.sevenTileBonuses}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Record by difficulty
            const Text(
              'Difficulty Victories',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.forestGreen,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDifficultyWinBox('EASY', stats.winsEasy, Colors.green[800]!),
                    _buildDifficultyWinBox('MEDIUM', stats.winsMedium, Colors.orange[800]!),
                    _buildDifficultyWinBox('HARD', stats.winsHard, Colors.red[800]!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordMetric(String label, int val) {
    return Column(
      children: [
        Text(
          val.toString(),
          style: const TextStyle(
            fontFamily: 'Lora',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: AppTheme.darkCharcoal,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Lora',
            fontWeight: FontWeight.bold,
            color: AppTheme.emeraldGreen,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyWinBox(String difficulty, int winsCount, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            difficulty,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$winsCount Wins',
          style: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkCharcoal,
          ),
        ),
      ],
    );
  }
}
