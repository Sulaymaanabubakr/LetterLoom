import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../core/toast_utils.dart';
import 'auth_service.dart';

class SaveProgressModal extends ConsumerWidget {
  const SaveProgressModal({super.key});

  static Future<void> show(BuildContext context) async {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SaveProgressModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF021710),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.shinyGold, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '→',
                        style: GoogleFonts.inter(
                          fontSize: 16,
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
                          'Save Your Progress',
                          style: GoogleFonts.lora(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '←',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(8, -10),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.shinyGold.withValues(alpha: 0.55),
                          width: 1.0,
                        ),
                        color: const Color(0xFF010E0A),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: AppTheme.shinyGold,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cloud Icon Display
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF07281D),
                  border: Border.all(
                    color: AppTheme.shinyGold.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.cloud_upload_rounded,
                    color: AppTheme.shinyGold,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Supporting Explanation
            Text(
              'Keep your stats, achievements, streaks, levels, unlocks and competitive progress safe across devices.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.ivoryText,
              ),
            ),
            const SizedBox(height: 24),
            // Primary Action: Continue with Google
            Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: AppTheme.goldGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shinyGold.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final success = await ref
                        .read(authProvider.notifier)
                        .signInWithGoogle(
                          onError: (msg) {
                            if (context.mounted) {
                              ToastUtils.showToast(context, msg, isError: true);
                            }
                          },
                        );
                    if (success && context.mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        final navigator = Navigator.of(
                          context,
                          rootNavigator: true,
                        );
                        if (navigator.canPop()) navigator.pop();
                        if (context.mounted) {
                          ToastUtils.showToast(
                            context,
                            'Account connected! Progress saved.',
                          );
                        }
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Official multicolour Google G mark; never substitute
                      // a text glyph because its shape varies by font.
                      ClipOval(
                        child: Container(
                          width: 26,
                          height: 26,
                          color: Colors.white,
                          padding: const EdgeInsets.all(4),
                          child: SvgPicture.asset(
                            'assets/images/google_g_logo.svg',
                            semanticsLabel: 'Google',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1402),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary Action: Maybe Later
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Maybe Later',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedIvory,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
