import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/save_progress_modal.dart';

class RankedMatchmakingService {
  /// Starts Ranked Matchmaking. If player is guest, shows Save Progress prompt.
  static Future<void> startRankedMatchmaking(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profile = ref.read(authProvider);
    if (profile.isGuest) {
      final confirmed = await showPremiumConfirmationSheet(
        context,
        title: 'Account Required for Ranked',
        message:
            'Save your progress to play Ranked 1v1 and earn competitive ratings!',
        confirmLabel: 'Continue with Google',
      );
      if (confirmed && context.mounted) await SaveProgressModal.show(context);
      return;
    }

    // There is no ranked queue, server-side result verifier, or rating RPC in
    // this repository. A spinner here would falsely imply a real match.
    showDialog(
      context: context,
      builder: (context) => PremiumDialog(
        title: 'Ranked is unavailable',
        child: Text(
          'Ranked matchmaking is being prepared for a future server release. Your rating cannot be changed from this build.',
          style: GoogleFonts.inter(color: AppTheme.mutedIvory),
        ),
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ),
        ],
      ),
    );
  }
}

class RankedQueueDialog extends StatefulWidget {
  const RankedQueueDialog({super.key});

  @override
  State<RankedQueueDialog> createState() => _RankedQueueDialogState();
}

class _RankedQueueDialogState extends State<RankedQueueDialog> {
  int _searchSeconds = 0;
  Timer? _timer;
  int _ratingRange = 100;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _searchSeconds++;
        if (_searchSeconds % 5 == 0) {
          _ratingRange += 50; // Widen search window
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.panelDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.shinyGold, width: 1.5),
      ),
      title: Text(
        'Ranked Matchmaking',
        textAlign: TextAlign.center,
        style: GoogleFonts.lora(
          color: AppTheme.ivoryText,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.shinyGold),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Searching for opponent...',
            style: GoogleFonts.inter(
              color: AppTheme.ivoryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rating Range: ±$_ratingRange',
            style: GoogleFonts.inter(color: AppTheme.shinyGold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Elapsed Time: ${_searchSeconds}s',
            style: GoogleFonts.inter(color: AppTheme.mutedIvory, fontSize: 12),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.mutedIvory),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel Search',
            style: TextStyle(color: AppTheme.mutedIvory),
          ),
        ),
      ],
    );
  }
}
