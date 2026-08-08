import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../game_engine/game_config.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'How to Play',
          style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.darkCharcoal),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Rules of LetterLoom',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.forestGreen,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'LetterLoom is a word game where two players (you and the computer) compete by forming words on a 15x15 grid using letter tiles from a rack of seven. Each word placed must be verified against the local offline English dictionary.',
              style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.darkCharcoal),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('1. Board Placements'),
            _buildRuleBullet(
              'First Word: The first word submitted must cross the golden centre star cell (7, 7).',
            ),
            _buildRuleBullet(
              'Alignment: All tiles placed in a turn must be aligned in a single row or column (no diagonals).',
            ),
            _buildRuleBullet(
              'Contiguity: There must be no empty grid cells between the tiles placed in that straight line.',
            ),
            _buildRuleBullet(
              'Connectivity: After the first turn, every new word must connect to at least one tile already locked on the board.',
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('2. Premium Spaces'),
            const Text(
              'Multipliers only apply when a tile is first placed on the cell. Locked tiles on subsequent turns do not trigger the multiplier again.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.darkCharcoal),
            ),
            const SizedBox(height: 12),
            _buildPremiumLegendRow('DL', 'Double Letter', AppTheme.doubleLetterColor),
            _buildPremiumLegendRow('TL', 'Triple Letter', AppTheme.tripleLetterColor),
            _buildPremiumLegendRow('DW', 'Double Word (including Center Star)', AppTheme.doubleWordColor),
            _buildPremiumLegendRow('TW', 'Triple Word', AppTheme.tripleWordColor),
            const SizedBox(height: 24),
            _buildSectionHeader('3. Word Scoring & Bingo'),
            _buildRuleBullet(
              'Letter points are summed and multiplied by premium letters, then the total word score is multiplied by premium word tiles.',
            ),
            _buildRuleBullet(
              'Bingo Bonus: Using all 7 tiles from your rack in a single turn awards a 50-point bonus.',
            ),
            _buildRuleBullet(
              'Blank Tiles: Blank tiles score 0 points. When you place a blank, you must select the letter it represents.',
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('4. Tile Exchanges & Passes'),
            _buildRuleBullet(
              'Exchange: You can exchange any number of rack tiles back into the bag. Note: exchanges are only allowed if there are at least 7 tiles remaining in the bag.',
            ),
            _buildRuleBullet(
              'Pass: You can pass your turn at any time.',
            ),
            _buildRuleBullet(
              'Endgame passes: The game ends automatically if there are six consecutive passes or exchanges in total.',
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('5. Tile Points Map'),
            _buildTilePointsMapGrid(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.forestGreen,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRuleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 10.0),
            child: Icon(Icons.circle, size: 6, color: AppTheme.warmGold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.darkCharcoal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLegendRow(String abbrev, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                abbrev,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.darkCharcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTilePointsMapGrid() {
    final List<Widget> children = [];
    GameConfig.letterScores.forEach((letter, score) {
      if (letter.trim().isEmpty) return; // Skip blank representation in points map
      children.add(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.lightGrey),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                letter,
                style: const TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestGreen,
                ),
              ),
              Text(
                '$score pts',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppTheme.darkCharcoal.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    });

    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: 1.0,
      children: children,
    );
  }
}
