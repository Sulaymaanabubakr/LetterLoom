import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/board_cell.dart';

class AppTheme {
  // ── Core Palette ────────────────────────────────────────────────────────────
  static const Color scaffoldDark = Color(0xFF02130E); // near-black green bg
  static const Color boardSurface = Color(0xFF0B2B1F); // dark board cells
  static const Color panelDark = Color(0xFF07281D); // score / rack bg
  static const Color forestGreen = Color(0xFF0F382B); // legacy compat
  static const Color emeraldGreen = Color(0xFF1B895C); // active / player accent
  static const Color midGreen = Color(0xFF104A35); // button gradient a
  static const Color darkGreen = Color(0xFF0B3827); // button gradient b
  static const Color boardFrame = Color(0xFF3A1E0D); // mahogany wood frame
  static const Color boardFrameEdge = Color(
    0xFF6B3618,
  ); // lighter mahogany edge

  // ── Tile ────────────────────────────────────────────────────────────────────
  static const Color tileIvory = Color(0xFFFAF5E4); // tile face
  static const Color tileShadowDeep = Color(0xFFC1B49F); // bottom bevel
  static const Color tileText = Color(0xFF1A1A1A); // letter colour
  static const Color tileSubText = Color(0xFF4A4A4A); // score sub-text

  // ── Text on dark bg ─────────────────────────────────────────────────────────
  static const Color ivoryText = Color(0xFFF4EDD8);
  static const Color mutedIvory = Color(0xFFB8AC94);

  // ── Accent ──────────────────────────────────────────────────────────────────
  static const Color shinyGold = Color(0xFFD4AF37);
  static const Color warmGold = Color(0xFFB8962E);
  static const Color darkCharcoal = Color(0xFF1A1A1A);
  static const Color lightGrey = Color(0xFF2E4438);

  // ── Home Screen Premium Gradients ───────────────────────────────────────────
  static const List<Color> goldGradient = [
    Color(0xFFF9D67A),
    Color(0xFFD59F25),
    Color(0xFF9E7108),
  ];
  static const List<Color> darkGreenGradient = [
    Color(0xFF0A3022),
    Color(0xFF031610),
  ];

  // ── Premium Cell Colors ──────────────────────────────────────────────────────
  static const Color tripleWordColor = Color(0xFFC63B30); // TW – terracotta red
  static const Color doubleWordColor = Color(0xFFD8753C); // DW – clay orange
  static const Color tripleLetterColor = Color(0xFF1C6CB3); // TL – steel blue
  static const Color doubleLetterColor = Color(0xFF2A9080); // DL – teal
  static const Color centerColor = Color(0xFFD4AF37); // ★ – gold star

