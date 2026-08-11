import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../core/music_manager.dart';
import '../game/game_notifier.dart';
import '../game/game_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';
import '../how_to_play/how_to_play_screen.dart';
import '../about/about_screen.dart';
import '../multiplayer/multiplayer_lobby_screen.dart';
import '../auth/auth_service.dart';
import '../auth/save_progress_modal.dart';
import '../profile/profile_screen.dart';
import '../daily/daily_challenge_screen.dart';
import '../daily/daily_rewards_service.dart';
import '../achievements/achievements_screen.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../word_of_the_day/word_of_the_day_service.dart';
import '../ranked/ranked_matchmaking_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _canContinue = false;
  bool _checkingSave = true;

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
    // Ensure menu music plays whenever we return to HomeScreen
    MusicManager.instance.setTrack(MusicTrack.menu);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DailyRewardsService.checkAndShowDailyReward(context, ref);
    });
  }

  Future<void> _checkSavedGame() async {
    final hasSave = await ref.read(gameProvider.notifier).hasSavedGame();
    if (mounted) {
      setState(() {
        _canContinue = hasSave;
        _checkingSave = false;
      });
    }
  }

  void _showDifficultyDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF021710),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppTheme.shinyGold, width: 1.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Title and Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32), // spacer to center title
                // Title
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
                          'Select Difficulty',
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
                // Circular Close Button
                InkWell(
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
              ],
            ),
            const SizedBox(height: 4),
            // Subtitle
            Center(
              child: Text(
                'Choose your challenge level',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.mutedIvory,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Easy option
            _buildDifficultyOptionCard(
              title: 'Easy',
              desc: 'Casual and forgiving',
              iconData: Icons.spa_rounded,
              customIcon: null,
              diffValue: 'easy',
            ),
            const SizedBox(height: 12),
            // Medium option
            _buildDifficultyOptionCard(
              title: 'Medium',
              desc: 'Balanced and competitive',
              iconData: Icons.balance_rounded,
              customIcon: null,
              diffValue: 'medium',
            ),
            const SizedBox(height: 12),
            // Hard option
            _buildDifficultyOptionCard(
              title: 'Hard',
              desc: 'Strategic and challenging',
              iconData: null,
              customIcon: const CustomPaint(
                size: Size(20, 20),
                painter: ChessKnightPainter(color: AppTheme.shinyGold),
              ),
              diffValue: 'hard',
            ),
            const SizedBox(height: 24),
            // Decorative Diamond Divider
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
                          AppTheme.shinyGold.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).then((_) => _checkSavedGame()); // Re-check if game is in progress now
  }

  Widget _buildDifficultyOptionCard({
    required String title,
    required String desc,
    required IconData? iconData,
    required Widget? customIcon,
    required String diffValue,
  }) {
    return Container(
      height: 72,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              bottom: -20,
              width: 120,
              child: Opacity(
                opacity: 0.04,
                child: CustomPaint(
                  painter: GoldMotifPainter(color: AppTheme.shinyGold),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(gameProvider.notifier).startNewGame(diffValue);
                  // Switch to calm game-screen kalimba music (non-blocking)
                  MusicManager.instance.setTrack(MusicTrack.game);
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => const GameScreen(),
                        ),
                      )
                      .then((_) {
                        // Back on home — restore menu music (non-blocking)
                        MusicManager.instance.setTrack(MusicTrack.menu);
                        _checkSavedGame();
                      });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Left circular icon frame
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF010A07),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.65),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child:
                              customIcon ??
                              Icon(
                                iconData,
                                color: AppTheme.shinyGold,
                                size: 18,
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Text Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.lora(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ivoryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.mutedIvory,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chevron
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: AppTheme.shinyGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 28.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header Bar (Guest Save icon or Profile Entry)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Consumer(
                        builder: (context, ref, child) {
                          final profile = ref.watch(authProvider);
                          if (profile.isGuest) {
                            return IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF07281D),
                                  border: Border.all(
                                    color: AppTheme.shinyGold.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: AppTheme.shinyGold,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => SaveProgressModal.show(context),
                            );
                          } else {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.panelDark,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.shinyGold.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person_rounded,
                                      color: AppTheme.shinyGold,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '@${profile.username}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.ivoryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Logo & Branding
                  Center(
                    child: Column(
                      children: [
                        // Luxury Logo Container
                        Container(
                          width: 135,
                          height: 135,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.65),
                                offset: const Offset(0, 10),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // App Title with Gold Gradient
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFF1CC), // light shiny gold highlight
                              Color(0xFFD4AF37), // rich gold
                              Color(0xFF8A640F), // antique bronze gold shadow
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: Text(
                            'LetterLoom',
                            style: GoogleFonts.lora(
                              fontSize: 50,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  offset: const Offset(0, 3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Subtitle with Gold Ornaments
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '→',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.shinyGold,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              'Solo Offline • Online Play',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.mutedIvory,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(
                              width: 20,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '←',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.shinyGold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Menu cards arranged two per row for quicker scanning.
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    children: [
                      _buildPremiumButton(
                        title: 'New Game',
                        subtitle: 'Start a new word challenge',
                        iconData: null,
                        isPrimary: true,
                        onPressed: _showDifficultyDialog,
                      ),
                      if (!_checkingSave)
                        _buildPremiumButton(
                          title: 'Continue Game',
                          subtitle: 'Resume your last match',
                          iconData: Icons.history_rounded,
                          isPrimary: false,
                          onPressed: _canContinue
                              ? () async {
                                  await ref
                                      .read(gameProvider.notifier)
                                      .loadSavedGame();
                                  MusicManager.instance.setTrack(
                                    MusicTrack.game,
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context)
                                        .push(
                                          MaterialPageRoute(
                                            builder: (_) => const GameScreen(),
                                          ),
                                        )
                                        .then((_) {
                                          MusicManager.instance.setTrack(
                                            MusicTrack.menu,
                                          );
                                          _checkSavedGame();
                                        });
                                  }
                                }
                              : null,
                        ),
                      _buildPremiumButton(
                        title: 'Daily Challenge',
                        subtitle: 'Today\'s puzzle',
                        iconData: Icons.today_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DailyChallengeScreen(),
                          ),
                        ),
                      ),
                      _buildPremiumButton(
                        title: 'Ranked 1v1',
                        subtitle: 'Compete in rating divisions',
                        iconData: Icons.sports_esports_rounded,
                        isPrimary: false,
                        onPressed: () =>
                            RankedMatchmakingService.startRankedMatchmaking(
                              context,
                              ref,
                            ),
                      ),
                      _buildPremiumButton(
                        title: 'Play Online',
                        subtitle: 'Casual room with friends',
                        iconData: Icons.groups_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MultiplayerLobbyScreen(),
                          ),
                        ),
                      ),
                      _buildPremiumButton(
                        title: 'Leaderboards',
                        subtitle: 'Global rankings & high scores',
                        iconData: Icons.leaderboard_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardsScreen(),
                          ),
                        ),
                      ),
                      _buildPremiumButton(
                        title: 'Achievements',
                        subtitle: 'View unlocks & progress',
                        iconData: Icons.workspace_premium_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AchievementsScreen(),
                          ),
                        ),
                      ),
                      _buildPremiumButton(
                        title: 'Word of the Day',
                        subtitle: 'Expand your Loom lexicon',
                        iconData: Icons.auto_stories_rounded,
                        isPrimary: false,
                        onPressed: () => WordOfTheDayService.showModal(context),
                      ),
                      _buildPremiumButton(
                        title: 'How to Play',
                        subtitle: 'Learn the rules & scoring',
                        iconData: Icons.menu_book_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HowToPlayScreen(),
                          ),
                        ),
                      ),
                      _buildPremiumButton(
                        title: 'Statistics',
                        subtitle: 'View your records & progress',
                        iconData: Icons.bar_chart_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StatisticsScreen(),
                          ),
                        ),
                      ),
                      _buildPremiumButton(
                        title: 'Settings',
                        subtitle: 'Customize your experience',
                        iconData: Icons.settings_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                      _buildPremiumButton(
                        title: 'About the Loom',
                        subtitle: 'Our story, lexicon, & credits',
                        iconData: Icons.info_outline_rounded,
                        isPrimary: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Divider & Footer Line (No Copyright text)
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumButton({
    required String title,
    required String subtitle,
    required IconData? iconData,
    required bool isPrimary,
    required VoidCallback? onPressed,
  }) {
    final bool disabled = onPressed == null;

    final Color textPrimaryColor = isPrimary
        ? const Color(0xFF1E1402)
        : AppTheme.ivoryText;
    final Color textSecondaryColor = isPrimary
        ? const Color(0xFF4E3705)
        : const Color(0xFF8AA59B);

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPrimary && !disabled
              ? [
                  BoxShadow(
                    color: AppTheme.shinyGold.withValues(alpha: 0.35),
                    offset: const Offset(0, 6),
                    blurRadius: 14,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
          border: !isPrimary
              ? Border.all(
                  color: AppTheme.shinyGold.withValues(alpha: 0.55),
                  width: 1.2,
                )
              : null,
          gradient: LinearGradient(
            colors: isPrimary
                ? AppTheme.goldGradient
                : AppTheme.darkGreenGradient,
            begin: isPrimary ? Alignment.topLeft : Alignment.topCenter,
            end: isPrimary ? Alignment.bottomRight : Alignment.bottomCenter,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Lattice Pattern Overlay on the right
              Positioned(
                right: -20,
                top: -20,
                bottom: -20,
                width: 120,
                child: Opacity(
                  opacity: isPrimary ? 0.08 : 0.04,
                  child: CustomPaint(
                    painter: GoldMotifPainter(
                      color: isPrimary ? Colors.black : AppTheme.shinyGold,
                    ),
                  ),
                ),
              ),
              // Main content layout
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isPrimary
                                      ? const Color(0xFF031A12)
                                      : const Color(0xFF010A07),
                                  border: Border.all(
                                    color: isPrimary
                                        ? AppTheme.shinyGold.withValues(
                                            alpha: 0.2,
                                          )
                                        : AppTheme.shinyGold.withValues(
                                            alpha: 0.65,
                                          ),
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: isPrimary
                                      ? const CustomPaint(
                                          size: Size(22, 22),
                                          painter: ChessKnightPainter(
                                            color: AppTheme.shinyGold,
                                          ),
                                        )
                                      : Icon(
                                          iconData,
                                          color: AppTheme.shinyGold,
                                          size: 17,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChessKnightPainter extends CustomPainter {
  final Color color;
  const ChessKnightPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final double w = size.width;
    final double h = size.height;

    path.moveTo(w * 0.28, h * 0.85);
    path.lineTo(w * 0.72, h * 0.85);
    path.lineTo(w * 0.70, h * 0.76);
    path.quadraticBezierTo(w * 0.72, h * 0.65, w * 0.68, h * 0.58);
    path.cubicTo(w * 0.82, h * 0.44, w * 0.82, h * 0.22, w * 0.68, h * 0.12);
    path.quadraticBezierTo(w * 0.60, h * 0.05, w * 0.52, h * 0.08);
    path.lineTo(w * 0.48, h * 0.16);
    path.quadraticBezierTo(w * 0.40, h * 0.12, w * 0.34, h * 0.18);
    path.cubicTo(w * 0.22, h * 0.22, w * 0.16, h * 0.35, w * 0.18, h * 0.46);
    path.quadraticBezierTo(w * 0.24, h * 0.52, w * 0.30, h * 0.48);
    path.quadraticBezierTo(w * 0.36, h * 0.58, w * 0.32, h * 0.72);
    path.quadraticBezierTo(w * 0.28, h * 0.78, w * 0.28, h * 0.85);
    path.close();

    canvas.drawPath(path, paint);

    // Eye
    final eyePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.42, h * 0.28), w * 0.045, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoldMotifPainter extends CustomPainter {
  final Color color;
  const GoldMotifPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final double w = size.width;
    final double h = size.height;

    final path = Path();
    for (double i = -h; i < w; i += 12) {
      path.moveTo(i, 0);
      path.lineTo(i + h, h);
    }
    for (double i = 0; i < w + h; i += 12) {
      path.moveTo(i, 0);
      path.lineTo(i - h, h);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
