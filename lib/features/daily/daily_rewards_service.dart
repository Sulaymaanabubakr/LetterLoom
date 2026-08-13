import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../storage/persistence_manager.dart';
import '../../core/supabase_bootstrap.dart';
import '../../core/toast_utils.dart';
import '../hints/hint_service.dart';
import '../progression/progression_service.dart';
import '../auth/auth_service.dart';

@immutable
class DailyRewardState {
  final int streakDays;
  final String lastClaimDate;

  const DailyRewardState({
    required this.streakDays,
    required this.lastClaimDate,
  });

  Map<String, dynamic> toJson() => {
    'streakDays': streakDays,
    'lastClaimDate': lastClaimDate,
  };

  factory DailyRewardState.fromJson(Map<String, dynamic> json) {
    return DailyRewardState(
      streakDays: json['streakDays'] as int? ?? 0,
      lastClaimDate: json['lastClaimDate'] as String? ?? '',
    );
  }
}

class DailyRewardsService {
  static final PersistenceManager _persistence = PersistenceManager();
  static const String _saveFileName = 'letterloom_daily_rewards_v1.json';
  static bool _claimInFlight = false;

  static String getTodayString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<DailyRewardState> loadState() async {
    final json = await _persistence.loadJsonData(_saveFileName);
    if (json != null) {
      return DailyRewardState.fromJson(json);
    }
    return const DailyRewardState(streakDays: 0, lastClaimDate: '');
  }

  static Future<void> checkAndShowDailyReward(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_claimInFlight) return;
    _claimInFlight = true;
    try {
      final remoteUser = SupabaseBootstrap.configured
          ? Supabase.instance.client.auth.currentUser
          : null;
      final isAccount = remoteUser != null && !remoteUser.isAnonymous;
      final state = await loadState();
      final today = getTodayString();
      int nextStreak;

      if (isAccount) {
        try {
          final response = await Supabase.instance.client.functions.invoke(
            'hint-wallet',
            body: const {'action': 'daily_reward_status'},
          );
          final payload = response.data;
          final result = payload is Map ? payload['result'] : null;
          if (result is! Map || result['claimable'] != true) return;
          nextStreak = (result['streak_days'] as num?)?.toInt() ?? 1;
        } catch (error) {
          debugPrint('[DailyRewards] Server status unavailable: $error');
          return;
        }
      } else {
        if (state.lastClaimDate == today) return;
        nextStreak = _nextGuestStreak(state, today);
      }

      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (dialogContext) => _DailyRewardDialog(
          streakDays: nextStreak,
          onClaim: () => _claimToday(ref, isAccount, state, today, nextStreak),
          onClaimed: () {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (context.mounted) {
              ToastUtils.show(context, _rewardConfirmationMessage(nextStreak));
            }
          },
          onClaimFailed: () {
            if (context.mounted) {
              ToastUtils.show(
                context,
                'Daily reward could not be claimed. Please try again.',
                isError: true,
              );
            }
          },
        ),
      );
    } finally {
      _claimInFlight = false;
    }
  }

  static int _nextGuestStreak(DailyRewardState state, String today) {
    if (state.lastClaimDate.isEmpty) return 1;
    final parts = state.lastClaimDate.split('-');
    final lastDate = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final nowParts = today.split('-');
    final currentDate = DateTime.utc(
      int.parse(nowParts[0]),
      int.parse(nowParts[1]),
      int.parse(nowParts[2]),
    );
    return currentDate.difference(lastDate).inDays == 1
        ? state.streakDays + 1
        : 1;
  }

  static String _rewardConfirmationMessage(int streakDays) {
    final day = ((streakDays - 1) % 7) + 1;
    return switch (day) {
      1 => 'Daily reward claimed: +1 Move Hint.',
      2 => 'Daily reward claimed: +1 Letter Hint.',
      3 => 'Daily reward claimed: +1 Strong Hint.',
      4 => 'Daily reward claimed: +50 level progress.',
      5 => 'Daily reward claimed: +2 Move Hints.',
      6 => 'Daily reward claimed: +2 Letter Hints.',
      _ => 'Daily reward claimed: +100 level progress.',
    };
  }

  static Future<bool> _claimToday(
    WidgetRef ref,
    bool isAccount,
    DailyRewardState state,
    String today,
    int streakDays,
  ) async {
    if (isAccount) {
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'hint-wallet',
          body: const {'action': 'daily_reward'},
        );
        final payload = response.data;
        final result = payload is Map ? payload['result'] : null;
        final claimed = result is Map && result['claimed'] == true;
        if (claimed) {
          // The claim is server-owned. Hydrate every visible account balance
          // immediately so Home does not wait for a relaunch.
          await ref.read(hintServiceProvider.notifier).refresh();
          await ref.read(authProvider.notifier).refreshRemoteProfile();
        }
        return claimed;
      } catch (error) {
        debugPrint('[DailyRewards] Server claim unavailable: $error');
        return false;
      }
    }

    await _persistence.saveJsonData(
      _saveFileName,
      DailyRewardState(streakDays: streakDays, lastClaimDate: today).toJson(),
    );
    final day = ((streakDays - 1) % 7) + 1;
    final hints = ref.read(hintServiceProvider.notifier);
    if (day == 1) await hints.addPurchasedHints('move', 1);
    if (day == 2) await hints.addPurchasedHints('letter', 1);
    if (day == 3) await hints.addPurchasedHints('strong', 1);
    if (day == 4) {
      await ref
          .read(progressionProvider)
          .addXP(50, reason: 'Daily Login Reward');
    }
    if (day == 5) await hints.addPurchasedHints('move', 2);
    if (day == 6) await hints.addPurchasedHints('letter', 2);
    if (day == 7) {
      await ref
          .read(progressionProvider)
          .addXP(100, reason: 'Daily Login Reward');
    }
    return true;
  }
}

