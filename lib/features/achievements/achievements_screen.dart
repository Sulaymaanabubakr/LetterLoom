import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/achievement.dart';
import 'achievements_service.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldDark,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PremiumPageHeader(title: 'Achievements'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Summary Header Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.panelDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: AppTheme.shinyGold,
                              size: 36,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unlocked $unlockedCount of ${achievements.length}',
                                    style: GoogleFonts.lora(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.ivoryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: achievements.isNotEmpty
                                          ? unlockedCount / achievements.length
                                          : 0.0,
                                      minHeight: 8,
                                      backgroundColor: const Color(0xFF021710),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppTheme.shinyGold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // List of Achievements
                      Expanded(
                        child: ListView.separated(
                          itemCount: achievements.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildAchievementCard(achievements[index]),
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
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final double fraction = (achievement.currentValue / achievement.targetValue)
        .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: achievement.isUnlocked
            ? const Color(0xFF07281D)
            : const Color(0xFF02130E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: achievement.isUnlocked
              ? AppTheme.shinyGold
              : AppTheme.shinyGold.withValues(alpha: 0.25),
          width: achievement.isUnlocked ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: achievement.isUnlocked
                  ? AppTheme.shinyGold.withValues(alpha: 0.2)
                  : Colors.black26,
              border: Border.all(
                color: achievement.isUnlocked
                    ? AppTheme.shinyGold
                    : Colors.white12,
              ),
            ),
            child: Center(
              child: Text(
                achievement.iconName,
                style: TextStyle(
                  fontSize: 24,
                  color: achievement.isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Content Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: GoogleFonts.lora(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: achievement.isUnlocked
                              ? AppTheme.ivoryText
                              : AppTheme.mutedIvory,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.shinyGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.shinyGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '+${achievement.xpReward} level progress',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.mutedIvory.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                if (!achievement.isUnlocked && achievement.targetValue > 1) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 5,
                            backgroundColor: Colors.black45,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.emeraldGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${achievement.currentValue}/${achievement.targetValue}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.mutedIvory,
                        ),
                      ),
                    ],
                  ),
                ] else if (achievement.isUnlocked) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppTheme.shinyGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Unlocked',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
