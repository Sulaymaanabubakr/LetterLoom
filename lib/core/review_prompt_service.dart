import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Controls the non-intrusive LetterLoom review request.
class ReviewPromptService {
  static const _launchCountKey = 'review_prompt_launch_count';
  static const _lastShownKey = 'review_prompt_last_shown_at';
  static const _completedKey = 'review_prompt_completed';
  static const _androidPackage = 'com.letter.loom';

  static Future<void> maybeShow(BuildContext context) async {
    final preferences = await SharedPreferences.getInstance();
    final launches = preferences.getInt(_launchCountKey) ?? 0;
    await preferences.setInt(_launchCountKey, launches + 1);
    if (launches + 1 < 3 || preferences.getBool(_completedKey) == true) return;

    final lastShown = DateTime.tryParse(
      preferences.getString(_lastShownKey) ?? '',
    );
    if (lastShown != null && DateTime.now().difference(lastShown).inDays < 30) {
      return;
    }
    await preferences.setString(
      _lastShownKey,
      DateTime.now().toIso8601String(),
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => const _ReviewPromptDialog(),
    );
  }

  /// Opens the real review modal without changing the normal prompt schedule.
  /// This is used by the debug-only device test flag.
  static Future<void> showForTesting(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => const _ReviewPromptDialog(),
    );
  }

  static Future<bool> openStoreListing() async {
    final Uri uri;
    if (Platform.isAndroid) {
      uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_androidPackage',
      );
    } else if (Platform.isIOS) {
      // The repository has no published Apple App Store ID yet. Keep this
      // graceful and honest rather than inventing an ID that could open the
      // wrong app; the configured search still lands in Apple's listing flow.
      uri = Uri.parse('https://apps.apple.com/us/search?term=LetterLoom');
    } else {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ReviewPromptDialog extends StatefulWidget {
  const _ReviewPromptDialog();

  @override
  State<_ReviewPromptDialog> createState() => _ReviewPromptDialogState();
}

class _ReviewPromptDialogState extends State<_ReviewPromptDialog> {
  int _rating = 0;
  bool _opening = false;

  Future<void> _submit() async {
    if (_rating == 0 || _opening) return;
    setState(() => _opening = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(ReviewPromptService._completedKey, true);
    final opened = await ReviewPromptService.openStoreListing();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The app store could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumDialog(
      title: 'Enjoying LetterLoom?',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: _opening ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.mutedIvory,
              side: BorderSide(
                color: AppTheme.mutedIvory.withValues(alpha: 0.4),
              ),
            ),
            child: Text('NOT NOW', style: GoogleFonts.inter()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _rating == 0 || _opening ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.shinyGold,
              foregroundColor: AppTheme.darkCharcoal,
              disabledBackgroundColor: AppTheme.shinyGold.withValues(
                alpha: 0.25,
              ),
            ),
            child: Text(
              _opening ? 'OPENING STORE…' : 'SUBMIT',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your review helps LetterLoom grow.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.mutedIvory),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                icon: Icon(
                  index < _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppTheme.shinyGold,
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