class _DailyRewardDialog extends StatefulWidget {
  final int streakDays;
  final Future<bool> Function() onClaim;
  final VoidCallback onClaimed;
  final VoidCallback onClaimFailed;

  const _DailyRewardDialog({
    required this.streakDays,
    required this.onClaim,
    required this.onClaimed,
    required this.onClaimFailed,
  });

  @override
  State<_DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<_DailyRewardDialog> {
  bool _claiming = false;

  static const _rewards = <({String title, String detail, IconData icon})>[
    (
      title: 'Move Hint',
      detail: 'Get 1 Move Hint',
      icon: Icons.swap_horiz_rounded,
    ),
    (
      title: 'Letter Hint',
      detail: 'Get 1 Letter Hint',
      icon: Icons.text_fields_rounded,
    ),
    (
      title: 'Strong Hint',
      detail: 'Get 1 Strong Hint',
      icon: Icons.visibility_rounded,
    ),
    (
      title: 'Level Progress',
      detail: 'Add 50 to your level progress',
      icon: Icons.auto_awesome_rounded,
    ),
    (
      title: 'Move Hint Bonus',
      detail: 'Get 2 Move Hints',
      icon: Icons.menu_book_rounded,
    ),
    (
      title: 'Letter Hint Bonus',
      detail: 'Get 2 Letter Hints',
      icon: Icons.workspace_premium_rounded,
    ),
    (
      title: 'Weekly Progress',
      detail: 'Add 100 to your level progress',
      icon: Icons.emoji_events_rounded,
    ),
  ];

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final claimed = await widget.onClaim();
    if (claimed) {
      widget.onClaimed();
    } else {
      widget.onClaimFailed();
    }
    if (mounted) setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentDay = ((widget.streakDays - 1) % _rewards.length) + 1;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF021710),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.shinyGold, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
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
                        '→',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                      Flexible(
                        child: ShaderMask(
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
                            'Daily Rewards',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lora(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
                Transform.translate(
                  offset: const Offset(8, -10),
                  child: InkWell(
                    onTap: _claiming ? null : () => Navigator.of(context).pop(),
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
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Claim one reward each day. Keep your streak to unlock bonuses.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.mutedIvory,
              ),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _RewardDayCard(
                      day: currentDay,
                      reward: _rewards[currentDay - 1],
                      claimed: false,
                      today: true,
                      featured: true,
                      claiming: _claiming,
                      onTap: !_claiming ? _claim : null,
                    ),
                    const SizedBox(height: 10),
                    ..._buildRewardGrid(currentDay),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRewardCard(int day, int currentDay) {
    return _RewardDayCard(
      day: day,
      reward: _rewards[day - 1],
      claimed: day < currentDay,
      today: false,
      featured: false,
    );
  }

  List<Widget> _buildRewardGrid(int currentDay) {
    final otherDays = List<int>.generate(_rewards.length, (index) => index + 1)
      ..remove(currentDay);
    final rowCount = (otherDays.length / 2).ceil();
    return List<Widget>.generate(rowCount, (row) {
      final days = otherDays.skip(row * 2).take(2).toList();
      return Padding(
        padding: EdgeInsets.only(bottom: row == rowCount - 1 ? 0 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(2, (slot) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: slot == 0 ? 4 : 0,
                  left: slot == 1 ? 4 : 0,
                ),
                child: slot < days.length
                    ? _buildCompactRewardCard(days[slot], currentDay)
                    : const SizedBox.shrink(),
              ),
            );
          }),
        ),
      );
    });
  }
}

