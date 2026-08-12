import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// A small, one-time discovery prompt anchored to a real control.
///
/// Coachmarks never block the rest of the UI. Dismissing one remembers that
/// choice on-device, and the same component can be reused for any future
/// feature that needs a little discoverability without a tutorial screen.
class Coachmark {
  Coachmark._();

  static const _preferencePrefix = 'letterloom_coachmark_';
  static final Map<String, Future<void> Function()> _activeDismissals = {};

  /// Removes a visible coachmark immediately. Screens call this before they
  /// open another route or modal so a screen-specific prompt never follows a
  /// player elsewhere in the app.
  static Future<void> dismiss(String id) async {
    final dismissal = _activeDismissals.remove(id);
    if (dismissal != null) await dismissal();
  }

  static Future<void> showOnce({
    required BuildContext context,
    required String id,
    required GlobalKey targetKey,
    required String title,
    required String message,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('$_preferencePrefix$id') == true ||
        !context.mounted) {
      return;
    }

    // The target may not have been laid out yet when a route first appears.
    final targetContext = targetKey.currentContext;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (targetContext == null) return;
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final target = box.localToGlobal(Offset.zero);
    final targetCenter = target.dx + box.size.width / 2;
    final screen = MediaQuery.sizeOf(context);
    late OverlayEntry entry;
    var dismissed = false;
    Future<void> dismiss() async {
      if (dismissed) return;
      dismissed = true;
      _activeDismissals.remove(id);
      entry.remove();
      await preferences.setBool('$_preferencePrefix$id', true);
    }

    const bubbleWidth = 236.0;
    const estimatedBubbleHeight = 104.0;
    final left = (targetCenter - bubbleWidth / 2).clamp(
      12.0,
      screen.width - bubbleWidth - 12.0,
    );
    // Keep the entire bubble above the target only when it really fits there.
    // The previous fixed top coordinate used the target's top, causing the
    // arrow to land a full bubble-height above the actual control on phones.
    final canFitAbove = target.dy - estimatedBubbleHeight - 12.0 >= 18.0;
    final top = canFitAbove
        ? target.dy - estimatedBubbleHeight - 12.0
        : target.dy + box.size.height + 12.0;
    final pointsDown = canFitAbove;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        width: bubbleWidth,
        child: Material(
          color: Colors.transparent,
          child: _CoachmarkBubble(
            title: title,
            message: message,
            pointsDown: pointsDown,
            arrowOffset: (targetCenter - left).clamp(24.0, bubbleWidth - 24.0),
            onDismiss: dismiss,
          ),
        ),
      ),
    );
    overlay.insert(entry);
    _activeDismissals[id] = dismiss;
  }
}

class _CoachmarkBubble extends StatelessWidget {
  final String title;
  final String message;
  final bool pointsDown;
  final double arrowOffset;
  final VoidCallback onDismiss;

  const _CoachmarkBubble({
    required this.title,
    required this.message,
    required this.pointsDown,
    required this.arrowOffset,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final arrow = CustomPaint(
      size: const Size(18, 10),
      painter: _CoachmarkArrowPainter(pointsDown: pointsDown),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!pointsDown)
          Positioned(left: arrowOffset - 9, top: -9, child: arrow),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D4933),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.shinyGold.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: AppTheme.shinyGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        color: AppTheme.mutedIvory,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.shinyGold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (pointsDown)
          Positioned(left: arrowOffset - 9, bottom: -9, child: arrow),
      ],
    );
  }
}

class _CoachmarkArrowPainter extends CustomPainter {
  final bool pointsDown;
  const _CoachmarkArrowPainter({required this.pointsDown});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width / 2, 0)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF0D4933));
  }

  @override
  bool shouldRepaint(covariant _CoachmarkArrowPainter oldDelegate) =>
      oldDelegate.pointsDown != pointsDown;
}
