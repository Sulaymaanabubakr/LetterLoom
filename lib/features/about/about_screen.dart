import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                          onTap: () => Navigator.of(context).pop(),
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
                                  'About the Loom',
                                  style: GoogleFonts.lora(
                                    fontSize: 24,
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
                      ),
                    ],
                  ),
                ),
              ),
              // Thin Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.shinyGold.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    children: [
                      // Section 1: The Tale
                      _buildInfoSection(
                        icon: Icons.history_edu_rounded,
                        title: "The Loom's Tale",
                        content:
                            "LetterLoom is a premium word game for thoughtful solo play and distant multiplayer matches. Play offline against a clever computer opponent, or create an online room and challenge someone wherever they are. Thread letters together, craft high-scoring words, and make every move count.",
                      ),
                      const SizedBox(height: 16),
                      // Section 2: The Lexicon
                      _buildInfoSection(
                        icon: Icons.menu_book_rounded,
                        title: "The Lexicon",
                        content:
                            "Powered by the ENABLE1 (Enhanced North American Benchmark LExicon) word list. This lexicon contains over 173,000 words and is bundled in LetterLoom, so word checking remains available during solo play without a network connection.",
                      ),
                      const SizedBox(height: 16),
                      // Section 3: Soundscapes
                      _buildInfoSection(
                        icon: Icons.music_note_rounded,
                        title: "Harmonic Soundscapes",
                        content:
                            "Relaxing, high-quality audio files curated to aid focus and strategy:\n\n"
                            "• General Screens: \"Midsummer Sky\" (Kevin MacLeod)\n\n"
                            "• Game & Daily Challenge: \"Sapphire Isle\" (Kevin MacLeod)\n\n"
                            "Both tracks are licensed under the Creative Commons Attribution 4.0 License. Special thanks to Kevin MacLeod (incompetech.com) for making these beautiful works available for commercial use.",
                      ),
                      const SizedBox(height: 36),
                      // App Logo Container
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.65),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Version info
                      Text(
                        'LetterLoom Premium',
                        style: GoogleFonts.lora(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0 • Handcrafted by Sulaymaan Abubakr',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.mutedIvory.withValues(alpha: 0.7),
                        ),
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

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.shinyGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        gradient: const LinearGradient(
          colors: AppTheme.darkGreenGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.shinyGold, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppTheme.mutedIvory,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
