import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/player_profile.dart';
import '../../core/app_config.dart';
import '../../core/toast_utils.dart';
import '../auth/auth_service.dart';
import '../auth/save_progress_modal.dart';
import 'username_generator.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const List<Map<String, String>> builtInAvatars = [
    {'id': 'avatar_owl', 'name': 'Wise Owl', 'icon': '🦉'},
    {'id': 'avatar_knight', 'name': 'Loom Knight', 'icon': '⚔️'},
    {'id': 'avatar_crown', 'name': 'Royal Crown', 'icon': '👑'},
    {'id': 'avatar_falcon', 'name': 'Swift Falcon', 'icon': '🦅'},
    {'id': 'avatar_dragon', 'name': 'Mythic Dragon', 'icon': '🐉'},
    {'id': 'avatar_wizard', 'name': 'Word Mage', 'icon': '🧙‍♂️'},
    {'id': 'avatar_lion', 'name': 'Golden Lion', 'icon': '🦁'},
    {'id': 'avatar_panther', 'name': 'Shadow Lynx', 'icon': '🐆'},
  ];

  static const List<Map<String, String>> countryList = [
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': 'AU', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': 'NG', 'name': 'Nigeria', 'flag': '🇳🇬'},
    {'code': 'DE', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': 'FR', 'name': 'France', 'flag': '🇫🇷'},
    {'code': 'IN', 'name': 'India', 'flag': '🇮🇳'},
    {'code': 'JP', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': 'BR', 'name': 'Brazil', 'flag': '🇧🇷'},
  ];

  void _showEditUsernameDialog(PlayerProfile profile) {
    final controller = TextEditingController(text: profile.username);
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PremiumDialog(
              title: 'Change Username',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    style: GoogleFonts.inter(color: AppTheme.ivoryText),
                    decoration: InputDecoration(
                      prefixText: '@',
                      prefixStyle: const TextStyle(color: AppTheme.shinyGold),
                      hintText: 'Enter unique username',
                      hintStyle: TextStyle(
                        color: AppTheme.mutedIvory.withValues(alpha: 0.5),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.shinyGold),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppTheme.shinyGold,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.shinyGold,
                      foregroundColor: const Color(0xFF1E1402),
                    ),
                    onPressed: () async {
                      final validation = UsernameGenerator.validate(
                        controller.text,
                      );
                      if (!validation.isValid) {
                        setDialogState(() {
                          errorMessage = validation.errorMessage;
                        });
                        return;
                      }

                      final newUsername = UsernameGenerator.normalize(
                        controller.text,
                      );
                      final updated = profile.copyWith(username: newUsername);
                      final saved = await ref
                          .read(authProvider.notifier)
                          .updateProfile(updated);
                      if (context.mounted && saved) {
                        Navigator.of(context).pop();
                        ToastUtils.showToast(
                          context,
                          'Username updated to @$newUsername',
                        );
                      } else if (context.mounted) {
                        setDialogState(() {
                          errorMessage =
                              'That username is unavailable. Please choose another.';
                        });
                      }
                    },
                    child: const Text('SAVE'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAvatarPicker(PlayerProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panelDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Your Avatar',
                style: GoogleFonts.lora(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ivoryText,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                itemCount: builtInAvatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final avatar = builtInAvatars[index];
                  final isSelected = profile.avatarId == avatar['id'];
                  return InkWell(
                    onTap: () async {
                      final updated = profile.copyWith(avatarId: avatar['id']);
                      await ref
                          .read(authProvider.notifier)
                          .updateProfile(updated);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF021710),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.shinyGold
                              : Colors.white24,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatar['icon']!,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCountryPicker(PlayerProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panelDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: countryList.length,
          itemBuilder: (context, index) {
            final country = countryList[index];
            final isSelected = profile.countryCode == country['code'];
            return ListTile(
              leading: Text(
                country['flag']!,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(
                country['name']!,
                style: GoogleFonts.inter(color: AppTheme.ivoryText),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppTheme.shinyGold)
                  : null,
              onTap: () async {
                final updated = profile.copyWith(countryCode: country['code']);
                await ref.read(authProvider.notifier).updateProfile(updated);
                if (context.mounted) Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider);
    final avatarData = builtInAvatars.firstWhere(
      (a) => a['id'] == profile.avatarId,
      orElse: () => builtInAvatars.first,
    );

    final countryData = countryList.firstWhere(
      (c) => c['code'] == profile.countryCode,
      orElse: () => countryList.first,
    );

    final currentLevelXP = AppConfig.xpRequiredForLevel(profile.level);
    final nextLevelXP = AppConfig.xpRequiredForLevel(profile.level + 1);
    final range = nextLevelXP - currentLevelXP;
    final progressInLevel = profile.xp - currentLevelXP;
    final double progressFraction = range > 0
        ? (progressInLevel / range).clamp(0.0, 1.0)
        : 1.0;

    final winRate = profile.gamesPlayed > 0
        ? ((profile.wins / profile.gamesPlayed) * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldDark,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PremiumPageHeader(
                title: 'Player Profile',
                action: profile.isGuest
                    ? InkWell(
                        onTap: () => SaveProgressModal.show(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.shinyGold.withValues(alpha: 0.65),
                            ),
                            color: const Color(0xFF010E0A),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            color: AppTheme.shinyGold,
                            size: 18,
                          ),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.panelDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => _showAvatarPicker(profile),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF021710),
                                      border: Border.all(
                                        color: AppTheme.shinyGold,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        avatarData['icon']!,
                                        style: const TextStyle(fontSize: 40),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.shinyGold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              profile.displayName,
                              style: GoogleFonts.lora(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ivoryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '@${profile.username}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.shinyGold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: AppTheme.shinyGold,
                                  ),
                                  onPressed: () =>
                                      _showEditUsernameDialog(profile),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => _showCountryPicker(profile),
                                  child: Row(
                                    children: [
                                      Text(
                                        countryData['flag']!,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        countryData['name']!,
                                        style: GoogleFonts.inter(
                                          color: AppTheme.mutedIvory,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        color: AppTheme.mutedIvory,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Level progress bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Level ${profile.level}',
                                  style: GoogleFonts.lora(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.ivoryText,
                                  ),
                                ),
                                Text(
                                  'Level progress',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.mutedIvory,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progressFraction,
                                minHeight: 10,
                                backgroundColor: const Color(0xFF021710),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.shinyGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Guest Warning Banner (if guest)
                      if (profile.isGuest)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1402),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.shinyGold.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off,
                                color: AppTheme.shinyGold,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Playing as Guest. Connect Google account to keep stats & compete in Ranked!',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.ivoryText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.shinyGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: () =>
                                    SaveProgressModal.show(context),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Competitive Statistics Grid
                      Text(
                        'Competitive Stats',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ivoryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.8,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: [
                          _buildStatTile(
                            'Ranked Rating',
                            '${profile.rankedRating}',
                            AppConfig.getRankedTier(profile.rankedRating),
                            Icons.emoji_events,
                          ),
                          _buildStatTile(
                            'Win Rate',
                            '$winRate%',
                            '${profile.wins} W / ${profile.losses} L',
                            Icons.pie_chart,
                          ),
                          _buildStatTile(
                            'Games Played',
                            '${profile.gamesPlayed}',
                            'Matches finished',
                            Icons.sports_esports,
                          ),
                          _buildStatTile(
                            'Highest Score',
                            '${profile.highestScore}',
                            'Personal best',
                            Icons.military_tech,
                          ),
                          _buildStatTile(
                            'Current Streak',
                            '${profile.currentStreak}',
                            'Wins in a row',
                            Icons.local_fire_department,
                          ),
                          _buildStatTile(
                            'Best Streak',
                            '${profile.bestStreak}',
                            'All-time streak',
                            Icons.workspace_premium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Sign Out Button (if authenticated)
                      if (!profile.isGuest)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          onPressed: () async {
                            await ref.read(authProvider.notifier).signOut();
                            if (context.mounted) {
                              ToastUtils.showToast(
                                context,
                                'Signed out of account.',
                              );
                            }
                          },
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

  Widget _buildStatTile(
    String title,
    String value,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panelDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.shinyGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.mutedIvory,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.ivoryText,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.mutedIvory.withValues(alpha: 0.7),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
