import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../game/game_notifier.dart';
import '../game/game_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';
import '../how_to_play/how_to_play_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _canContinue = false;
  bool _checkingSave = true;

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
  }

  Future<void> _checkSavedGame() async {
    final hasSave = await ref.read(gameProvider.notifier).hasSavedGame();
    if (mounted) {
      setState(() {
        _canContinue = hasSave;
        _checkingSave = false;
      });
    }
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(
          child: Text(
            'Select Difficulty',
            style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDifficultyButton('Easy', 'Plays simple words, relaxes scores.', 'easy'),
            const SizedBox(height: 12),
            _buildDifficultyButton('Medium', 'Competitive plays, balanced scoring.', 'medium'),
            const SizedBox(height: 12),
            _buildDifficultyButton('Hard', 'Strategic board usage and trie searches.', 'hard'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.darkCharcoal)),
          ),
        ],
      ),
    ).then((_) => _checkSavedGame()); // Re-check if game is in progress now
  }

  Widget _buildDifficultyButton(String title, String desc, String diffValue) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        ref.read(gameProvider.notifier).startNewGame(diffValue);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const GameScreen()),
        ).then((_) => _checkSavedGame());
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.lightGrey),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppTheme.darkCharcoal.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.warmGold),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.scaffoldDark,
              Color(0xFF01100A),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                // Logo & Branding
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.8), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              offset: const Offset(0, 6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'LetterLoom',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ivoryText,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Offline Craft Wordplay',
                         style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppTheme.mutedIvory,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                // Menu Buttons
                _buildMenuButton(
                  title: 'New Game',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _showDifficultyDialog,
                  isPrimary: true,
                ),
                const SizedBox(height: 14),
                if (!_checkingSave)
                  _buildMenuButton(
                    title: 'Continue Game',
                    icon: Icons.history_rounded,
                    onPressed: _canContinue
                        ? () {
                            ref.read(gameProvider.notifier).loadSavedGame();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const GameScreen()),
                            ).then((_) => _checkSavedGame());
                          }
                        : null,
                    isPrimary: false,
                  ),
                const SizedBox(height: 14),
                _buildMenuButton(
                  title: 'How to Play',
                  icon: Icons.help_outline_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const HowToPlayScreen()),
                    );
                  },
                  isPrimary: false,
                ),
                const SizedBox(height: 14),
                _buildMenuButton(
                  title: 'Statistics',
                  icon: Icons.bar_chart_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                    );
                  },
                  isPrimary: false,
                ),
                const SizedBox(height: 14),
                _buildMenuButton(
                  title: 'Settings',
                  icon: Icons.settings_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                  isPrimary: false,
                ),
                const Spacer(flex: 1),
                // Attribution Footer
                 Center(
                  child: Text(
                    'Permissive Wordlist © Dolph Dictionary & SOWPODS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: AppTheme.mutedIvory.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    final bool disabled = onPressed == null;
    final buttonColor = isPrimary
        ? AppTheme.shinyGold
        : disabled
            ? AppTheme.panelDark.withValues(alpha: 0.5)
            : AppTheme.panelDark;
    final textColor = isPrimary
        ? AppTheme.panelDark
        : disabled
            ? AppTheme.mutedIvory.withValues(alpha: 0.4)
            : AppTheme.ivoryText;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isPrimary && !disabled
            ? [
                BoxShadow(
                  color: AppTheme.shinyGold.withValues(alpha: 0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: !isPrimary && !disabled
                ? BorderSide(color: AppTheme.shinyGold.withValues(alpha: 0.35), width: 1)
                : BorderSide.none,
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
