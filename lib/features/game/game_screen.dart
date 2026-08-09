import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../models/game_state.dart';
import 'game_notifier.dart';
import '../../core/haptic_utils.dart';
import '../../core/sound_manager.dart';
import '../../core/toast_utils.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Tile? _selectedRackTile;

  // ── Blank tile picker ──────────────────────────────────────────────────────
  void _promptBlankTileSelection(BuildContext context, int row, int col) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.panelDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.shinyGold, width: 1),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose a Letter for Blank Tile',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppTheme.shinyGold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: 26,
                  itemBuilder: (context, index) {
                    final char = String.fromCharCode(65 + index);
                    return InkWell(
                      onTap: () {
                        ref.read(gameProvider.notifier).setBlankLetter(row, col, char);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.tileIvory,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.5)),
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: const TextStyle(
                              fontFamily: 'Lora',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkCharcoal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Pause / Confirm dialogs ────────────────────────────────────────────────
  Widget _premiumDialogButton({
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    Gradient gradient;
    Border? border;
    Color textColor;

    if (isPrimary) {
      gradient = const LinearGradient(
        colors: AppTheme.goldGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = const Color(0xFF1E1402);
    } else if (isDanger) {
      gradient = const LinearGradient(
        colors: [Color(0xFF5A120A), Color(0xFF2E0502)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      border = Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.55), width: 1.2);
      textColor = Colors.white;
    } else {
      gradient = const LinearGradient(
        colors: AppTheme.darkGreenGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      border = Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.55), width: 1.2);
      textColor = AppTheme.shinyGold;
    }

    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: border,
        gradient: gradient,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.lora(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPauseDialog() {
    final settings = ref.read(gameProvider).settings;
    HapticUtils.trigger(HapticType.tap, settings);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF021710),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.shinyGold, width: 1.5),
        ),
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '➔  ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                ),
              ),
              Text(
                'GAME PAUSED',
                style: GoogleFonts.lora(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                ),
              ),
              Text(
                '  ➔',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _premiumDialogButton(
              label: 'Resume Match',
              isPrimary: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            _premiumDialogButton(
              label: 'Restart Match',
              onTap: () {
                Navigator.of(context).pop();
                _confirmRestart();
              },
            ),
            const SizedBox(height: 12),
            _premiumDialogButton(
              label: 'Abandon & Exit',
              isDanger: true,
              onTap: () {
                Navigator.of(context).pop();
                _confirmAbandon();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestart() {
    final state = ref.read(gameProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF021710),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.shinyGold, width: 1.5),
        ),
        title: Center(
          child: Text(
            'Restart Match?',
            style: GoogleFonts.lora(
              fontWeight: FontWeight.bold,
              color: AppTheme.shinyGold,
              fontSize: 20,
            ),
          ),
        ),
        content: Text(
          'Your current progress will be lost. Restart this match?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppTheme.mutedIvory,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: _premiumDialogButton(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _premiumDialogButton(
                  label: 'Restart',
                  isDanger: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(gameProvider.notifier).startNewGame(state.difficulty);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmAbandon() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF021710),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.shinyGold, width: 1.5),
        ),
        title: Center(
          child: Text(
            'Abandon Game?',
            style: GoogleFonts.lora(
              fontWeight: FontWeight.bold,
              color: AppTheme.shinyGold,
              fontSize: 20,
            ),
          ),
        ),
        content: Text(
          'Abandoning is recorded as a Loss in statistics. Return to main menu?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppTheme.mutedIvory,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: _premiumDialogButton(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _premiumDialogButton(
                  label: 'Abandon',
                  isDanger: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(gameProvider.notifier).abandonGame();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPassConfirm() {
    final settings = ref.read(gameProvider).settings;
    HapticUtils.trigger(HapticType.tap, settings);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF021710),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.shinyGold, width: 1.5),
        ),
        title: Center(
          child: Text(
            'Pass Turn?',
            style: GoogleFonts.lora(
              fontWeight: FontWeight.bold,
              color: AppTheme.shinyGold,
              fontSize: 20,
            ),
          ),
        ),
        content: Text(
          'You will score 0 points for this turn. Continue?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppTheme.mutedIvory,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: _premiumDialogButton(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _premiumDialogButton(
                  label: 'Pass',
                  isPrimary: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(gameProvider.notifier).passTurn();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExchangeDialog() {
    final state = ref.read(gameProvider);
    HapticUtils.trigger(HapticType.tap, state.settings);
    if (state.tileBag.length < 7) {
      ToastUtils.show(context, 'Cannot exchange tiles when bag has fewer than 7 tiles.', isError: true);
      return;
    }
    final List<Tile> selectedToExchange = [];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF021710),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.shinyGold, width: 1.5),
            ),
            title: Center(
              child: Text(
                'Exchange Tiles',
                style: GoogleFonts.lora(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                  fontSize: 20,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select tiles to return to the bag.',
                  style: GoogleFonts.inter(
                    color: AppTheme.mutedIvory,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.playerRack.map((tile) {
                    final bool isSel = selectedToExchange.any((t) => t.id == tile.id);
                    return GestureDetector(
                      onTap: () => setDialogState(() {
                        if (isSel) {
                          selectedToExchange.removeWhere((t) => t.id == tile.id);
                        } else {
                          selectedToExchange.add(tile);
                        }
                      }),
                      child: Container(
                        width: 38,
                        height: 44,
                        decoration: AppTheme.tileDecoration(isSelected: isSel),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                tile.letter.trim().isEmpty ? ' ' : tile.letter,
                                style: GoogleFonts.lora(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkCharcoal,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 3,
                              bottom: 2,
                              child: Text(
                                tile.scoreValue.toString(),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.tileSubText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: _premiumDialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _premiumDialogButton(
                      label: 'Exchange',
                      isPrimary: true,
                      onTap: () {
                        if (selectedToExchange.isNotEmpty) {
                          Navigator.of(context).pop();
                          ref.read(gameProvider.notifier).exchangeTiles(selectedToExchange);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
  }

  void _handleSubmit() {
    final state = ref.read(gameProvider);
    final error = ref.read(gameProvider.notifier).submitPlayerMove();
    if (error != null) {
      HapticUtils.trigger(HapticType.error, state.settings);
      SoundManager.play(SoundType.invalid, state.settings);
      ToastUtils.show(context, error, isError: true);
    } else {
      HapticUtils.trigger(HapticType.success, state.settings);
      SoundManager.play(SoundType.submit, state.settings);
      setState(() => _selectedRackTile = null);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final bool isCompleted = state.status == 'gameCompleted';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmAbandon();
      },
      child: Scaffold(
        body: PremiumBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Custom App Bar ───────────────────────────────────
                    _buildHeader(state),
                    // ── 2. Scoreboard ───────────────────────────────────────
                    _buildScoreboard(state),
                    // ── 3. Status Banner ────────────────────────────────────
                    _buildStatusBanner(state),
                    // ── 4. Board ────────────────────────────────────────────
                    Expanded(child: _buildBoard(state)),
                    // ── 5. Rack ─────────────────────────────────────────────
                    _buildRack(state),
                    // ── 6. Action buttons ───────────────────────────────────
                    _buildActionsPanel(state),
                  ],
                ),
                if (state.status == 'computerThinking') _buildAIOverlay(),
                if (isCompleted) _buildGameOverOverlay(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(GameState state) {
    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;
    switch (state.difficulty.toLowerCase()) {
      case 'easy':
        badgeColor = Colors.greenAccent;
        badgeBg = const Color(0xFF0C462B);
        badgeIcon = Icons.spa_rounded;
        break;
      case 'medium':
        badgeColor = const Color(0xFFECA042);
        badgeBg = const Color(0xFF5E3C0C);
        badgeIcon = Icons.balance_rounded;
        break;
      default:
        badgeColor = const Color(0xFFE0524B);
        badgeBg = const Color(0xFF4C100C);
        badgeIcon = Icons.workspace_premium_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Custom Gold-Bordered Back Button
            Positioned(
              left: 0,
              child: InkWell(
                onTap: _showPauseDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.shinyGold.withValues(alpha: 0.65),
                      width: 1.2,
                    ),
                    color: const Color(0xFF010E0A),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.shinyGold,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ),
            // Centered Title and Difficulty Badge
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '➔  ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.shinyGold,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFF1CC),
                              Color(0xFFD4AF37),
                              Color(0xFF8A640F),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: Text(
                            'LETTERLOOM',
                            style: GoogleFonts.lora(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          '  ➔',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.shinyGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, color: badgeColor, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            state.difficulty.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right Bag Counter
            Positioned(
              right: 0,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.shinyGold.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                  color: const Color(0xFF010E0A),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppTheme.shinyGold,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${state.tileBag.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.shinyGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Scoreboard ─────────────────────────────────────────────────────────────
  Widget _buildScoreboard(GameState state) {
    final isPlayerTurn = state.currentTurn == 'player' && state.status == 'playerTurn';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: _buildScoreCard(
              label: 'YOU',
              score: state.playerScore,
              isActive: isPlayerTurn,
              iconData: Icons.person_rounded,
              avatarColor: Colors.greenAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildScoreCard(
              label: 'COMPUTER',
              score: state.computerScore,
              isActive: !isPlayerTurn,
              iconData: Icons.smart_toy_rounded,
              avatarColor: AppTheme.shinyGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard({
    required String label,
    required int score,
    required bool isActive,
    required IconData iconData,
    required Color avatarColor,
  }) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.shinyGold : AppTheme.shinyGold.withValues(alpha: 0.35),
          width: isActive ? 1.5 : 1.0,
        ),
        gradient: const LinearGradient(
          colors: AppTheme.darkGreenGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.shinyGold.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF010A07),
              border: Border.all(
                color: isActive ? avatarColor : avatarColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Icon(
                iconData,
                color: isActive ? avatarColor : avatarColor.withValues(alpha: 0.6),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Score text
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppTheme.shinyGold : AppTheme.mutedIvory,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  score.toString(),
                  style: GoogleFonts.lora(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ivoryText,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Banner ──────────────────────────────────────────────────────────
  Widget _buildStatusBanner(GameState state) {
    final String msg = state.lastMoveMessage ?? _defaultStatusMsg(state);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF021710),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✦  ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.shinyGold,
              ),
            ),
            Expanded(
              child: Text(
                msg,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ivoryText,
                ),
              ),
            ),
            Text(
              '  ✦',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.shinyGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _defaultStatusMsg(GameState state) {
    switch (state.status) {
      case 'playerTurn':    return 'Your turn — place your tiles!';
      case 'computerThinking': return 'Computer is thinking...';
      case 'computerTurn':  return 'Computer is playing...';
      case 'gameCompleted': return 'Game over!';
      default:              return '';
    }
  }

  // ── Board ──────────────────────────────────────────────────────────────────
  Widget _buildBoard(GameState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppTheme.boardFrame,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.boardFrameEdge, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(builder: (context, constraints) {
        const double coordW = 14.0;
        const double coordH = 12.0;
        final double gridW = constraints.maxWidth - coordW;
        final double cellSize = (gridW - 14 * 1.2) / 15;

        return Column(
          children: [
            // Top number row
            SizedBox(
              height: coordH,
              child: Row(
                children: [
                  const SizedBox(width: coordW),
                  ...List.generate(15, (i) => SizedBox(
                    width: cellSize + (i < 14 ? 1.2 : 0),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 7, color: AppTheme.mutedIvory, fontWeight: FontWeight.w600)),
                    ),
                  )),
                ],
              ),
            ),
            // Middle row (letters + grid) — Expanded to fill available height
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left letter coords
                  SizedBox(
                    width: coordW,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O']
                          .map((l) => Expanded(
                                child: Center(
                                  child: Text(l,
                                      style: const TextStyle(
                                          fontSize: 7,
                                          color: AppTheme.mutedIvory,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  // Board grid
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 225,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 15,
                        crossAxisSpacing: 1.2,
                        mainAxisSpacing: 1.2,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        final r = index ~/ 15;
                        final c = index % 15;
                        return _buildBoardCell(state, r, c, cellSize);
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Bottom number row
            SizedBox(
              height: coordH,
              child: Row(
                children: [
                  const SizedBox(width: coordW),
                  ...List.generate(15, (i) => SizedBox(
                    width: cellSize + (i < 14 ? 1.2 : 0),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 7, color: AppTheme.mutedIvory, fontWeight: FontWeight.w600)),
                    ),
                  )),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // (Coord helpers inlined into _buildBoard above)

  // ── Board Cell ─────────────────────────────────────────────────────────────
  Widget _buildBoardCell(GameState state, int r, int c, double size) {
    final cell = state.board[r][c];
    final tile = cell.tile;
    final isNew = cell.isNewPlacement;

    Widget cellContent;

    if (tile != null) {
      final tileWidget = _buildTileWidget(tile, size - 2, isNew: isNew);

      if (isNew && state.status == 'playerTurn') {
        cellContent = Draggable<Tile>(
          data: tile,
          feedback: Opacity(
            opacity: 0.75,
            child: SizedBox(width: size, height: size, child: tileWidget),
          ),
          childWhenDragging: Container(decoration: AppTheme.cellDecoration(cell.type)),
          onDragStarted: () => SoundManager.play(SoundType.pickup, state.settings),
          onDragCompleted: () => ref.read(gameProvider.notifier).recallTileAt(r, c),
          child: tileWidget,
        );
      } else {
        cellContent = tileWidget;
      }
    } else {
      // Empty cell – show label
      final label = AppTheme.cellLabel(cell.type);
      cellContent = Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: size * 0.27,
            fontWeight: FontWeight.bold,
            color: cell.type == CellType.normal
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.88),
          ),
        ),
      );
    }

    return DragTarget<Tile>(
      onWillAcceptWithDetails: (details) => tile == null,
      onAcceptWithDetails: (details) {
        final incomingTile = details.data;
        SoundManager.play(SoundType.place, state.settings);
        HapticUtils.trigger(HapticType.place, state.settings);
        final placed = ref.read(gameProvider.notifier).placeTile(incomingTile, r, c);
        if (placed && incomingTile.isBlank) _promptBlankTileSelection(context, r, c);
      },
      builder: (context, candidateData, _) {
        final isHover = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () {
            if (state.status != 'playerTurn') return;
            if (tile != null) {
              if (cell.isNewPlacement) {
                HapticUtils.trigger(HapticType.tap, state.settings);
                ref.read(gameProvider.notifier).recallTileAt(r, c);
              }
            } else {
              if (_selectedRackTile != null) {
                SoundManager.play(SoundType.place, state.settings);
                HapticUtils.trigger(HapticType.place, state.settings);
                final blankToPlace = _selectedRackTile!.isBlank;
                final placed = ref.read(gameProvider.notifier).placeTile(_selectedRackTile!, r, c);
                if (placed) {
                  setState(() => _selectedRackTile = null);
                  if (blankToPlace) _promptBlankTileSelection(context, r, c);
                }
              }
            }
          },
          child: Container(
            decoration: AppTheme.cellDecoration(cell.type, isHover: isHover),
            child: cellContent,
          ),
        );
      },
    );
  }

  Widget _buildTileWidget(Tile tile, double size, {bool isNew = false}) {
    return Container(
      width: size,
      height: size,
      decoration: AppTheme.tileDecoration(isNew: isNew),
      child: Stack(
        children: [
          Center(
            child: Text(
              tile.displayLetter,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: size * 0.48,
                fontWeight: FontWeight.bold,
                color: tile.isBlank ? AppTheme.warmGold : AppTheme.darkCharcoal,
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 1,
            child: Text(
              tile.scoreValue.toString(),
              style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w600,
                color: AppTheme.tileSubText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rack ───────────────────────────────────────────────────────────────────
  Widget _buildRack(GameState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.65), width: 1.5),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF021D14),
            Color(0xFF063323),
            Color(0xFF021D14),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Left decorative cap
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 14,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppTheme.shinyGold, width: 1.5)),
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF1CC), Color(0xFFD4AF37), Color(0xFF8A640F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Right decorative cap
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 14,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppTheme.shinyGold, width: 1.5)),
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF1CC), Color(0xFFD4AF37), Color(0xFF8A640F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Center Tiles Row
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: state.playerRack.map((tile) {
                    final bool isSel = _selectedRackTile?.id == tile.id;
                    final tileWidget = _buildTileWidget(tile, 38, isNew: false);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Draggable<Tile>(
                        data: tile,
                        feedback: Opacity(opacity: 0.75, child: tileWidget),
                        childWhenDragging: Opacity(opacity: 0.3, child: tileWidget),
                        onDragStarted: () {
                          HapticUtils.trigger(HapticType.tap, state.settings);
                          SoundManager.play(SoundType.pickup, state.settings);
                          setState(() => _selectedRackTile = null);
                        },
                        child: GestureDetector(
                          onTap: state.status == 'playerTurn'
                              ? () {
                                  HapticUtils.trigger(HapticType.tap, state.settings);
                                  setState(() {
                                    _selectedRackTile = isSel ? null : tile;
                                  });
                                }
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            transform: isSel
                                ? (Matrix4.translationValues(0.0, -6.0, 0.0))
                                : Matrix4.identity(),
                            child: Container(
                              decoration: isSel
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.shinyGold.withValues(alpha: 0.7),
                                          blurRadius: 8,
                                        )
                                      ],
                                    )
                                  : null,
                              child: tileWidget,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions Panel ──────────────────────────────────────────────────────────
  Widget _buildActionsPanel(GameState state) {
    final bool isPlayerTurn = state.status == 'playerTurn';
    final bool hasNew = state.board.any((row) => row.any((c) => c.isNewPlacement));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionBtn(
                icon: Icons.undo_rounded,
                label: 'Recall',
                enabled: isPlayerTurn && hasNew,
                onTap: () => ref.read(gameProvider.notifier).recallAllNewPlacements(),
                state: state,
              ),
              _buildActionBtn(
                icon: Icons.shuffle_rounded,
                label: 'Shuffle',
                enabled: isPlayerTurn,
                onTap: () => ref.read(gameProvider.notifier).shuffleRack(),
                state: state,
              ),
              _buildActionBtn(
                icon: Icons.swap_horiz_rounded,
                label: 'Exchange',
                enabled: isPlayerTurn && state.tileBag.length >= 7,
                badge: '7+',
                onTap: _showExchangeDialog,
                state: state,
              ),
              _buildActionBtn(
                icon: Icons.flag_rounded,
                label: 'Pass',
                enabled: isPlayerTurn,
                onTap: _showPassConfirm,
                state: state,
              ),
            ],
          ),
        ),
        _buildBottomPlayRow(state, hasNew, isPlayerTurn),
      ],
    );
  }

  Widget _buildBottomPlayRow(GameState state, bool hasNew, bool isPlayerTurn) {
    final bool enabled = isPlayerTurn && hasNew;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          // Circular Menu/Pause Button
          InkWell(
            onTap: _showPauseDialog,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.shinyGold, width: 1.2),
                color: const Color(0xFF010A07),
              ),
              child: const Center(
                child: Icon(Icons.menu_rounded, color: AppTheme.shinyGold, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Play Word Pill Button
          Expanded(
            child: Opacity(
              opacity: enabled ? 1.0 : 0.45,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: AppTheme.shinyGold.withValues(alpha: 0.35),
                            offset: const Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                  border: !enabled
                      ? Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.45), width: 1.2)
                      : null,
                  gradient: LinearGradient(
                    colors: enabled ? AppTheme.goldGradient : AppTheme.darkGreenGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: enabled ? _handleSubmit : null,
                    borderRadius: BorderRadius.circular(28),
                    child: Center(
                      child: Text(
                        'PLAY WORD',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: enabled ? const Color(0xFF1E1402) : AppTheme.shinyGold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required GameState state,
    String? badge,
  }) {
    final Color contentColor = enabled ? AppTheme.shinyGold : AppTheme.mutedIvory.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: enabled ? () {
        HapticUtils.trigger(HapticType.tap, state.settings);
        onTap();
      } : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Button Frame
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: enabled ? AppTheme.shinyGold : AppTheme.shinyGold.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                  color: const Color(0xFF010A07),
                ),
                child: Center(
                  child: Icon(icon, color: contentColor, size: 20),
                ),
              ),
              if (badge != null && enabled)
                Positioned(
                  top: -2,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF021710),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.shinyGold, width: 1.0),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.shinyGold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Overlays ───────────────────────────────────────────────────────────────
  Widget _buildAIOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.panelDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.5), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.shinyGold),
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              const Text('Computer is thinking...',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.ivoryText,
                  )),
              const SizedBox(height: 6),
              Text('Formulating candidates...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedIvory,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(GameState state) {
    final bool isWin = state.playerScore > state.computerScore;
    final bool isTie = state.playerScore == state.computerScore;
    final String headline = isTie ? "IT'S A TIE!" : (isWin ? 'VICTORY' : 'DEFEAT');
    final Color headlineColor = isTie ? AppTheme.warmGold : (isWin ? AppTheme.shinyGold : Colors.redAccent);

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF021710),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.shinyGold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gold Crown or Shield Emblem
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF010E0A),
                    border: Border.all(color: headlineColor, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      isWin ? Icons.emoji_events_rounded : (isTie ? Icons.handshake_rounded : Icons.gavel_rounded),
                      color: headlineColor,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Headline
              Text(
                headline,
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: headlineColor,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Scores Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _overScore('YOU', state.playerScore, isWin && !isTie),
                  Container(
                    width: 1.2,
                    height: 52,
                    color: AppTheme.shinyGold.withValues(alpha: 0.25),
                  ),
                  _overScore('COMPUTER', state.computerScore, !isWin && !isTie),
                ],
              ),
              const SizedBox(height: 24),
              if (state.lastMoveMessage != null) ...[
                Text(
                  state.lastMoveMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.mutedIvory,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // Back to Main Menu Button
              _premiumDialogButton(
                label: 'Back to Main Menu',
                isPrimary: true,
                onTap: () {
                  HapticUtils.trigger(HapticType.tap, state.settings);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overScore(String label, int score, bool isWinner) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mutedIvory)),
        const SizedBox(height: 4),
        Text(score.toString(),
            style: GoogleFonts.lora(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isWinner ? AppTheme.shinyGold : AppTheme.ivoryText,
            )),
      ],
    );
  }
}
