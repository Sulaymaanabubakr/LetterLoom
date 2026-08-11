import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../storage/persistence_manager.dart';
import '../../core/supabase_bootstrap.dart';
import '../hints/hint_service.dart';
import '../progression/progression_service.dart';

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
          onClaim: () async {
            final claimed = await _claimToday(
              ref,
              isAccount,
              state,
              today,
              nextStreak,
            );
            if (claimed && dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
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
        return result is Map && result['claimed'] == true;
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
  final Future<void> Function() onClaim;

  const _DailyRewardDialog({required this.streakDays, required this.onClaim});

  @override
  State<_DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<_DailyRewardDialog> {
  bool _claiming = false;

  static const _rewards = <({String title, String detail, IconData icon})>[
    (title: 'Welcome', detail: '+1 Move Hint', icon: Icons.swap_horiz_rounded),
    (
      title: 'Letter Loom',
      detail: '+1 Letter Hint',
      icon: Icons.text_fields_rounded,
    ),
    (
      title: 'Sharp Eye',
      detail: '+1 Strong Hint',
      icon: Icons.visibility_rounded,
    ),
    (title: 'Wordsmith', detail: '+50 XP', icon: Icons.auto_awesome_rounded),
    (
      title: 'Well Read',
      detail: '+2 Move Hints',
      icon: Icons.menu_book_rounded,
    ),
    (
      title: 'Loom Master',
      detail: '+2 Letter Hints',
      icon: Icons.workspace_premium_rounded,
    ),
    (title: 'Full Week', detail: '+100 XP', icon: Icons.emoji_events_rounded),
  ];

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    await widget.onClaim();
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
              'Day $currentDay is ready to collect',
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
                  children: List.generate(_rewards.length, (index) {
                    final day = index + 1;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: day == _rewards.length ? 0 : 8,
                      ),
                      child: _RewardDayCard(
                        day: day,
                        reward: _rewards[index],
                        claimed: day < currentDay,
                        today: day == currentDay,
                        claiming: _claiming && day == currentDay,
                        onTap: day == currentDay && !_claiming ? _claim : null,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardDayCard extends StatelessWidget {
  final int day;
  final ({String title, String detail, IconData icon}) reward;
  final bool claimed;
  final bool today;
  final bool claiming;
  final VoidCallback? onTap;

  const _RewardDayCard({
    required this.day,
    required this.reward,
    required this.claimed,
    required this.today,
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
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: today
                ? AppTheme.shinyGold.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: today ? 1 : 0.45),
              width: today ? 1.5 : 0.9,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  'DAY $day',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: today ? AppTheme.shinyGold : AppTheme.mutedIvory,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.14),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: claiming
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      : Icon(
                          claimed
                              ? Icons.check_rounded
                              : today
                              ? reward.icon
                              : Icons.lock_rounded,
                          size: 19,
                          color: color,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ivoryText,
                      ),
                    ),
                    Text(
                      reward.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: today ? AppTheme.ivoryText : AppTheme.mutedIvory,
                      ),
                    ),
                  ],
                ),
              ),
              if (today && !claiming)
                const Icon(
                  Icons.touch_app_rounded,
                  color: AppTheme.shinyGold,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