  // ── Material Theme ──────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldDark,
      colorScheme: const ColorScheme.dark(
        primary: emeraldGreen,
        secondary: shinyGold,
        tertiary: tileIvory,
        surface: panelDark,
        onPrimary: Colors.white,
        onSecondary: darkCharcoal,
        onSurface: ivoryText,
        error: Color(0xFFBA1A1A),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.lora(
          fontWeight: FontWeight.bold,
          color: ivoryText,
        ),
        headlineLarge: GoogleFonts.lora(
          fontWeight: FontWeight.bold,
          color: ivoryText,
        ),
        titleLarge: GoogleFonts.lora(
          fontWeight: FontWeight.w600,
          color: ivoryText,
        ),
        bodyLarge: GoogleFonts.inter(color: ivoryText),
        bodyMedium: GoogleFonts.inter(color: ivoryText),
        labelLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: ivoryText,
        ),
      ),
      cardTheme: CardThemeData(
        color: panelDark,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: shinyGold.withValues(alpha: 0.3), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panelDark,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: shinyGold.withValues(alpha: 0.5), width: 1),
        ),
      ),
    );
  }

  // ── Tile Decoration ─────────────────────────────────────────────────────────
  static BoxDecoration tileDecoration({
    bool isSelected = false,
    bool isNew = false,
  }) {
    return BoxDecoration(
      color: tileIvory,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: isSelected
            ? shinyGold
            : isNew
            ? emeraldGreen
            : const Color(0xFFD8CEB8),
        width: isSelected
            ? 2.5
            : isNew
            ? 2.0
            : 1.2,
      ),
      boxShadow: [
        // Top-left highlight
        const BoxShadow(
          color: Colors.white,
          offset: Offset(-0.5, -0.5),
          blurRadius: 0,
          spreadRadius: 0,
        ),
        // Physical bottom bevel (wood shadow)
        BoxShadow(
          color: tileShadowDeep.withValues(alpha: 0.9),
          offset: const Offset(0, 3),
          blurRadius: 0,
          spreadRadius: 0,
        ),
        // Drop shadow on board
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(0, 3),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // ── Cell Decoration ─────────────────────────────────────────────────────────
  static BoxDecoration cellDecoration(
    CellType type, {
    bool isSelected = false,
    bool isHover = false,
  }) {
    final Color base = _cellColor(type);
    return BoxDecoration(
      color: isHover ? base.withValues(alpha: 0.7) : base,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: isSelected
            ? shinyGold
            : type == CellType.normal
            ? const Color(0xFF184A38)
            : shinyGold.withValues(alpha: 0.35),
        width: isSelected ? 2 : 0.8,
      ),
    );
  }

  static Color _cellColor(CellType type) {
    switch (type) {
      case CellType.doubleLetter:
        return doubleLetterColor;
      case CellType.tripleLetter:
        return tripleLetterColor;
      case CellType.doubleWord:
        return doubleWordColor;
      case CellType.tripleWord:
        return tripleWordColor;
      case CellType.centre:
        return centerColor;
      default:
        return boardSurface;
    }
  }

  static String cellLabel(CellType type) {
    switch (type) {
      case CellType.doubleLetter:
        return 'DL';
      case CellType.tripleLetter:
        return 'TL';
      case CellType.doubleWord:
        return 'DW';
      case CellType.tripleWord:
        return 'TW';
      case CellType.centre:
        return '★';
      default:
        return '';
    }
  }
}

class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const PremiumBackgroundPainter(), child: child);
  }
}

class PremiumBackgroundPainter extends CustomPainter {
  const PremiumBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Paint vignette radial gradient background
    final Paint bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        radius: 1.4,
        colors: const [
          Color(0xFF063021), // rich forest green center
          Color(0xFF021710), // dark emerald green middle
          Color(0xFF010604), // near-black green corners
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shared LetterLoom header used by secondary screens. Keeping this in the
/// theme prevents feature screens from drifting into unrelated Material UI.
class PremiumPageHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const PremiumPageHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.shinyGold,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '➔  ',
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
                          title.toUpperCase(),
                          style: GoogleFonts.lora(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Text(
                        '  ➔',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) Positioned(right: 0, child: action!),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.shinyGold.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Transform.rotate(
                angle: 3.14159 / 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldGreen,
                    border: Border.all(color: AppTheme.shinyGold, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.shinyGold.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PremiumDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  const PremiumDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppTheme.darkGreenGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.shinyGold, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.shinyGold,
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
            const SizedBox(height: 16),
            child,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> showPremiumConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => _PremiumConfirmationSheet(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          danger: danger,
        ),
      ) ??
      false;
}

class _PremiumConfirmationSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  const _PremiumConfirmationSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF021710),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.shinyGold, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '➔  ',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lora(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.ivoryText,
                          ),
                        ),
                      ),
                      Text(
                        '  ➔',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.shinyGold.withValues(alpha: 0.55),
                      ),
                      color: const Color(0xFF010E0A),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.shinyGold,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.mutedIvory,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ConfirmationButton(
                    label: 'CANCEL',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ConfirmationButton(
                    label: confirmLabel.toUpperCase(),
                    primary: !danger,
                    danger: danger,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  const _ConfirmationButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = primary
        ? const LinearGradient(
            colors: AppTheme.goldGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : danger
        ? const LinearGradient(
            colors: [Color(0xFF5A120A), Color(0xFF2E0502)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: AppTheme.darkGreenGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: gradient,
        border: primary
            ? null
            : Border.all(
                color: AppTheme.shinyGold.withValues(alpha: 0.55),
                width: 1.2,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.lora(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primary ? AppTheme.darkCharcoal : AppTheme.shinyGold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
