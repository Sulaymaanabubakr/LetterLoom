import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../models/game_state.dart';
import '../../ai/ai_engine.dart';
import 'game_notifier.dart';
import '../../core/haptic_utils.dart';
import '../../core/music_manager.dart';
import '../../core/sound_manager.dart';
import '../../core/toast_utils.dart';
import '../../core/coachmark.dart';
import '../hints/hint_modal.dart';
import '../hints/hint_engine.dart';
import 'post_game_analysis.dart';
import 'post_game_analysis_dialog.dart';
import '../multiplayer/agora_voice_service.dart';
import '../multiplayer/multiplayer_repository.dart';

class GameScreen extends ConsumerStatefulWidget {
  final StateNotifierProvider<GameNotifier, GameState>? controllerProvider;
  final bool isMultiplayer;
  final String? opponentName;
  final Future<void> Function()? onMultiplayerRestart;
  final Future<void> Function()? onMultiplayerEnd;
  final Future<void> Function()? onMultiplayerLeave;
  final String? multiplayerGameId;

  const GameScreen({
    super.key,
    this.controllerProvider,
    this.isMultiplayer = false,
    this.opponentName,
    this.onMultiplayerRestart,
    this.onMultiplayerEnd,
    this.onMultiplayerLeave,
    this.multiplayerGameId,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  static const double _edgeContentTightening = 24.0;
  static const Duration _turnDuration = GameNotifier.turnDuration;
  Tile? _selectedRackTile;
  Timer? _turnCountdownTimer;
  DateTime? _countdownTurnStartedAt;
  bool _timeoutRequested = false;
  bool _appLifecyclePauseHeld = false;
  bool _exchangeSheetOpen = false;
  final AgoraVoiceService _voice = AgoraVoiceService();
  StreamSubscription<Set<int>>? _speakerSubscription;
  Set<int> _activeSpeakers = const {};
  HintResult? _activeHint;
  final GlobalKey _hintButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    MusicManager.instance.setTrack(MusicTrack.game);
    WidgetsBinding.instance.addObserver(this);
    if (widget.isMultiplayer && widget.multiplayerGameId != null) {
      _speakerSubscription = _voice.activeSpeakers.listen((speakers) {
        if (mounted) setState(() => _activeSpeakers = speakers);
      });
      unawaited(_connectVoice());
    }
    _turnCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickTurnCountdown(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await Coachmark.showOnce(
        context: context,
        id: widget.isMultiplayer
            ? 'multiplayer_hint_button'
            : 'solo_hint_button',
        targetKey: _hintButtonKey,
        title: 'Need a hand?',
        message:
            'Tap the bulb for a playable move, useful letter, or strongest play.',
      );
    });
  }

