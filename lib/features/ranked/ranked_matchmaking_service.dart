import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/game_state.dart';
import '../../models/multiplayer_game.dart';
import '../auth/auth_service.dart';
import '../auth/save_progress_modal.dart';
import '../game/game_notifier.dart';
import '../game/game_screen.dart';
import '../multiplayer/multiplayer_game_notifier.dart';
import '../multiplayer/multiplayer_repository.dart';

class RankedMatchmakingService {
  static Future<void> startRankedMatchmaking(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profile = ref.read(authProvider);
    if (profile.isGuest) {
      final confirmed = await showPremiumConfirmationSheet(
        context,
        title: 'Account Required for Ranked',
        message: 'Save your progress to enter Competitive Duel and earn a rating!',
        confirmLabel: 'Continue with Google',
      );
      if (confirmed && context.mounted) await SaveProgressModal.show(context);
      return;
    }

    final game = await showDialog<MultiplayerGame>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => RankedQueueDialog(displayName: profile.displayName),
    );
    if (game == null || !context.mounted) return;
    await _openRankedGame(context, ref, game);
  }

  static Future<void> _openRankedGame(
    BuildContext context,
    WidgetRef ref,
    MultiplayerGame game,
  ) async {
    try {
      final repository = MultiplayerRepository();
      final snapshot = await repository.loadGameState(game.id);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final opponent = snapshot.players
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .firstWhere(
            (item) => item['user_id'] != currentUserId,
            orElse: () => <String, dynamic>{},
          );
      final seed = ref.read(gameProvider.notifier).currentState;
      final initialState = snapshot.hydrate(seed);
      final provider = StateNotifierProvider<MultiplayerGameNotifier, GameState>(
        (ref) => MultiplayerGameNotifier(
          gameId: game.id,
          opponentUserId: opponent['user_id'] as String? ?? '',
          initialState: initialState,
          repository: repository,
        ),
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProviderScope(
            overrides: [
              provider.overrideWith(
                (ref) => MultiplayerGameNotifier(
                  gameId: game.id,
                  opponentUserId: opponent['user_id'] as String? ?? '',
                  initialState: initialState,
                  repository: repository,
                ),
              ),
            ],
            child: GameScreen(
              controllerProvider: provider,
              isMultiplayer: true,
              opponentName: opponent['display_name'] as String?,
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('[Ranked] Unable to open matched game: $error');
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (_) => PremiumDialog(
          title: 'Competitive Match Error',
          actions: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CLOSE'),
              ),
            ),
          ],
          child: Text(
            'The match was found, but the board could not be opened. Please try again.',
            style: GoogleFonts.inter(color: AppTheme.mutedIvory),
          ),
        ),
      );
    }
  }
}

class RankedQueueDialog extends StatefulWidget {
  final String displayName;

  const RankedQueueDialog({super.key, required this.displayName});

  @override
  State<RankedQueueDialog> createState() => _RankedQueueDialogState();
}

class _RankedQueueDialogState extends State<RankedQueueDialog> {
  final MultiplayerRepository _repository = MultiplayerRepository();
  Timer? _pollTimer;
  Timer? _elapsedTimer;
  int _searchSeconds = 0;
  String? _error;
  bool _cancelling = false;
  bool _searchExpired = false;

  @override
  void initState() {
    super.initState();
    _joinQueue();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _cancelling || _error != null || _searchExpired) return;
      setState(() => _searchSeconds++);
    });
  }

  Future<void> _joinQueue() async {
    try {
      final result = await _repository.rankedMatchmaking(
        action: 'join',
        displayName: widget.displayName,
      );
      await _handleResult(result);
    } catch (error) {
      debugPrint('[Ranked] Queue join failed: $error');
      if (mounted) {
        setState(() {
          _error = 'Ranked matchmaking is temporarily unavailable. Please try again.';
        });
      }
    }
  }

  Future<void> _poll() async {
    if (!mounted || _cancelling || _error != null || _searchExpired) return;
    if (_searchSeconds >= 90) {
      await _expireSearch();
      return;
    }
    try {
      final result = await _repository.rankedMatchmaking(action: 'status');
      await _handleResult(result);
    } catch (_) {
      // A transient poll failure should not remove a player from the queue.
    }
  }

  Future<void> _handleResult(RankedMatchmakingResult result) async {
    if (result.status == 'expired') {
      await _expireSearch();
      return;
    }
    if (!mounted || result.status != 'matched' || result.game == null) return;
    _pollTimer?.cancel();
    Navigator.of(context).pop(result.game);
  }

  Future<void> _expireSearch() async {
    _cancelling = true;
    _pollTimer?.cancel();
    try {
      await _repository.rankedMatchmaking(action: 'cancel');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _cancelling = false;
        _searchExpired = true;
      });
    }
  }

  Future<void> _keepSearching() async {
    setState(() {
      _searchExpired = false;
      _searchSeconds = 0;
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    await _joinQueue();
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await _repository.rankedMatchmaking(action: 'cancel');
    } catch (_) {
      // The dialog must still close if the queue service is unavailable.
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumDialog(
      title: 'Competitive Match',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error == null && !_searchExpired)
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.shinyGold),
                strokeWidth: 3,
              ),
            )
          else if (_searchExpired)
            const Icon(Icons.hourglass_empty_rounded, color: AppTheme.shinyGold, size: 48)
          else
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 20),
          Text(
            _searchExpired
                ? 'No opponent found yet. Keep searching?'
                : (_error ?? 'Searching for opponent...'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.ivoryText, fontWeight: FontWeight.w600),
          ),
          if (_error == null && !_searchExpired) ...[
            const SizedBox(height: 6),
            Text(
              'We\'ll find another player near your rating. No room code needed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.mutedIvory, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text('Search range expands as you wait', style: GoogleFonts.inter(color: AppTheme.mutedIvory, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Elapsed time: ${_searchSeconds}s', style: GoogleFonts.inter(color: AppTheme.shinyGold, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        if (_searchExpired) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelling ? null : _cancel,
              child: const Text('STOP SEARCH'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _cancelling ? null : _keepSearching,
              child: const Text('KEEP SEARCHING'),
            ),
          ),
        ] else
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelling ? null : _cancel,
              child: Text(_error == null ? 'CANCEL SEARCH' : 'CLOSE'),
            ),
          ),
      ],
    );
  }
}
