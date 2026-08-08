import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../models/game_state.dart';
import 'game_notifier.dart';
import '../../core/haptic_utils.dart';
import '../../core/sound_manager.dart';

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
  void _showPauseDialog() {
    final settings = ref.read(gameProvider).settings;
    HapticUtils.trigger(HapticType.tap, settings);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Center(
          child: Text('Game Paused',
              style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold, color: AppTheme.shinyGold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dialogBtn('Resume Match', AppTheme.emeraldGreen, () => Navigator.of(context).pop()),
            const SizedBox(height: 10),
            _dialogBtn('Restart Match', AppTheme.warmGold, () {
              Navigator.of(context).pop();
              _confirmRestart();
            }),
            const SizedBox(height: 10),
            _dialogBtn('Abandon & Exit', Colors.red[800]!, () {
              Navigator.of(context).pop();
              _confirmAbandon();
            }),
          ],
        ),
      ),
    );
  }

  ElevatedButton _dialogBtn(String label, Color bg, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _confirmRestart() {
    final state = ref.read(gameProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Game?',
            style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
        content: const Text('Your current progress will be lost. Restart this match?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(gameProvider.notifier).startNewGame(state.difficulty);
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _confirmAbandon() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Game?',
            style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
        content: const Text('Abandoning is recorded as a Loss in statistics. Return to main menu?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(gameProvider.notifier).abandonGame();
              Navigator.of(context).pop();
            },
            child: const Text('Abandon'),
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
        title: const Text('Pass Turn?',
            style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
        content: const Text('You will score 0 points for this turn. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(gameProvider.notifier).passTurn();
            },
            child: const Text('Pass'),
          ),
        ],
      ),
    );
  }

  void _showExchangeDialog() {
    final state = ref.read(gameProvider);
    HapticUtils.trigger(HapticType.tap, state.settings);
    if (state.tileBag.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot exchange tiles when bag has fewer than 7 tiles.')),
      );
      return;
    }
    final List<Tile> selectedToExchange = [];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Exchange Tiles',
                style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Select tiles to return to the bag.',
                    style: TextStyle(fontSize: 13)),
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
                        child: Stack(children: [
                          Center(
                            child: Text(
                              tile.letter.trim().isEmpty ? ' ' : tile.letter,
                              style: const TextStyle(
                                  fontFamily: 'Lora',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkCharcoal),
                            ),
                          ),
                          Positioned(
                            right: 3,
                            bottom: 2,
                            child: Text(tile.scoreValue.toString(),
                                style: const TextStyle(fontSize: 8, color: AppTheme.tileSubText)),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedToExchange.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        ref
                            .read(gameProvider.notifier)
                            .exchangeTiles(selectedToExchange);
                      },
                child: const Text('Exchange'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red[800]),
      );
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
        backgroundColor: AppTheme.scaffoldDark,
        body: SafeArea(
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
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(GameState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Back / Menu button
          _goldBorderButton(
            child: const Icon(Icons.chevron_left_rounded, color: AppTheme.ivoryText, size: 22),
            onTap: _showPauseDialog,
          ),
          // Centered title + difficulty badge
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🍃 ', style: TextStyle(fontSize: 14)),
                    Text(
                      'LetterLoom',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.ivoryText,
                        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4)],
                      ),
                    ),
                    const Text(' 🍃', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.panelDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.6), width: 1),
                  ),
                  child: Text(
                    state.difficulty.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppTheme.shinyGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bag counter
          _goldBorderButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💰', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  'Bag: ${state.tileBag.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ivoryText,
                  ),
                ),
              ],
            ),
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _goldBorderButton({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.all(7),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppTheme.panelDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.55), width: 1),
        ),
        child: child,
      ),
    );
  }

  // ── Scoreboard ─────────────────────────────────────────────────────────────
  Widget _buildScoreboard(GameState state) {
    final isPlayerTurn = state.currentTurn == 'player' && state.status == 'playerTurn';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Expanded(child: _buildScoreCard(
            icon: Icons.person_rounded,
            label: 'YOU',
            score: state.playerScore,
            isActive: isPlayerTurn,
            isPlayer: true,
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildScoreCard(
            icon: Icons.smart_toy_rounded,
            label: 'COMPUTER',
            score: state.computerScore,
            isActive: !isPlayerTurn,
            isPlayer: false,
          )),
        ],
      ),
    );
  }

  Widget _buildScoreCard({
    required IconData icon,
    required String label,
    required int score,
    required bool isActive,
    required bool isPlayer,
  }) {
    final Color borderColor = isActive
        ? (isPlayer ? AppTheme.emeraldGreen : AppTheme.shinyGold)
        : AppTheme.lightGrey;
    final Color bgColor = isActive
        ? (isPlayer ? AppTheme.panelDark : AppTheme.tileIvory)
        : AppTheme.panelDark.withValues(alpha: 0.6);
    final Color labelColor = isPlayer
        ? (isActive ? AppTheme.ivoryText : AppTheme.mutedIvory)
        : (isActive ? AppTheme.darkCharcoal : AppTheme.mutedIvory);
    final Color scoreColor = isPlayer
        ? AppTheme.ivoryText
        : (isActive ? AppTheme.darkCharcoal : AppTheme.mutedIvory);
    final Color iconColor = isActive
        ? (isPlayer ? AppTheme.emeraldGreen : AppTheme.warmGold)
        : AppTheme.mutedIvory;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        boxShadow: isActive
            ? [BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
              border: Border.all(color: iconColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: labelColor)),
              Text(score.toString(),
                  style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      color: scoreColor)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status Banner ──────────────────────────────────────────────────────────
  Widget _buildStatusBanner(GameState state) {
    final String msg = state.lastMoveMessage ?? _defaultStatusMsg(state);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.panelDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lightGrey.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.ivoryText,
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
    // Frame margin + border + padding on each side = 6+2+4 = 12px per side = 24px total
    // Left coord column = 14px
    // Available grid width = screen width - 24 (margins) - 14 (coords)
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
        const double coordW = 14.0; // left letter column width
        const double coordH = 12.0; // top/bottom number row height
        // Each cell must fit exactly 15 across the available width
        // Account for 14 gaps of 1.2px between cells
        final double gridW = constraints.maxWidth - coordW;
        final double cellSize = (gridW - 14 * 1.2) / 15;

        return Column(
          children: [
            // Top number row
            SizedBox(
              height: coordH,
              child: Row(children: [
                const SizedBox(width: coordW),
                ...List.generate(15, (i) => SizedBox(
                  width: cellSize + (i < 14 ? 1.2 : 0),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 7, color: AppTheme.mutedIvory, fontWeight: FontWeight.w600)),
                  ),
                )),
              ]),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left letter coords
                  SizedBox(
                    width: coordW,
                    child: Column(
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
                  SizedBox(
                    width: gridW,
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
              child: Row(children: [
                const SizedBox(width: coordW),
                ...List.generate(15, (i) => SizedBox(
                  width: cellSize + (i < 14 ? 1.2 : 0),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 7, color: AppTheme.mutedIvory, fontWeight: FontWeight.w600)),
                  ),
                )),
              ]),
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
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.panelDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.45), width: 1),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: state.playerRack.map((tile) {
            final bool isSel = _selectedRackTile?.id == tile.id;
            final tileWidget = _buildTileWidget(tile, 40, isNew: false);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
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
                              boxShadow: [BoxShadow(color: AppTheme.shinyGold.withValues(alpha: 0.7), blurRadius: 8)],
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
    );
  }

  // ── Actions Panel ──────────────────────────────────────────────────────────
  Widget _buildActionsPanel(GameState state) {
    final bool isPlayerTurn = state.status == 'playerTurn';
    final bool hasNew = state.board.any((row) => row.any((c) => c.isNewPlacement));
    final int selectedCount = state.playerRack
        .where((t) => _selectedRackTile?.id == t.id)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      color: AppTheme.scaffoldDark,
      child: Column(
        children: [
          // Action icon buttons — each takes equal width via IntrinsicHeight + Row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildActionBtn(
                  icon: Icons.replay_rounded,
                  label: 'Recall',
                  enabled: isPlayerTurn && hasNew,
                  onTap: () => ref.read(gameProvider.notifier).recallAllNewPlacements(),
                  state: state,
                )),
                const SizedBox(width: 6),
                Expanded(child: _buildActionBtn(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  enabled: isPlayerTurn,
                  onTap: () => ref.read(gameProvider.notifier).shuffleRack(),
                  state: state,
                )),
                const SizedBox(width: 6),
                Expanded(child: _buildActionBtn(
                  icon: Icons.sync_alt_rounded,
                  label: 'Exchange',
                  enabled: isPlayerTurn && state.tileBag.length >= 7,
                  badge: selectedCount > 0 ? '$selectedCount' : null,
                  onTap: _showExchangeDialog,
                  state: state,
                )),
                const SizedBox(width: 6),
                Expanded(child: _buildActionBtn(
                  icon: Icons.flag_rounded,
                  label: 'Pass',
                  enabled: isPlayerTurn,
                  onTap: _showPassConfirm,
                  state: state,
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Play Word pill button
          GestureDetector(
            onTap: isPlayerTurn && hasNew ? _handleSubmit : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasNew
                      ? [AppTheme.midGreen, AppTheme.darkGreen]
                      : [AppTheme.panelDark, AppTheme.panelDark],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: hasNew ? AppTheme.shinyGold : AppTheme.lightGrey,
                  width: 1.5,
                ),
                boxShadow: hasNew
                    ? [BoxShadow(
                        color: AppTheme.shinyGold.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '✦',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasNew ? AppTheme.shinyGold : AppTheme.mutedIvory,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Play Word',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: hasNew ? AppTheme.ivoryText : AppTheme.mutedIvory,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '✦',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasNew ? AppTheme.shinyGold : AppTheme.mutedIvory,
                    ),
                  ),
                ],
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
    final Color iconColor = enabled ? AppTheme.shinyGold : AppTheme.mutedIvory;
    return GestureDetector(
      onTap: enabled ? () {
        HapticUtils.trigger(HapticType.tap, state.settings);
        onTap();
      } : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.panelDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? AppTheme.shinyGold.withValues(alpha: 0.45)
                : AppTheme.lightGrey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (badge != null)
              // Badge floating above icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppTheme.shinyGold,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(badge,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkCharcoal,
                            )),
                      ),
                    ),
                  ),
                ],
              )
            else
              Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
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
    final String headline = isTie ? "It's a Tie!" : (isWin ? 'Victory! 🏆' : 'Defeat 😔');
    final Color headlineColor = isTie ? AppTheme.warmGold : (isWin ? AppTheme.shinyGold : Colors.red[400]!);

    return Container(
      color: Colors.black.withValues(alpha: 0.70),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.panelDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: headlineColor,
                  )),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _overScore('YOU', state.playerScore, isWin && !isTie),
                  Container(width: 1, height: 50, color: AppTheme.lightGrey),
                  _overScore('COMPUTER', state.computerScore, !isWin && !isTie),
                ],
              ),
              const SizedBox(height: 20),
              if (state.lastMoveMessage != null)
                Text(state.lastMoveMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.mutedIvory)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  HapticUtils.trigger(HapticType.tap, state.settings);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.midGreen, AppTheme.darkGreen]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Back to Main Menu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.ivoryText,
                      )),
                ),
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
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mutedIvory)),
        const SizedBox(height: 4),
        Text(score.toString(),
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isWinner ? AppTheme.shinyGold : AppTheme.ivoryText,
            )),
      ],
    );
  }
}