  void _tickTurnCountdown() {
    if (!mounted) return;
    final state = ref.read(_provider);
    if (ref.read(_provider.notifier).isGamePaused) {
      setState(() {});
      return;
    }
    if (_countdownTurnStartedAt != state.turnStartedAt) {
      _countdownTurnStartedAt = state.turnStartedAt;
      _timeoutRequested = false;
    }
    final start = state.turnStartedAt;
    final isTimedTurn =
        state.turnStartedAt != null &&
        (state.status == 'playerTurn' ||
            (widget.isMultiplayer && state.status == 'waitingForOpponent'));
    if (isTimedTurn &&
        start != null &&
        DateTime.now().isAfter(start.add(_turnDuration))) {
      if (!_timeoutRequested) {
        _timeoutRequested = true;
        ref.read(_provider.notifier).handleTurnTimeout();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    unawaited(Coachmark.dismiss('solo_hint_button'));
    unawaited(Coachmark.dismiss('multiplayer_hint_button'));
    WidgetsBinding.instance.removeObserver(this);
    _turnCountdownTimer?.cancel();
    _speakerSubscription?.cancel();
    if (widget.multiplayerGameId != null) {
      unawaited(
        MultiplayerRepository().updateVoicePresence(
          widget.multiplayerGameId!,
          connected: false,
          micEnabled: false,
        ),
      );
    }
    unawaited(_voice.dispose());
    MusicManager.instance.setTrack(MusicTrack.menu);
    super.dispose();
  }

  Future<void> _connectVoice() async {
    final gameId = widget.multiplayerGameId;
    if (gameId == null) return;
    try {
      final credentials = await MultiplayerRepository().requestVoiceToken(
        gameId,
      );
      final joined = await _voice.join(
        gameId: gameId,
        credentials: credentials,
      );
      if (joined) {
        await MultiplayerRepository().updateVoicePresence(
          gameId,
          connected: true,
          micEnabled: false,
        );
      }
    } catch (_) {
      // Voice is optional; leave the board fully operational if unavailable.
    }
  }

  Future<void> _toggleVoice() async {
    if (!_voice.isJoined) {
      await _connectVoice();
      if (mounted) setState(() {});
      return;
    }
    await _voice.setMuted(!_voice.isMuted);
    final gameId = widget.multiplayerGameId;
    if (gameId != null) {
      await MultiplayerRepository().updateVoicePresence(
        gameId,
        connected: true,
        micEnabled: !_voice.isMuted,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final notifier = ref.read(_provider.notifier);
    if (lifecycleState == AppLifecycleState.resumed) {
      if (widget.isMultiplayer &&
          widget.multiplayerGameId != null &&
          !_voice.isJoined) {
        unawaited(_connectVoice());
      }
      if (_appLifecyclePauseHeld) {
        _appLifecyclePauseHeld = false;
        notifier.resumeGame();
      }
      if (mounted) setState(() {});
    } else if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      if (_appLifecyclePauseHeld) return;
      _appLifecyclePauseHeld = true;
      if (widget.isMultiplayer) {
        unawaited(_voice.leave());
        if (widget.multiplayerGameId != null) {
          unawaited(
            MultiplayerRepository().updateVoicePresence(
              widget.multiplayerGameId!,
              connected: false,
              micEnabled: false,
            ),
          );
        }
      }
      notifier.pauseGame();
      // Persist immediately using the frozen pause instant. This prevents an
      // app background/termination from charging the player turn time.
      unawaited(notifier.persistPausedGame());
    }
  }

  int _remainingTurnSeconds(GameState state) {
    final start = state.turnStartedAt;
    if (start == null) return 0;
    final pausedAt = ref.read(_provider.notifier).pauseStartedAt;
    final clockNow = pausedAt ?? DateTime.now();
    final remaining = start.add(_turnDuration).difference(clockNow);
    if (remaining.isNegative) return 0;
    return (remaining.inMilliseconds / 1000).ceil();
  }

  StateNotifierProvider<GameNotifier, GameState> get _provider =>
      widget.controllerProvider ?? gameProvider;

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
                        ref
                            .read(_provider.notifier)
                            .setBlankLetter(row, col, char);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.tileIvory,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.5),
                          ),
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
      border = Border.all(
        color: AppTheme.shinyGold.withValues(alpha: 0.55),
        width: 1.2,
      );
      textColor = Colors.white;
    } else {
      gradient = const LinearGradient(
        colors: AppTheme.darkGreenGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      border = Border.all(
        color: AppTheme.shinyGold.withValues(alpha: 0.55),
        width: 1.2,
      );
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

  Future<bool> _showMultiplayerConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    return showPremiumConfirmationSheet(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      danger: danger,
    );
  }

  Future<void> _showPauseDialog() async {
    final settings = ref.read(_provider).settings;
    HapticUtils.trigger(HapticType.tap, settings);
    ref.read(_provider.notifier).pauseGame();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => PremiumDialog(
        title: 'Game Paused',
        child: Column(
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
              label: 'Match Breakdown',
              onTap: () {
                Navigator.of(context).pop();
                PostGameAnalysisDialog.show(
                  context,
                  PostGameSummary.fromGameState(ref.read(_provider)),
                );
              },
            ),
            const SizedBox(height: 12),
            if (widget.isMultiplayer &&
                widget.onMultiplayerRestart != null) ...[
              _premiumDialogButton(
                label: 'Restart Match',
                onTap: () async {
                  Navigator.of(context).pop();
                  final confirmed = await _showMultiplayerConfirmation(
                    title: 'Restart match?',
                    message: 'The current multiplayer progress will be lost.',
                    confirmLabel: 'Restart',
                  );
                  if (!confirmed) return;
                  try {
                    await widget.onMultiplayerRestart!();
                    if (mounted) {
                      ToastUtils.show(context, 'Match restarted');
                    }
                  } catch (error) {
                    if (mounted) {
                      ToastUtils.show(
                        context,
                        'Unable to restart match: $error',
                        isError: true,
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            if (widget.isMultiplayer && widget.onMultiplayerEnd != null) ...[
              _premiumDialogButton(
                label: 'End Match',
                isDanger: true,
                onTap: () async {
                  Navigator.of(context).pop();
                  final confirmed = await _showMultiplayerConfirmation(
                    title: 'End match?',
                    message: 'Both players will leave this match.',
                    confirmLabel: 'End match',
                    danger: true,
                  );
                  if (!confirmed) return;
                  try {
                    await widget.onMultiplayerEnd!();
                  } catch (error) {
                    if (mounted) {
                      ToastUtils.show(
                        context,
                        'Unable to end match: $error',
                        isError: true,
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            if (widget.isMultiplayer && widget.onMultiplayerLeave != null)
              _premiumDialogButton(
                label: 'Leave Match',
                isDanger: true,
                onTap: () async {
                  Navigator.of(context).pop();
                  final confirmed = await _showMultiplayerConfirmation(
                    title: 'Leave match?',
                    message: 'You will leave this multiplayer match.',
                    confirmLabel: 'Leave match',
                    danger: true,
                  );
                  if (!confirmed) return;
                  try {
                    await widget.onMultiplayerLeave!();
                  } catch (error) {
                    if (mounted) {
                      ToastUtils.show(
                        context,
                        'Unable to leave match: $error',
                        isError: true,
                      );
                    }
                  }
                },
              ),
            if (!widget.isMultiplayer) ...[
              _premiumDialogButton(
                label: 'Save & Exit',
                onTap: () async {
                  await ref.read(_provider.notifier).saveGameForExit();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
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
          ],
        ),
      ),
    );
    if (!mounted) return;
    ref.read(_provider.notifier).resumeGame();
    setState(() {});
  }

  void _confirmRestart() {
    final state = ref.read(_provider);
    showPremiumConfirmationSheet(
      context,
      title: 'Restart Match?',
      message: 'Your current progress will be lost. Restart this match?',
      confirmLabel: 'Restart',
      danger: true,
    ).then((confirmed) {
      if (confirmed) {
        ref.read(_provider.notifier).startNewGame(state.difficulty);
      }
    });
  }

  void _confirmAbandon() {
    showPremiumConfirmationSheet(
      context,
      title: 'Abandon Game?',
      message:
          'Abandoning is recorded as a Loss in statistics. Return to main menu?',
      confirmLabel: 'Abandon',
      danger: true,
    ).then((confirmed) async {
      if (!confirmed) return;
      await ref.read(_provider.notifier).abandonGame();
      if (context.mounted) Navigator.of(context).pop();
    });
  }

  void _showPassConfirm() {
    final settings = ref.read(_provider).settings;
    HapticUtils.trigger(HapticType.tap, settings);
    showPremiumConfirmationSheet(
      context,
      title: 'Pass Turn?',
      message: 'You will score 0 points for this turn. Continue?',
      confirmLabel: 'Pass',
    ).then((confirmed) {
      if (confirmed) ref.read(_provider.notifier).passTurn();
    });
  }

  Future<void> _showExchangeDialog() async {
    if (_exchangeSheetOpen || !mounted) return;

    final state = ref.read(_provider);
    HapticUtils.trigger(HapticType.tap, state.settings);
    final notifier = ref.read(_provider.notifier);
    final wasAlreadyPaused = notifier.isGamePaused;
    _exchangeSheetOpen = true;
    if (!wasAlreadyPaused) notifier.pauseGame();

    try {
      if (state.tileBag.length < 7) {
        await showPremiumConfirmationSheet(
          context,
          title: 'Exchange Unavailable',
          message:
              'Tile exchange unlocks when at least 7 tiles remain in the bag. ${state.tileBag.length} ${state.tileBag.length == 1 ? 'tile remains' : 'tiles remain'} right now.',
          confirmLabel: 'Got it',
        );
        return;
      }

      final List<Tile> selectedToExchange = [];
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF021710),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(color: AppTheme.shinyGold, width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.shinyGold.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz_rounded,
                            color: AppTheme.shinyGold,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Exchange Tiles',
                              style: GoogleFonts.lora(
                                color: AppTheme.shinyGold,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppTheme.shinyGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose the tiles you want to return to the bag.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppTheme.mutedIvory,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: state.playerRack.map((tile) {
                          final isSelected = selectedToExchange.any(
                            (selected) => selected.id == tile.id,
                          );
                          return GestureDetector(
                            onTap: () => setSheetState(() {
                              if (isSelected) {
                                selectedToExchange.removeWhere(
                                  (selected) => selected.id == tile.id,
                                );
                              } else {
                                selectedToExchange.add(tile);
                              }
                            }),
                            child: Container(
                              width: 44,
                              height: 50,
                              decoration: AppTheme.tileDecoration(
                                isSelected: isSelected,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      tile.letter.trim().isEmpty
                                          ? ' '
                                          : tile.letter,
                                      style: GoogleFonts.lora(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkCharcoal,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    bottom: 3,
                                    child: Text(
                                      tile.scoreValue.toString(),
                                      style: const TextStyle(
                                        fontSize: 9,
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
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _premiumDialogButton(
                              label: 'Cancel',
                              onTap: () => Navigator.of(sheetContext).pop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _premiumDialogButton(
                              label: selectedToExchange.isEmpty
                                  ? 'Select tiles'
                                  : 'Exchange ${selectedToExchange.length}',
                              isPrimary: true,
                              onTap: () {
                                if (selectedToExchange.isEmpty) return;
                                final tiles = List<Tile>.of(selectedToExchange);
                                Navigator.of(sheetContext).pop();
                                ref
                                    .read(_provider.notifier)
                                    .exchangeTiles(tiles);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _exchangeSheetOpen = false;
      if (mounted && !wasAlreadyPaused) {
        notifier.resumeGame();
        setState(() {});
      }
    }
  }

  void _handleSubmit() {
    final state = ref.read(_provider);
    final error = ref.read(_provider.notifier).submitPlayerMove();
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
    final state = ref.watch(_provider);
    final bool isCompleted = state.status == 'gameCompleted';
    final double edgeContentTightening =
        Theme.of(context).platform == TargetPlatform.android
        ? _edgeContentTightening
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showPauseDialog();
      },
      child: Scaffold(
        body: PremiumBackground(
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Transform.translate(
                      offset: Offset(0, edgeContentTightening),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── 1. Custom App Bar ───────────────────────────────────
                          _buildHeader(state),
                          // ── 2. Scoreboard ───────────────────────────────────────
                          _buildScoreboard(state),
                          // ── 3. Status Banner ────────────────────────────────────
                          _buildStatusBanner(state),
                        ],
                      ),
                    ),
                    // ── 4. Board & Rack Grouped ─────────────────────────────
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBoard(state),
                            const SizedBox(height: 8),
                            _buildRack(state),
                          ],
                        ),
                      ),
                    ),
                    // ── 5. Action buttons & Play Row ────────────────────────
                    Transform.translate(
                      offset: Offset(0, -edgeContentTightening),
                      child: _buildActionsPanel(state),
                    ),
                  ],
                ),
                if (state.status == 'computerThinking' && !widget.isMultiplayer)
                  _buildAIOverlay(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
                  width: 38,
                  height: 38,
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
                          '→',
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
                          '←',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
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
                height: 38,
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
    if (widget.isMultiplayer && state.multiplayerPlayers.length > 2) {
      return _buildMultiplayerScoreboard(state);
    }
    final isPlayerTurn =
        state.currentTurn == 'player' && state.status == 'playerTurn';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
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
              label: widget.isMultiplayer
                  ? (widget.opponentName ?? 'OPPONENT')
                  : 'COMPUTER',
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

  Widget _buildMultiplayerScoreboard(GameState state) {
    final localId = Supabase.instance.client.auth.currentUser?.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: state.multiplayerPlayers.map((player) {
              final score = state.multiplayerScores[player.userId] ?? 0;
              final active =
                  player.userId ==
                          state.multiplayerPlayers
                              .firstWhere(
                                (p) => p.userId == localId,
                                orElse: () => player,
                              )
                              .userId &&
                      state.currentTurn == 'player' ||
                  player.userId != localId && state.currentTurn != 'player';
              return SizedBox(
                width: (MediaQuery.sizeOf(context).width - 38) / 2,
                child: _buildScoreCard(
                  label: player.userId == localId ? 'YOU' : player.displayName,
                  score: score,
                  isActive: active,
                  iconData: player.micEnabled
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  avatarColor: _activeSpeakers.isNotEmpty && player.micEnabled
                      ? Colors.greenAccent
                      : AppTheme.shinyGold,
                ),
              );
            }).toList(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: _toggleVoice,
              tooltip: _voice.isMuted ? 'Enable microphone' : 'Mute microphone',
              icon: Icon(
                _voice.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              ),
              color: _voice.isJoined ? AppTheme.shinyGold : AppTheme.mutedIvory,
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
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.shinyGold
              : AppTheme.shinyGold.withValues(alpha: 0.35),
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
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Profile Avatar
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF010A07),
              border: Border.all(
                color: isActive
                    ? avatarColor
                    : avatarColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Icon(
                iconData,
                color: isActive
                    ? avatarColor
                    : avatarColor.withValues(alpha: 0.6),
                size: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$label: ',
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ivoryText,
                ),
              ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF021710),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.shinyGold.withValues(alpha: 0.25),
          width: 1.0,
        ),
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
            if (state.turnStartedAt != null &&
                (state.status == 'playerTurn' ||
                    (widget.isMultiplayer &&
                        state.status == 'waitingForOpponent')))
              _buildTurnCountdown(state),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnCountdown(GameState state) {
    final seconds = _remainingTurnSeconds(state);
    final minutes = seconds ~/ 60;
    final display = '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
    final urgent = seconds <= 10;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: urgent
            ? const Color(0xFF5A120A).withValues(alpha: 0.8)
            : const Color(0xFF0B2A1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: urgent
              ? Colors.redAccent
              : AppTheme.shinyGold.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        display,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: urgent ? Colors.white : AppTheme.shinyGold,
        ),
      ),
    );
  }

  String _defaultStatusMsg(GameState state) {
    switch (state.status) {
      case 'playerTurn':
        return 'Your turn — place your tiles!';
      case 'computerThinking':
        return widget.isMultiplayer
            ? 'Waiting for your opponent...'
            : 'Computer is thinking...';
      case 'waitingForOpponent':
        return "Opponent's turn";
      case 'computerTurn':
        return widget.isMultiplayer
            ? 'Opponent is playing...'
            : 'Computer is playing...';
      case 'gameCompleted':
        return 'Game over!';
      case 'gamePaused':
        return 'Match paused — resume when ready.';
      default:
        return '';
    }
  }

  // ── Board ──────────────────────────────────────────────────────────────────
  Widget _buildBoard(GameState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double coordW = 14.0;
        const double coordH = 12.0;
        const double gap = 1.0;
        const double paddingTotal = 6.0; // padding 3 * 2
        const double borderTotal = 3.0; // border 1.5 * 2
        const double decorationTotal = paddingTotal + borderTotal; // 9.0

        // Available space for grid cells (subtracting board decoration)
        final bool isAndroid =
            Theme.of(context).platform == TargetPlatform.android;
        final double boardConstraintWidth = isAndroid
            ? constraints.maxWidth
            : (constraints.maxWidth > 390 ? 390 : constraints.maxWidth);
        final double gridW = boardConstraintWidth - coordW - decorationTotal;
        final double gridH =
            constraints.maxHeight - (coordH * 2) - decorationTotal;

        // Pick the smaller axis so nothing overflows or crops
        final double cellW = (gridW - 14 * gap) / 15;
        final double cellH = (gridH - 14 * gap) / 15;
        final double cellSize = cellW < cellH ? cellW : cellH;

        // Actual grid dimensions
        final double actualGridW = cellSize * 15 + gap * 14;
        final double actualGridH = cellSize * 15 + gap * 14;

        // The Container sizes should wrap the actual content exactly!
        final double boardWidth = actualGridW + coordW + decorationTotal;
        final double boardHeight = actualGridH + (coordH * 2) + decorationTotal;

        // Grid starts right after coordinate labels
        const double offsetX = coordW;
        const double offsetY = coordH;

        return Center(
          child: Container(
            width: boardWidth,
            height: boardHeight,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.boardFrame,
              border: Border.all(color: AppTheme.boardFrameEdge, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Top number labels ──
                ...List.generate(15, (c) {
                  final double x = offsetX + c * (cellSize + gap);
                  return Positioned(
                    left: x,
                    top: 0,
                    width: cellSize,
                    height: coordH,
                    child: Center(
                      child: Text(
                        '${c + 1}',
                        style: const TextStyle(
                          fontSize: 7,
                          color: AppTheme.mutedIvory,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),

                // ── Bottom number labels ──
                ...List.generate(15, (c) {
                  final double x = offsetX + c * (cellSize + gap);
                  return Positioned(
                    left: x,
                    bottom: 0,
                    width: cellSize,
                    height: coordH,
                    child: Center(
                      child: Text(
                        '${c + 1}',
                        style: const TextStyle(
                          fontSize: 7,
                          color: AppTheme.mutedIvory,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),

                // ── Left letter labels ──
                ...List.generate(15, (r) {
                  final double y = offsetY + r * (cellSize + gap);
                  return Positioned(
                    left: 0,
                    top: y,
                    width: coordW,
                    height: cellSize,
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + r),
                        style: const TextStyle(
                          fontSize: 7,
                          color: AppTheme.mutedIvory,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),

                // ── Board cells (15×15) ──
                ...List.generate(225, (index) {
                  final r = index ~/ 15;
                  final c = index % 15;
                  final double x = offsetX + c * (cellSize + gap);
                  final double y = offsetY + r * (cellSize + gap);
                  return Positioned(
                    left: x,
                    top: y,
                    width: cellSize,
                    height: cellSize,
                    child: _buildBoardCell(state, r, c, cellSize),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // (Coord helpers inlined into _buildBoard above)

  // ── Board Cell ─────────────────────────────────────────────────────────────
  Widget _buildBoardCell(GameState state, int r, int c, double size) {
    final cell = state.board[r][c];
    final tile = cell.tile;
    final isNew = cell.isNewPlacement;
    final hintPlacement = state.status == 'playerTurn'
        ? _hintPlacementAt(r, c)
        : null;

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
          childWhenDragging: Container(
            decoration: AppTheme.cellDecoration(cell.type),
          ),
          onDragStarted: () =>
              SoundManager.play(SoundType.pickup, state.settings),
          onDragCompleted: () =>
              ref.read(_provider.notifier).recallTileAt(r, c),
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
        final placed = ref
            .read(_provider.notifier)
            .placeTile(incomingTile, r, c);
        if (placed && incomingTile.isBlank) {
          _promptBlankTileSelection(context, r, c);
        }
      },
      builder: (context, candidateData, _) {
        final isHover = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () {
            if (state.status != 'playerTurn') return;
            if (_activeHint != null) setState(() => _activeHint = null);
            if (tile != null) {
              if (cell.isNewPlacement) {
                HapticUtils.trigger(HapticType.tap, state.settings);
                ref.read(_provider.notifier).recallTileAt(r, c);
              }
            } else {
              if (_selectedRackTile != null) {
                SoundManager.play(SoundType.place, state.settings);
                HapticUtils.trigger(HapticType.place, state.settings);
                final blankToPlace = _selectedRackTile!.isBlank;
                final placed = ref
                    .read(_provider.notifier)
                    .placeTile(_selectedRackTile!, r, c);
                if (placed) {
                  setState(() => _selectedRackTile = null);
                  if (blankToPlace) _promptBlankTileSelection(context, r, c);
                }
              }
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: AppTheme.cellDecoration(
                  cell.type,
                  isHover: isHover,
                ),
                child: cellContent,
              ),
              if (hintPlacement != null && tile == null)
                IgnorePointer(child: _buildHintCell(hintPlacement, size)),
            ],
          ),
        );
      },
    );
  }

  PlacedTileInput? _hintPlacementAt(int row, int col) {
    final hint = _activeHint;
    if (hint == null) return null;
    for (final placement in hint.placements) {
      if (placement.row == row && placement.col == col) return placement;
    }
    return null;
  }

  Widget _buildHintCell(PlacedTileInput placement, double size) {
    final hint = _activeHint!;
    final showLetter = hint.hintType != 'move';
    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldDark.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.shinyGold.withValues(alpha: 0.88),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shinyGold.withValues(alpha: 0.24),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          showLetter ? (placement.blankLetter ?? placement.letter) : '?',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: AppTheme.ivoryText.withValues(alpha: 0.94),
            shadows: [
              Shadow(
                color: AppTheme.darkCharcoal.withValues(alpha: 0.9),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.shinyGold.withValues(alpha: 0.65),
          width: 1.5,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFF021D14), Color(0xFF063323), Color(0xFF021D14)],
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
                  border: Border(
                    right: BorderSide(color: AppTheme.shinyGold, width: 1.5),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFF1CC),
                      Color(0xFFD4AF37),
                      Color(0xFF8A640F),
                    ],
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
                  border: Border(
                    left: BorderSide(color: AppTheme.shinyGold, width: 1.5),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFF1CC),
                      Color(0xFFD4AF37),
                      Color(0xFF8A640F),
                    ],
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
                    final tileWidget = _buildTileWidget(tile, 34, isNew: false);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Draggable<Tile>(
                        data: tile,
                        feedback: Opacity(opacity: 0.75, child: tileWidget),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: tileWidget,
                        ),
                        onDragStarted: () {
                          HapticUtils.trigger(HapticType.tap, state.settings);
                          SoundManager.play(SoundType.pickup, state.settings);
                          setState(() => _selectedRackTile = null);
                        },
                        child: GestureDetector(
                          onTap: state.status == 'playerTurn'
                              ? () {
                                  HapticUtils.trigger(
                                    HapticType.tap,
                                    state.settings,
                                  );
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
                                          color: AppTheme.shinyGold.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 8,
                                        ),
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
    final bool hasNew = state.board.any(
      (row) => row.any((c) => c.isNewPlacement),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.undo_rounded,
                  label: 'Recall',
                  enabled: isPlayerTurn && hasNew,
                  onTap: () =>
                      ref.read(_provider.notifier).recallAllNewPlacements(),
                  state: state,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  enabled: isPlayerTurn,
                  onTap: () => ref.read(_provider.notifier).shuffleRack(),
                  state: state,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Exchange',
                  enabled: isPlayerTurn,
                  badge: '7+',
                  onTap: _showExchangeDialog,
                  state: state,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.flag_rounded,
                  label: 'Pass',
                  enabled: isPlayerTurn,
                  onTap: _showPassConfirm,
                  state: state,
                ),
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          // Circular Menu/Pause Button
          InkWell(
            onTap: _showPauseDialog,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.shinyGold, width: 1.2),
                color: const Color(0xFF010A07),
              ),
              child: const Center(
                child: Icon(
                  Icons.menu_rounded,
                  color: AppTheme.shinyGold,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Circular Hint Button. In online matches, opening help pauses the
          // shared match through MultiplayerGameNotifier, so neither player
          // loses their timed turn while the private suggestion is visible.
          RepaintBoundary(
            key: _hintButtonKey,
            child: InkWell(
              onTap: widget.isMultiplayer && !isPlayerTurn
                  ? null
                  : () {
                      unawaited(Coachmark.dismiss('solo_hint_button'));
                      unawaited(Coachmark.dismiss('multiplayer_hint_button'));
                      HintModal.show(
                        context: context,
                        boardGrid: state.board,
                        playerRack: state.playerRack,
                        onHintGenerated: (hint) {
                          if (!mounted) return;
                          setState(() => _activeHint = hint);
                        },
                        // The turn clock is frozen for the entire help flow,
                        // including the boost/ad dialog, not only while calculating.
                        onModalOpened: () =>
                            ref.read(_provider.notifier).pauseGame(),
                        onModalClosed: () =>
                            ref.read(_provider.notifier).resumeGame(),
                      );
                    },
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.shinyGold, width: 1.2),
                  color: const Color(0xFF010A07),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: AppTheme.shinyGold,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Play Word Pill Button
          Expanded(
            child: Opacity(
              opacity: enabled ? 1.0 : 0.45,
              child: Container(
                height: 44,
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
                      ? Border.all(
                          color: AppTheme.shinyGold.withValues(alpha: 0.45),
                          width: 1.2,
                        )
                      : null,
                  gradient: LinearGradient(
                    colors: enabled
                        ? AppTheme.goldGradient
                        : AppTheme.darkGreenGradient,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: enabled
                              ? const Color(0xFF1E1402)
                              : AppTheme.shinyGold,
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
    final Color contentColor = enabled
        ? AppTheme.shinyGold
        : AppTheme.mutedIvory.withValues(alpha: 0.3);

    final Widget capsule = Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF021710),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? AppTheme.shinyGold.withValues(alpha: 0.45)
              : AppTheme.shinyGold.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticUtils.trigger(HapticType.tap, state.settings);
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(13),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: contentColor, size: 16),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: contentColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (badge != null && enabled) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          capsule,
          Positioned(
            top: -6,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF021710),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.shinyGold, width: 0.8),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return capsule;
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
            border: Border.all(
              color: AppTheme.shinyGold.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.shinyGold),
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              const Text(
                'Computer is thinking...',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.ivoryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Formulating candidates...',
                style: TextStyle(fontSize: 12, color: AppTheme.mutedIvory),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(GameState state) {
    final scores = state.multiplayerScores.isNotEmpty
        ? state.multiplayerScores.values.toList()
        : [state.playerScore, state.computerScore];
    final bestScore = scores.reduce((a, b) => a > b ? a : b);
    final localId = Supabase.instance.client.auth.currentUser?.id;
    final localScore = state.multiplayerScores[localId] ?? state.playerScore;
    final bool isWin =
        localScore == bestScore &&
        scores.where((score) => score == bestScore).length == 1;
    final bool isTie = scores.where((score) => score == bestScore).length > 1;
    final String headline = isTie
        ? "IT'S A TIE!"
        : (isWin ? 'VICTORY' : 'DEFEAT');
    final Color headlineColor = isTie
        ? AppTheme.warmGold
        : (isWin ? AppTheme.shinyGold : Colors.redAccent);

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
                      isWin
                          ? Icons.emoji_events_rounded
                          : (isTie
                                ? Icons.handshake_rounded
                                : Icons.gavel_rounded),
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
              if (state.multiplayerPlayers.length > 2)
                Wrap(
                  spacing: 18,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: state.multiplayerPlayers.map((player) {
                    final score = state.multiplayerScores[player.userId] ?? 0;
                    return _overScore(
                      player.userId == localId ? 'YOU' : player.displayName,
                      score,
                      score == bestScore,
                    );
                  }).toList(),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _overScore('YOU', state.playerScore, isWin && !isTie),
                    Container(
                      width: 1.2,
                      height: 52,
                      color: AppTheme.shinyGold.withValues(alpha: 0.25),
                    ),
                    _overScore(
                      'COMPUTER',
                      state.computerScore,
                      !isWin && !isTie,
                    ),
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
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.mutedIvory,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score.toString(),
          style: GoogleFonts.lora(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isWinner ? AppTheme.shinyGold : AppTheme.ivoryText,
          ),
        ),
      ],
    );
  }
}
