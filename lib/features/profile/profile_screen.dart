import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart';
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

  void _showEditUsernameDialog(PlayerProfile profile) {
    final screenContext = context;
    final controller = TextEditingController(text: profile.username);
    int availabilityRequest = 0;
    Timer? availabilityDebounce;
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) {
        String? errorMessage;
        bool? isAvailable;
        bool isChecking = false;
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PremiumDialog(
              title: 'Change Username',
              actions: [
                Expanded(
                  child: TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('CANCEL'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.shinyGold,
                      foregroundColor: const Color(0xFF1E1402),
                    ),
                    onPressed: isSaving || isChecking
                        ? null
                        : () async {
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
                            setDialogState(() => isSaving = true);
                            final available = await ref
                                .read(authProvider.notifier)
                                .isUsernameAvailable(newUsername);
                            if (!context.mounted) return;
                            if (available != true) {
                              setDialogState(() {
                                isSaving = false;
                                isAvailable = available;
                                errorMessage = available == false
                                    ? 'That username is already taken.'
                                    : 'Could not check availability. Try again.';
                              });
                              return;
                            }

                            final updated = profile.copyWith(
                              username: newUsername,
                            );
                            final saved = await ref
                                .read(authProvider.notifier)
                                .updateProfile(updated);
                            if (context.mounted && saved) {
                              Navigator.of(dialogContext).pop();
                              if (screenContext.mounted) {
                                ToastUtils.showToast(
                                  screenContext,
                                  'Username updated to @$newUsername',
                                );
                              }
                            } else if (context.mounted) {
                              setDialogState(() {
                                isSaving = false;
                                errorMessage =
                                    'That username is unavailable. Please choose another.';
                              });
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1E1402),
                            ),
                          )
                        : const Text('SAVE'),
                  ),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    style: GoogleFonts.inter(color: AppTheme.ivoryText),
                    onChanged: (value) async {
                      final validation = UsernameGenerator.validate(value);
                      final request = ++availabilityRequest;
                      if (!validation.isValid) {
                        setDialogState(() {
                          errorMessage = validation.errorMessage;
                          isAvailable = null;
                          isChecking = false;
                        });
                        return;
                      }

                      setDialogState(() {
                        errorMessage = null;
                        isChecking = true;
                      });
                      availabilityDebounce?.cancel();
                      availabilityDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () async {
                          final available = await ref
                              .read(authProvider.notifier)
                              .isUsernameAvailable(value);
                          if (!context.mounted ||
                              request != availabilityRequest) {
                            return;
                          }
                          setDialogState(() {
                            isChecking = false;
                            isAvailable = available;
                            errorMessage = available == false
                                ? 'That username is already taken.'
                                : available == null
                                ? 'Could not check availability. Try again.'
                                : null;
                          });
                        },
                      );
                    },
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
                  if (isChecking) ...[
                    const SizedBox(height: 10),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.shinyGold,
                      ),
                    ),
                  ] else if (isAvailable == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Username is available.',
                      style: GoogleFonts.inter(
                        color: AppTheme.emeraldGreen,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAvatarPicker(PlayerProfile profile) {
    final screenContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panelDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
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
                      final saved = await ref
                          .read(authProvider.notifier)
                          .updateProfile(updated);
                      if (!sheetContext.mounted) return;
                      if (!saved) {
                        ToastUtils.showToast(
                          sheetContext,
                          'Could not save your avatar. Please try again.',
                          isError: true,
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      if (screenContext.mounted) {
                        ToastUtils.showToast(
                          screenContext,
                          '${avatar['name']} selected.',
                        );
                      }
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
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      showSearch: true,
      favorite: const ['NG', 'US', 'GB', 'CA'],
      countryListTheme: CountryListThemeData(
        backgroundColor: AppTheme.panelDark,
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.74,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        textStyle: GoogleFonts.inter(color: AppTheme.ivoryText),
        searchTextStyle: GoogleFonts.inter(color: AppTheme.ivoryText),
        inputDecoration: InputDecoration(
          hintText: 'Search every country',
          hintStyle: GoogleFonts.inter(color: AppTheme.mutedIvory),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.shinyGold,
          ),
          filled: true,
          fillColor: const Color(0xFF021710),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppTheme.shinyGold.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
      onSelect: (country) async {
        final updated = profile.copyWith(countryCode: country.countryCode);
        final saved = await ref
            .read(authProvider.notifier)
            .updateProfile(updated);
        if (!mounted) return;
        ToastUtils.showToast(
          context,
          saved
              ? '${country.displayName} selected.'
              : 'Could not save country. Please try again.',
          isError: !saved,
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

    final countryData = Country.tryParse(profile.countryCode);

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
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'YOUR PLAYER IDENTITY',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Header Card
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF174B37), Color(0xFF061A13)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.emeraldGreen.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.42),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                InkWell(
                                  onTap: () => _showAvatarPicker(profile),
                                  borderRadius: BorderRadius.circular(44),
                                  child: Container(
                                    width: 82,
                                    height: 82,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF021710),
                                      border: Border.all(
                                        color: AppTheme.shinyGold,
                                        width: 2.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.shinyGold.withValues(
                                            alpha: 0.18,
                                          ),
                                          blurRadius: 18,
                                        ),
                                      ],
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
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 27,
                                    height: 27,
                                    decoration: BoxDecoration(
                                      color: AppTheme.shinyGold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF123B2C),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile.displayName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lora(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ivoryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 28,
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    '@${profile.username}',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppTheme.shinyGold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      tooltip: 'Change username',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 15,
                                        color: AppTheme.shinyGold,
                                      ),
                                      onPressed: () {
                                        if (profile.isGuest) {
                                          SaveProgressModal.show(context);
                                          return;
                                        }
                                        _showEditUsernameDialog(profile);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _showCountryPicker(profile),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      countryData?.flagEmoji ?? '🌍',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        countryData?.displayNameNoCountryCode ??
                                            'Select country',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: AppTheme.mutedIvory,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppTheme.mutedIvory,
                                      size: 17,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF031A12,
                                ).withValues(alpha: 0.66),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.shinyGold.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.shinyGold,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'LEVEL ${profile.level}',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF1E1402),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${profile.xp - currentLevelXP} / $range XP',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppTheme.mutedIvory,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progressFraction,
                                      minHeight: 8,
                                      backgroundColor: const Color(0xFF010E0A),
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
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      // Competitive Statistics Grid
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Competitive Stats',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lora(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.ivoryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.18,
                        mainAxisSpacing: 8,
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
                      const SizedBox(height: 12),
                      // Sign Out Button (if authenticated)
                      if (!profile.isGuest)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 11),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF103325), Color(0xFF071E16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.shinyGold),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.mutedIvory,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.ivoryText,
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
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
