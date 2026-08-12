/// Central configuration for LetterLoom extensions and external service integrations.
///
/// RULE: Never hardcode private backend secrets, live AdMob unit IDs, or production
/// OAuth credentials directly. Use safe development fallbacks and environment variables.
class AppConfig {
  // ── Authentication & Google Sign-In ──────────────────────────────────────
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    // OAuth client IDs are public identifiers. The secret remains configured
    // only in Supabase and is never shipped with the app.
    defaultValue:
        '374555574691-egp5n392vi1ulkmbt1i5qcg3t0oh5m1t.apps.googleusercontent.com',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '374555574691-gtnjggpcbnsp4ugnvqa3rps9fiocrgp9.apps.googleusercontent.com',
  );

  static String? get configuredGoogleClientId {
    final value = googleClientId.trim();
    if (value.isEmpty || value.startsWith('PLACEHOLDER_')) return null;
    return value;
  }

  // ── Google Play Games Integration ─────────────────────────────────────────
  static const String playGamesAppId = String.fromEnvironment(
    'PLAY_GAMES_APP_ID',
    defaultValue: '374555574691',
  );

  static const Map<String, String> playGamesAchievementsMap = {
    'first_victory': 'CgkI_PLACEHOLDER_ACHIEVEMENT_01',
    'first_bingo': 'CgkI_PLACEHOLDER_ACHIEVEMENT_02',
    'hard_earned': 'CgkI_PLACEHOLDER_ACHIEVEMENT_03',
    'big_move': 'CgkI_PLACEHOLDER_ACHIEVEMENT_04',
    'triple_century': 'CgkI_PLACEHOLDER_ACHIEVEMENT_05',
    'winning_streak': 'CgkI_PLACEHOLDER_ACHIEVEMENT_06',
    'champion': 'CgkI_PLACEHOLDER_ACHIEVEMENT_07',
  };

  static const Map<String, String> playGamesLeaderboardsMap = {
    'ranked_rating': 'CgkI_PLACEHOLDER_LEADERBOARD_RANKED',
    'highest_game_score': 'CgkI_PLACEHOLDER_LEADERBOARD_GAME_SCORE',
    'daily_challenge': 'CgkI_PLACEHOLDER_LEADERBOARD_DAILY_CHALLENGE',
  };

  // ── AdMob Configuration ───────────────────────────────────────────────────
  // Google Official Test Ad Unit ID for Rewarded Ads (Android / iOS default)
  static const String rewardedAdUnitIdAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_AD_UNIT_ID_ANDROID',
    defaultValue:
        'ca-app-pub-3940256099942544/5224354917', // Google AdMob Test Rewarded ID
  );
  static const String rewardedAdUnitIdIOS = String.fromEnvironment(
    'ADMOB_REWARDED_AD_UNIT_ID_IOS',
    defaultValue:
        'ca-app-pub-3940256099942544/1712485313', // Google AdMob Test Rewarded ID
  );

  static const int dailyRewardedAdLimit = 3;

  // ── Daily Hint Allowances ─────────────────────────────────────────────────
  static const int defaultDailyMoveHints = 3;
  static const int defaultDailyLetterHints = 3;
  static const int defaultDailyStrongHints = 1;

  // ── Play Billing Consumable Product IDs ──────────────────────────────────
  static const String productMoveHintPack5 = 'letterloom_hints_move_5';
  static const String productLetterHintPack5 = 'letterloom_hints_letter_5';
  static const String productStrongHintPack3 = 'letterloom_hints_strong_3';
  static const String productMixedHintBundle = 'letterloom_hints_mixed_bundle';

  static const List<String> purchasableProductIds = [
    productMoveHintPack5,
    productLetterHintPack5,
    productStrongHintPack3,
    productMixedHintBundle,
  ];

  // ── XP & Level System Configuration ─────────────────────────────────────
  static const int xpMatchComplete = 50;
  static const int xpMatchWin = 100;
  static const int xpBingo = 50;
  static const int xpDailyChallengeComplete = 150;
  static const int xpDailyMissionComplete = 75;
  static const int xpWeeklyMissionComplete = 200;
  static const int xpAchievementUnlock = 100;

  /// Calculate total cumulative XP required to reach a specific level.
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    return (100 * (level - 1) * (level - 1) * 1.5).round();
  }

  /// Calculate player level based on total cumulative XP.
  static int levelForXP(int xp) {
    if (xp <= 0) return 1;
    int level = 1;
    while (xpRequiredForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  // ── Competitive Ranked Configuration ────────────────────────────────────
  static const int defaultRankedRating = 1200;
  static const int rankedKFactor = 32;

  static String getRankedTier(int rating) {
    if (rating < 1000) return 'Bronze III';
    if (rating < 1100) return 'Bronze II';
    if (rating < 1200) return 'Bronze I';
    if (rating < 1350) return 'Silver III';
    if (rating < 1500) return 'Silver II';
    if (rating < 1650) return 'Silver I';
    if (rating < 1800) return 'Gold III';
    if (rating < 1950) return 'Gold II';
    if (rating < 2100) return 'Gold I';
    if (rating < 2300) return 'Platinum';
    if (rating < 2500) return 'Diamond';
    return 'Master';
  }
}
