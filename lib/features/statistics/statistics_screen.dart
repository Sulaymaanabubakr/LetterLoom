import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../game/game_notifier.dart';
import '../../core/haptic_utils.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final stats = gameState.statistics;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Bar with Back Button & Ornate Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: SizedBox(
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Custom Gold-Bordered Back Button
                      Positioned(
                        left: 0,
                        child: InkWell(
                          onTap: () {
                            HapticUtils.trigger(
                              HapticType.tap,
                              gameState.settings,
                            );
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.shinyGold.withValues(
                                  alpha: 0.65,
                                ),
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
                      // Centered Gold Title
                      Positioned.fill(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFFFF1CC),
                                        Color(0xFFD4AF37),
                                        Color(0xFF8A640F),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ).createShader(bounds),
                                child: Text(
                                  'STATISTICS',
                                  style: GoogleFonts.lora(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
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
                      ),
                    ],
                  ),
                ),
              ),
              // Thin Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                          border: Border.all(
                            color: AppTheme.shinyGold,
                            width: 1.2,
                          ),
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
              const SizedBox(height: 12),
              // Scroll Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 4.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // General record overview card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          gradient: const LinearGradient(
                            colors: AppTheme.darkGreenGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '✦  Win Rate  ✦',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedIvory,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Win rate with Laurel Wreaths
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CustomPaint(
                                  size: Size(45, 60),
                                  painter: LaurelWreathPainter(
                                    isLeft: true,
                                    color: AppTheme.shinyGold,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFFFFF1CC),
                                          Color(0xFFD4AF37),
                                          Color(0xFF8A640F),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ).createShader(bounds),
                                  child: Text(
                                    '${stats.winPercentage.toStringAsFixed(1)}%',
                                    style: GoogleFonts.lora(
                                      fontSize: 46,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const CustomPaint(
                                  size: Size(45, 60),
                                  painter: LaurelWreathPainter(
                                    isLeft: false,
                                    color: AppTheme.shinyGold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // In-card Diamond Divider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppTheme.shinyGold.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Transform.rotate(
                                  angle: 3.14159 / 4,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppTheme.emeraldGreen,
                                      border: Border.all(
                                        color: AppTheme.shinyGold,
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppTheme.shinyGold.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Four Stat Icons Grid
                            Row(
                              children: [
                                _buildRecordMetric(
                                  'GAMES',
                                  stats.totalGames,
                                  Icons.assignment_turned_in_outlined,
                                ),
                                _buildMetricDivider(),
                                _buildRecordMetric(
                                  'WINS',
                                  stats.wins,
                                  Icons.emoji_events_outlined,
                                ),
                                _buildMetricDivider(),
                                _buildRecordMetric(
                                  'LOSSES',
                                  stats.losses,
                                  Icons.shield_outlined,
                                ),
                                _buildMetricDivider(),
                                _buildRecordMetric(
                                  'TIES',
                                  stats.ties,
                                  Icons.handshake_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Personal Records Category
                      _buildCategoryHeader('Personal Records'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          gradient: const LinearGradient(
                            colors: AppTheme.darkGreenGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailedRecordRow(
                              'Highest Game Score',
                              '${stats.highestGameScore} pts',
                              Icons.stars_rounded,
                            ),
                            _buildRowDivider(),
                            _buildDetailedRecordRow(
                              'Best Single-Turn Score',
                              '${stats.highestSingleTurnScore} pts',
                              Icons.track_changes_rounded,
                            ),
                            _buildRowDivider(),
                            _buildDetailedRecordRow(
                              'Longest Word Played',
                              stats.longestWord.isEmpty
                                  ? '-'
                                  : stats.longestWord,
                              Icons.abc_rounded,
                            ),
                            _buildRowDivider(),
                            _buildDetailedRecordRow(
                              'Total Words Submitted',
                              '${stats.totalWordsPlayed}',
                              Icons.menu_book_rounded,
                            ),
                            _buildRowDivider(),
                            _buildDetailedRecordRow(
                              'Total Bingo Bonuses',
                              '${stats.sevenTileBonuses}',
                              Icons.workspace_premium_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Difficulty Victories Category
                      _buildCategoryHeader('Difficulty Victories'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 18.0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          gradient: const LinearGradient(
                            colors: AppTheme.darkGreenGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDifficultyVictoryBox(
                              'EASY',
                              stats.winsEasy,
                              const Color(0xFF0C462B),
                              Colors.greenAccent,
                            ),
                            _buildDifficultyVictoryBox(
                              'MEDIUM',
                              stats.winsMedium,
                              const Color(0xFF5E3C0C),
                              const Color(0xFFECA042),
                            ),
                            _buildDifficultyVictoryBox(
                              'HARD',
                              stats.winsHard,
                              const Color(0xFF4C100C),
                              const Color(0xFFE0524B),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Divider & Footer Line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppTheme.shinyGold.withValues(alpha: 0.4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Transform.rotate(
                            angle: 3.14159 / 4,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldGreen,
                                border: Border.all(
                                  color: AppTheme.shinyGold,
                                  width: 1.5,
                                ),
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
                                    AppTheme.shinyGold.withValues(alpha: 0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '✦  ',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.shinyGold.withValues(alpha: 0.7),
            ),
          ),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedIvory,
              letterSpacing: 2.0,
            ),
          ),
          Text(
            '  ✦',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.shinyGold.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordMetric(String label, int val, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          // Icon framed in gold circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF010A07),
              border: Border.all(
                color: AppTheme.shinyGold.withValues(alpha: 0.55),
                width: 1.0,
              ),
            ),
            child: Icon(icon, color: AppTheme.shinyGold, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            val.toString(),
            style: GoogleFonts.lora(
              color: AppTheme.ivoryText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.mutedIvory,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1.2,
      height: 42,
      color: AppTheme.shinyGold.withValues(alpha: 0.25),
    );
  }

  Widget _buildRowDivider() {
    return Divider(
      height: 12,
      thickness: 0.8,
      color: AppTheme.shinyGold.withValues(alpha: 0.15),
    );
  }

  Widget _buildDetailedRecordRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF010A07),
              border: Border.all(
                color: AppTheme.shinyGold.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: Icon(icon, color: AppTheme.shinyGold, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.ivoryText,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.lora(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.shinyGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyVictoryBox(
    String difficulty,
    int winsCount,
    Color bgColor,
    Color badgeColor,
  ) {
    return Column(
      children: [
        // Badge Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            difficulty,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: badgeColor,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Mini wreath around crown
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(72, 72),
                painter: MiniLaurelWreathPainter(
                  color: badgeColor.withValues(alpha: 0.35),
                ),
              ),
              Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF010A07),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: AppTheme.shinyGold,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$winsCount Wins',
          style: GoogleFonts.lora(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.ivoryText,
          ),
        ),
      ],
    );
  }
}

class LaurelWreathPainter extends CustomPainter {
  final bool isLeft;
  final Color color;
  const LaurelWreathPainter({required this.isLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final double w = size.width;
    final double h = size.height;

    final path = Path();
    if (isLeft) {
      // Stem curving from bottom right to top left
      path.moveTo(w * 0.9, h * 0.9);
      path.quadraticBezierTo(w * 0.1, h * 0.75, w * 0.3, h * 0.1);
      canvas.drawPath(path, strokePaint);

      // Draw leaves along the stem
      void drawLeaf(double x, double y, double angleRad) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angleRad);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-4, -6, 0, -12)
          ..quadraticBezierTo(4, -6, 0, 0)
          ..close();
        canvas.drawPath(leaf, paint);
        canvas.restore();
      }

      drawLeaf(w * 0.8, h * 0.82, -0.6);
      drawLeaf(w * 0.55, h * 0.70, -0.9);
      drawLeaf(w * 0.38, h * 0.55, -1.2);
      drawLeaf(w * 0.28, h * 0.38, -1.4);
      drawLeaf(w * 0.26, h * 0.20, -1.6);
    } else {
      // Stem curving from bottom left to top right
      path.moveTo(w * 0.1, h * 0.9);
      path.quadraticBezierTo(w * 0.9, h * 0.75, w * 0.7, h * 0.1);
      canvas.drawPath(path, strokePaint);

      // Draw leaves
      void drawLeaf(double x, double y, double angleRad) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angleRad);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-4, -6, 0, -12)
          ..quadraticBezierTo(4, -6, 0, 0)
          ..close();
        canvas.drawPath(leaf, paint);
        canvas.restore();
      }

      drawLeaf(w * 0.2, h * 0.82, 0.6);
      drawLeaf(w * 0.45, h * 0.70, 0.9);
      drawLeaf(w * 0.62, h * 0.55, 1.2);
      drawLeaf(w * 0.72, h * 0.38, 1.4);
      drawLeaf(w * 0.74, h * 0.20, 1.6);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MiniLaurelWreathPainter extends CustomPainter {
  final Color color;
  const MiniLaurelWreathPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double w = size.width;
    final double h = size.height;

    // Draw left stem
    final pathLeft = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..quadraticBezierTo(w * 0.05, h * 0.72, w * 0.12, h * 0.18);
    canvas.drawPath(pathLeft, strokePaint);

    // Draw right stem
    final pathRight = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..quadraticBezierTo(w * 0.95, h * 0.72, w * 0.88, h * 0.18);
    canvas.drawPath(pathRight, strokePaint);

    // Draw leaves along the stems
    void drawLeaf(double x, double y, double angleRad) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angleRad);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-2.5, -4, 0, -8)
        ..quadraticBezierTo(2.5, -4, 0, 0)
        ..close();
      canvas.drawPath(leaf, paint);
      canvas.restore();
    }

    // Left leaves
    drawLeaf(w * 0.38, h * 0.82, -0.6);
    drawLeaf(w * 0.23, h * 0.72, -0.9);
    drawLeaf(w * 0.14, h * 0.58, -1.2);
    drawLeaf(w * 0.12, h * 0.40, -1.4);
    drawLeaf(w * 0.16, h * 0.24, -1.6);

    // Right leaves
    drawLeaf(w * 0.62, h * 0.82, 0.6);
    drawLeaf(w * 0.77, h * 0.72, 0.9);
    drawLeaf(w * 0.86, h * 0.58, 1.2);
    drawLeaf(w * 0.88, h * 0.40, 1.4);
    drawLeaf(w * 0.84, h * 0.24, 1.6);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
