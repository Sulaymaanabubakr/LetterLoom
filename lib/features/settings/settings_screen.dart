import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../game/game_notifier.dart';
import '../../core/haptic_utils.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showResetConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Statistics?',
          style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently clear all your wins, losses, high scores, and statistics. This action cannot be undone.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.darkCharcoal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(gameProvider.notifier).resetStatistics();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Statistics cleared!')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final settings = gameState.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.darkCharcoal),
          onPressed: () {
            HapticUtils.trigger(HapticType.tap, settings);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preference cards
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Sound Effects',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Play sounds on placement & victory'),
                    value: settings.soundEnabled,
                    activeThumbColor: AppTheme.emeraldGreen,
                    onChanged: (val) {
                      HapticUtils.trigger(HapticType.tap, settings);
                      ref.read(gameProvider.notifier).toggleSound(val);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text(
                      'Haptic Feedback',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Vibrate for tile movements & taps'),
                    value: settings.hapticEnabled,
                    activeThumbColor: AppTheme.emeraldGreen,
                    onChanged: (val) {
                      ref.read(gameProvider.notifier).toggleHaptics(val);
                      if (val) {
                        // Quick preview trigger
                        HapticFeedback.mediumImpact();
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text(
                      'Background Music',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Enable ambient game music (if loaded)'),
                    value: settings.musicEnabled,
                    activeThumbColor: AppTheme.emeraldGreen,
                    onChanged: (val) {
                      HapticUtils.trigger(HapticType.tap, settings);
                      ref.read(gameProvider.notifier).toggleMusic(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Animation settings
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Placement Speed',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Controls how fast the computer opponent places tiles on the board.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkCharcoal.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSpeedOption(ref, 'Slow', 1.5, settings.animationSpeed),
                        _buildSpeedOption(ref, 'Normal', 1.0, settings.animationSpeed),
                        _buildSpeedOption(ref, 'Fast', 0.5, settings.animationSpeed),
                        _buildSpeedOption(ref, 'Instant', 0.2, settings.animationSpeed),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Reset button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                HapticUtils.trigger(HapticType.tap, settings);
                _showResetConfirmDialog(context, ref);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Reset Statistics',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedOption(WidgetRef ref, String label, double speedVal, double currentSpeed) {
    final bool active = speedVal == currentSpeed;
    return InkWell(
      onTap: () {
        ref.read(gameProvider.notifier).setAnimationSpeed(speedVal);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.forestGreen : Colors.transparent,
          border: Border.all(color: active ? AppTheme.forestGreen : AppTheme.lightGrey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : AppTheme.darkCharcoal,
          ),
        ),
      ),
    );
  }
}
