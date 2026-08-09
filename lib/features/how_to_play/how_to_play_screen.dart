import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Bar with Back Button & Ornate Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: SizedBox(
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Custom Gold-Bordered Back Button
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
                                  'How to Play',
                                  style: GoogleFonts.lora(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
              const SizedBox(height: 16),
              // Main content scroll area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card: Rules Summary & Gold Medal
                      _buildPremiumCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Custom Emblem LPainter Container
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF031A12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.shinyGold.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  const Positioned.fill(
                                    child: CustomPaint(
                                      painter: EmblemLPainter(color: AppTheme.shinyGold),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      'L',
                                      style: GoogleFonts.lora(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.shinyGold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'The Rules of LetterLoom',
                                    style: GoogleFonts.lora(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.shinyGold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'LetterLoom is a word game where two players compete by forming words on a 15×15 grid using letter tiles from a rack of seven. Each word placed must be verified against the local offline English dictionary.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: AppTheme.mutedIvory,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Card 1: Board Placement
                      _buildPremiumCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mini Grid Painter
                            Container(
                              width: 76,
                              height: 76,
                              decoration: const BoxDecoration(
                                color: Color(0xFF031A12),
                              ),
                              child: const CustomPaint(
                                painter: MiniBoardPainter(
                                  gridColor: Color(0xFF0C382A),
                                  accentColor: AppTheme.shinyGold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCardTitle('1', 'Board Placement'),
                                  const SizedBox(height: 12),
                                  _buildBulletItem(
                                    'First Word: ',
                                    'The first word submitted must cross the golden centre star cell (7, 7).',
                                  ),
                                  _buildBulletItem(
                                    'Alignment: ',
                                    'All tiles placed in a turn must be aligned in a single row or column (no diagonals).',
                                  ),
                                  _buildBulletItem(
                                    'Contiguity: ',
                                    'There must be no empty grid cells between the tiles placed in that straight line.',
                                  ),
                                  _buildBulletItem(
                                    'Connectivity: ',
                                    'After the first turn, every new word must connect to at least one tile already locked on the board.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Card 2: Premium Spaces
                      _buildPremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCardTitle('2', 'Premium Spaces'),
                            const SizedBox(height: 8),
                            Text(
                              'Multipliers only apply when a tile is first placed on the cell. Locked tiles on subsequent turns do not trigger the multiplier again.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.4,
                                color: AppTheme.mutedIvory,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // DL, TL, DW, TW horizontal legend Wrap
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                _buildPremiumSpaceLegend('DL', 'Double Letter', AppTheme.doubleLetterColor),
                                _buildPremiumSpaceLegend('TL', 'Triple Letter', AppTheme.tripleLetterColor),
                                _buildPremiumSpaceLegend('DW', 'Double Word\n(including Center Star)', AppTheme.doubleWordColor),
                                _buildPremiumSpaceLegend('TW', 'Triple Word', AppTheme.tripleWordColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Card 3: Word Scoring & Bingo
                      _buildPremiumCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Gift Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF031A12),
                                border: Border.all(
                                  color: AppTheme.shinyGold.withValues(alpha: 0.45),
                                  width: 1.2,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.card_giftcard_rounded,
                                  color: AppTheme.shinyGold,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCardTitle('3', 'Word Scoring & Bingo'),
                                  const SizedBox(height: 12),
                                  _buildBulletItem(
                                    'Letter points ',
                                    'are summed and multiplied by premium letters, then the total word score is multiplied by premium word tiles.',
                                  ),
                                  _buildBulletItem(
                                    'Bingo Bonus: ',
                                    'Using all 7 tiles from your rack in a single turn awards a 50-point bonus.',
                                  ),
                                  _buildBulletItem(
                                    'Blank Tiles: ',
                                    'Blank tiles score 0 points. When you place a blank, you must select the letter it represents.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Card 4: Tile Exchanges & Passes
                      _buildPremiumCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Exchange Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF031A12),
                                border: Border.all(
                                  color: AppTheme.shinyGold.withValues(alpha: 0.45),
                                  width: 1.2,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.sync_rounded,
                                  color: AppTheme.shinyGold,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCardTitle('4', 'Tile Exchanges & Passes'),
                                  const SizedBox(height: 12),
                                  _buildBulletItem(
                                    'Exchange: ',
                                    'You can exchange any number of rack tiles back into the bag. Note: exchanges are only allowed if there are at least 7 tiles remaining in the bag.',
                                  ),
                                  _buildBulletItem(
                                    'Pass: ',
                                    'You can pass your turn at any time.',
                                  ),
                                  _buildBulletItem(
                                    'Endgame Passes: ',
                                    'The game ends automatically if there are six consecutive passes.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tip Footer Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.45), width: 1.2),
                          gradient: const LinearGradient(
                            colors: AppTheme.darkGreenGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Row(
                          children: [
                            Transform.rotate(
                              angle: 3.14159 / 4,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldGreen,
                                  border: Border.all(color: AppTheme.shinyGold, width: 1.2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Tip: Plan ahead, use premium spaces wisely, and keep your rack flexible. The best words are woven with strategy.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.mutedIvory,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
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

  Widget _buildPremiumCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.45), width: 1.2),
        gradient: const LinearGradient(
          colors: AppTheme.darkGreenGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }

  Widget _buildCardTitle(String number, String title) {
    return Row(
      children: [
        // Number Badge
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF010A07),
            border: Border.all(color: AppTheme.shinyGold, width: 1.2),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.lora(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.shinyGold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Title Text
        Text(
          title,
          style: GoogleFonts.lora(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.shinyGold,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(String prefix, String suffix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.shinyGold,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: prefix,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ivoryText,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: suffix,
                    style: GoogleFonts.inter(
                      color: AppTheme.mutedIvory,
                      fontSize: 13,
                      height: 1.4,
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

  Widget _buildPremiumSpaceLegend(String abbrev, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          child: Center(
            child: Text(
              abbrev,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.mutedIvory,
          ),
        ),
      ],
    );
  }
}

class EmblemLPainter extends CustomPainter {
  final Color color;
  const EmblemLPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Draw main circle border
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Inner details concentric circles
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(Offset(cx, cy), r - 4, innerPaint);
    canvas.drawCircle(Offset(cx, cy), r - 8, innerPaint);

    // Draw diamond style accents at cardinal points
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy - r + 6), 2.0, dotPaint);
    canvas.drawCircle(Offset(cx, cy + r - 6), 2.0, dotPaint);
    canvas.drawCircle(Offset(cx - r + 6, cy), 2.0, dotPaint);
    canvas.drawCircle(Offset(cx + r - 6, cy), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MiniBoardPainter extends CustomPainter {
  final Color gridColor;
  final Color accentColor;
  const MiniBoardPainter({required this.gridColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cellW = w / 5;
    final double cellH = h / 5;

    final linePaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Outer border
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(8)),
      borderPaint,
    );

    // Grid lines
    for (int i = 1; i < 5; i++) {
      canvas.drawLine(Offset(i * cellW, 0), Offset(i * cellW, h), linePaint);
      canvas.drawLine(Offset(0, i * cellH), Offset(w, i * cellH), linePaint);
    }

    // Corner "X" marks
    final xPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    void drawX(int row, int col) {
      final double left = col * cellW + 3;
      final double top = row * cellH + 3;
      final double right = (col + 1) * cellW - 3;
      final double bottom = (row + 1) * cellH - 3;
      canvas.drawLine(Offset(left, top), Offset(right, bottom), xPaint);
      canvas.drawLine(Offset(right, top), Offset(left, bottom), xPaint);
    }
    drawX(0, 0);
    drawX(0, 4);
    drawX(4, 0);
    drawX(4, 4);

    // Center gold star
    final starPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    final double cx = 2 * cellW + cellW / 2;
    final double cy = 2 * cellH + cellH / 2;

    final path = Path();
    const int points = 5;
    const double outerRadius = 5.5;
    const double innerRadius = 2.2;
    for (int i = 0; i < points * 2; i++) {
      final double angle = i * 3.14159 / points - 3.14159 / 2;
      final double r = i.isEven ? outerRadius : innerRadius;
      final double x = cx + r * cos(angle);
      final double y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, starPaint);

    // Mini green arrow pointing towards center in cell (1, 0)
    final arrowPaint = Paint()
      ..color = AppTheme.emeraldGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final double ax = cellW / 2;
    final double ay = cellH + cellH / 2;
    canvas.drawLine(Offset(ax - 2, ay), Offset(ax + 3, ay), arrowPaint);
    canvas.drawLine(Offset(ax + 3, ay), Offset(ax, ay - 3), arrowPaint);
    canvas.drawLine(Offset(ax + 3, ay), Offset(ax, ay + 3), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
