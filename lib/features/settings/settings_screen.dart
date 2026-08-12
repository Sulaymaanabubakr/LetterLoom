import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../game/game_notifier.dart';
import '../../core/haptic_utils.dart';
import '../../core/toast_utils.dart';
import '../../core/push_notification_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showResetConfirmDialog(BuildContext context, WidgetRef ref) {
    showPremiumConfirmationSheet(
      context,
      title: 'Reset Statistics?',
      message:
          'This will permanently delete all records of games, wins, and losses.',
      confirmLabel: 'Reset',
      danger: true,
    ).then((confirmed) {
      if (!confirmed) return;
      ref.read(gameProvider.notifier).resetStatistics();
      if (context.mounted) ToastUtils.show(context, 'Statistics cleared!');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final settings = gameState.settings;

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
                            HapticUtils.trigger(HapticType.tap, settings);
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
                                  'SETTINGS',
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
                      // Preferences Category
                      _buildCategoryHeader('Preferences'),
                      // Switch 1: Sound Effects
                      _buildPreferenceCard(
                        title: 'Sound Effects',
                        subtitle:
                            'Play sounds on tile placement\n& when you win.',
                        iconData: Icons.volume_up_rounded,
                        value: settings.soundEnabled,
                        onChanged: (val) {
                          HapticUtils.trigger(HapticType.tap, settings);
                          ref.read(gameProvider.notifier).toggleSound(val);
                          ToastUtils.show(
                            context,
                            val
                                ? 'Sound effects enabled'
                                : 'Sound effects disabled',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Switch 2: Haptic Feedback
                      _buildPreferenceCard(
                        title: 'Haptic Feedback',
                        subtitle: 'Vibrate for tile movements\n& taps.',
                        iconData: Icons.vibration_rounded,
                        value: settings.hapticEnabled,
                        onChanged: (val) {
                          ref.read(gameProvider.notifier).toggleHaptics(val);
                          if (val) {
                            HapticFeedback.mediumImpact();
                          }
                          ToastUtils.show(
                            context,
                            val
                                ? 'Haptic feedback enabled'
                                : 'Haptic feedback disabled',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Switch 3: Background Music
                      _buildPreferenceCard(
                        title: 'Background Music',
                        subtitle:
                            'Enable ambient music\nfor a more immersive\nexperience.',
                        iconData: Icons.music_note_rounded,
                        value: settings.musicEnabled,
                        onChanged: (val) {
                          HapticUtils.trigger(HapticType.tap, settings);
                          ref.read(gameProvider.notifier).toggleMusic(val);
                          ToastUtils.show(
                            context,
                            val
                                ? 'Background music enabled'
                                : 'Background music disabled',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const _NotificationPreferencesCard(),
                      const SizedBox(height: 24),
                      // Gameplay Category
                      _buildCategoryHeader('Gameplay'),
                      // Card 4: AI Placement Speed Selector
                      Container(
                        padding: const EdgeInsets.all(16),
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
                            Text(
                              'AI Placement Speed',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lora(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.shinyGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose how fast the computer opponent places tiles on the board.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppTheme.mutedIvory,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Speed selection segmented row
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.shinyGold.withValues(
                                    alpha: 0.25,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Row(
                                  children: [
                                    _buildSpeedOption(
                                      context,
                                      ref,
                                      'Slow',
                                      Icons.hourglass_bottom_rounded,
                                      1.5,
                                      settings.animationSpeed,
                                      isFirst: true,
                                    ),
                                    _buildSpeedOption(
                                      context,
                                      ref,
                                      'Normal',
                                      Icons.eco_rounded,
                                      1.0,
                                      settings.animationSpeed,
                                    ),
                                    _buildSpeedOption(
                                      context,
                                      ref,
                                      'Fast',
                                      Icons.directions_run_rounded,
                                      0.5,
                                      settings.animationSpeed,
                                    ),
                                    _buildSpeedOption(
                                      context,
                                      ref,
                                      'Instant',
                                      Icons.flash_on_rounded,
                                      0.2,
                                      settings.animationSpeed,
                                      isLast: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Account Category
                      _buildCategoryHeader('Account'),
                      // Card 5: Reset Statistics (Red danger button)
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.shinyGold.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5A120A), Color(0xFF2E0502)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticUtils.trigger(HapticType.tap, settings);
                              _showResetConfirmDialog(context, ref);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Row(
                                children: [
                                  // Left Trash Icon Circular Frame
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF2E0502),
                                      border: Border.all(
                                        color: AppTheme.shinyGold.withValues(
                                          alpha: 0.65,
                                        ),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.delete_rounded,
                                        color: AppTheme.shinyGold,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Middle Text Info
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Reset Statistics',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.lora(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.ivoryText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'This will permanently delete all your gameplay statistics and records.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFFE2B7B5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Right Arrow
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
      padding: const EdgeInsets.only(top: 14.0, bottom: 10.0),
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

  Widget _buildPreferenceCard({
    required String title,
    required String subtitle,
    required IconData iconData,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
      child: Row(
        children: [
          // Left Circular Icon Frame
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF010A07),
              border: Border.all(
                color: AppTheme.shinyGold.withValues(alpha: 0.65),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Icon(iconData, color: AppTheme.shinyGold, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          // Middle Text (Serif Title, Sans-serif Subtitle)
          Expanded(
            child: Column(
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
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.mutedIvory,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Custom Green/Gold Toggle Switch
          _buildCustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildCustomSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value ? const Color(0xFF0C5036) : const Color(0xFF031610),
          border: Border.all(
            color: value
                ? AppTheme.shinyGold
                : AppTheme.shinyGold.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: value ? 24.0 : 2.0,
              top: 2.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFF1CC),
                      Color(0xFFD4AF37),
                      Color(0xFF9E7108),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    IconData icon,
    double speedVal,
    double currentSpeed, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final bool active = speedVal == currentSpeed;
    return Expanded(
      child: InkWell(
        onTap: () {
          final settings = ref.read(gameProvider).settings;
          HapticUtils.trigger(HapticType.tap, settings);
          ref.read(gameProvider.notifier).setAnimationSpeed(speedVal);
          ToastUtils.show(context, 'AI speed set to: $label');
        },
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0A3022) : Colors.transparent,
            border: active
                ? Border.all(color: AppTheme.shinyGold, width: 1.5)
                : Border(
                    right: !isLast
                        ? BorderSide(
                            color: AppTheme.shinyGold.withValues(alpha: 0.15),
                            width: 1.0,
                          )
                        : BorderSide.none,
                  ),
            borderRadius: active
                ? BorderRadius.circular(10)
                : BorderRadius.horizontal(
                    left: isFirst ? const Radius.circular(11) : Radius.zero,
                    right: isLast ? const Radius.circular(11) : Radius.zero,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? AppTheme.shinyGold : AppTheme.mutedIvory,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? AppTheme.shinyGold : AppTheme.mutedIvory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPreferencesCard extends StatefulWidget {
  const _NotificationPreferencesCard();

  @override
  State<_NotificationPreferencesCard> createState() =>
      _NotificationPreferencesCardState();
}

class _NotificationPreferencesCardState
    extends State<_NotificationPreferencesCard> {
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await PushNotificationService.loadPreferences();
      if (mounted) setState(() => _preferences = preferences);
    } catch (_) {
      // The controls remain usable once the player is signed in or online.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(NotificationPreferences preferences) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _preferences = preferences;
    });
    try {
      final permission = await PushNotificationService.permissionStatus();
      final isAllowed =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
      if (!isAllowed &&
          (preferences.multiplayerTurns ||
              preferences.rankedMatches ||
              preferences.dailyReminders)) {
        final granted =
            await PushNotificationService.requestPermissionAndRegister();
        if (!granted && mounted) {
          ToastUtils.show(
            context,
            'Allow notifications in your device settings to receive alerts.',
          );
        }
      }
      await PushNotificationService.savePreferences(preferences);
    } catch (_) {
      if (mounted)
        ToastUtils.show(
          context,
          'Notification settings could not be saved.',
          isError: true,
        );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = PushNotificationService.isSignedIn;
    return Opacity(
      opacity: _loading ? .65 : 1,
      child: Column(
        children: [
          _notificationPreferenceCard(
            icon: Icons.notifications_active_rounded,
            title: 'Game Notifications',
            subtitle: signedIn
                ? 'Get alerts for your multiplayer turn, ranked matches, and daily challenge.'
                : 'Sign in to choose which game updates can reach this device.',
            value:
                _preferences.multiplayerTurns ||
                _preferences.rankedMatches ||
                _preferences.dailyReminders,
            onChanged: signedIn
                ? (value) => _save(
                    NotificationPreferences(
                      multiplayerTurns: value,
                      rankedMatches: value,
                      dailyReminders: value,
                    ),
                  )
                : null,
          ),
          if (signedIn) ...[
            const SizedBox(height: 12),
            _notificationPreferenceCard(
              icon: Icons.sports_esports_rounded,
              title: 'Your Multiplayer Turn',
              subtitle: 'Know when it is your move in an online match.',
              value: _preferences.multiplayerTurns,
              onChanged: (value) =>
                  _save(_preferences.copyWith(multiplayerTurns: value)),
            ),
            const SizedBox(height: 12),
            _notificationPreferenceCard(
              icon: Icons.emoji_events_rounded,
              title: 'Ranked Match Updates',
              subtitle: 'Receive results and updates from Competitive Duel.',
              value: _preferences.rankedMatches,
              onChanged: (value) =>
                  _save(_preferences.copyWith(rankedMatches: value)),
            ),
            const SizedBox(height: 12),
            _notificationPreferenceCard(
              icon: Icons.local_fire_department_rounded,
              title: 'Daily Challenge Reminder',
              subtitle: 'A daily reminder to keep your challenge streak alive.',
              value: _preferences.dailyReminders,
              onChanged: (value) =>
                  _save(_preferences.copyWith(dailyReminders: value)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _notificationPreferenceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.shinyGold.withValues(alpha: .45),
          width: 1.2,
        ),
        gradient: const LinearGradient(
          colors: AppTheme.darkGreenGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF010A07),
              border: Border.all(
                color: AppTheme.shinyGold.withValues(alpha: 0.65),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: AppTheme.shinyGold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
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
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.mutedIvory,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildNotificationSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final enabled = onChanged != null && !_loading && !_saving;
    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value ? const Color(0xFF0C5036) : const Color(0xFF031610),
          border: Border.all(
            color: value
                ? AppTheme.shinyGold
                : AppTheme.shinyGold.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: value ? 24 : 2,
              top: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFF1CC),
                      Color(0xFFD4AF37),
                      Color(0xFF9E7108),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