class _RewardDayCard extends StatelessWidget {
  final int day;
  final ({String title, String detail, IconData icon}) reward;
  final bool claimed;
  final bool today;
  final bool featured;
  final bool claiming;
  final VoidCallback? onTap;

  const _RewardDayCard({
    required this.day,
    required this.reward,
    required this.claimed,
    required this.today,
    required this.featured,
    this.claiming = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = today
        ? AppTheme.shinyGold
        : claimed
        ? AppTheme.emeraldGreen
        : AppTheme.lightGrey;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: featured ? 86 : 122,
          padding: EdgeInsets.symmetric(
            horizontal: featured ? 16 : 12,
            vertical: featured ? 10 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: today
                  ? [
                      AppTheme.shinyGold.withValues(alpha: 0.22),
                      AppTheme.shinyGold.withValues(alpha: 0.07),
                    ]
                  : claimed
                  ? [
                      AppTheme.emeraldGreen.withValues(alpha: 0.16),
                      AppTheme.panelDark,
                    ]
                  : [AppTheme.panelDark, const Color(0xFF031E15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(featured ? 18 : 16),
            border: Border.all(
              color: color.withValues(alpha: today ? 0.95 : 0.5),
              width: today ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: featured
              ? _buildFeaturedContent(color)
              : _buildCompactContent(color),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Color color, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: claiming
            ? SizedBox(
                width: size * 0.42,
                height: size * 0.42,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(
                claimed
                    ? Icons.check_rounded
                    : today
                    ? reward.icon
                    : Icons.lock_rounded,
                size: size * 0.48,
                color: color,
              ),
      ),
    );
  }

  Widget _buildFeaturedContent(Color color) {
    return Row(
      children: [
        _buildStatusIcon(color, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAY $day • TODAY\'S REWARD',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.shinyGold,
                ),
              ),
              Text(
                reward.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ivoryText,
                ),
              ),
              Text(
                reward.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.ivoryText,
                ),
              ),
            ],
          ),
        ),
        if (!claiming)
          const Icon(
            Icons.touch_app_rounded,
            color: AppTheme.shinyGold,
            size: 20,
          ),
      ],
    );
  }

  Widget _buildCompactContent(Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DAY $day',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.mutedIvory,
              ),
            ),
            _buildStatusIcon(color, size: 34),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          reward.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.ivoryText,
          ),
        ),
        Text(
          reward.detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10,
            height: 1.15,
            color: AppTheme.mutedIvory,
          ),
        ),
      ],
    );
  }
}
