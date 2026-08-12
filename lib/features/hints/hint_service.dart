import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_config.dart';
import '../../core/supabase_bootstrap.dart';
import '../../storage/persistence_manager.dart';

@immutable
class HintState {
  final int dailyMoveRemaining;
  final int dailyLetterRemaining;
  final int dailyStrongRemaining;
  final int purchasedMove;
  final int purchasedLetter;
  final int purchasedStrong;
  final int adsWatchedToday;
  final String lastResetDate;

  const HintState({
    required this.dailyMoveRemaining,
    required this.dailyLetterRemaining,
    required this.dailyStrongRemaining,
    required this.purchasedMove,
    required this.purchasedLetter,
    required this.purchasedStrong,
    required this.adsWatchedToday,
    required this.lastResetDate,
  });

  factory HintState.initial() {
    final todayStr = _formatDate(DateTime.now());
    return HintState(
      dailyMoveRemaining: AppConfig.defaultDailyMoveHints,
      dailyLetterRemaining: AppConfig.defaultDailyLetterHints,
      dailyStrongRemaining: AppConfig.defaultDailyStrongHints,
      purchasedMove: 0,
      purchasedLetter: 0,
      purchasedStrong: 0,
      adsWatchedToday: 0,
      lastResetDate: todayStr,
    );
  }

  static String _formatDate(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  int totalMoveHints() => dailyMoveRemaining + purchasedMove;
  int totalLetterHints() => dailyLetterRemaining + purchasedLetter;
  int totalStrongHints() => dailyStrongRemaining + purchasedStrong;

  HintState copyWith({
    int? dailyMoveRemaining,
    int? dailyLetterRemaining,
    int? dailyStrongRemaining,
    int? purchasedMove,
    int? purchasedLetter,
    int? purchasedStrong,
    int? adsWatchedToday,
    String? lastResetDate,
  }) {
    return HintState(
      dailyMoveRemaining: dailyMoveRemaining ?? this.dailyMoveRemaining,
      dailyLetterRemaining: dailyLetterRemaining ?? this.dailyLetterRemaining,
      dailyStrongRemaining: dailyStrongRemaining ?? this.dailyStrongRemaining,
      purchasedMove: purchasedMove ?? this.purchasedMove,
      purchasedLetter: purchasedLetter ?? this.purchasedLetter,
      purchasedStrong: purchasedStrong ?? this.purchasedStrong,
      adsWatchedToday: adsWatchedToday ?? this.adsWatchedToday,
      lastResetDate: lastResetDate ?? this.lastResetDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyMoveRemaining': dailyMoveRemaining,
      'dailyLetterRemaining': dailyLetterRemaining,
      'dailyStrongRemaining': dailyStrongRemaining,
      'purchasedMove': purchasedMove,
      'purchasedLetter': purchasedLetter,
      'purchasedStrong': purchasedStrong,
      'adsWatchedToday': adsWatchedToday,
      'lastResetDate': lastResetDate,
    };
  }

  factory HintState.fromJson(Map<String, dynamic> json) {
    final todayStr = _formatDate(DateTime.now());
    final savedDate = json['lastResetDate'] as String? ?? todayStr;
    final isSameDay = savedDate == todayStr;

    return HintState(
      dailyMoveRemaining: isSameDay
          ? (json['dailyMoveRemaining'] as int? ??
                AppConfig.defaultDailyMoveHints)
          : AppConfig.defaultDailyMoveHints,
      dailyLetterRemaining: isSameDay
          ? (json['dailyLetterRemaining'] as int? ??
                AppConfig.defaultDailyLetterHints)
          : AppConfig.defaultDailyLetterHints,
      dailyStrongRemaining: isSameDay
          ? (json['dailyStrongRemaining'] as int? ??
                AppConfig.defaultDailyStrongHints)
          : AppConfig.defaultDailyStrongHints,
      purchasedMove: json['purchasedMove'] as int? ?? 0,
      purchasedLetter: json['purchasedLetter'] as int? ?? 0,
      purchasedStrong: json['purchasedStrong'] as int? ?? 0,
      adsWatchedToday: isSameDay ? (json['adsWatchedToday'] as int? ?? 0) : 0,
      lastResetDate: todayStr,
    );
  }
}

final hintServiceProvider = StateNotifierProvider<HintNotifier, HintState>((
  ref,
) {
  return HintNotifier();
});

class HintNotifier extends StateNotifier<HintState> {
  static const String _saveFileName = 'letterloom_hints_v1.json';
  final PersistenceManager _persistence = PersistenceManager();
  bool _mutationInFlight = false;
  final Completer<void> _initialization = Completer<void>();

  HintNotifier() : super(HintState.initial()) {
    _init();
  }

  /// Allows the splash screen to hydrate the wallet before HomeScreen builds.
  Future<void> get ready => _initialization.future;

  Future<void> _init() async {
    try {
      if (_isAuthenticatedAccount) {
        await _loadRemoteWallet();
        return;
      }
      final savedData = await _persistence.loadJsonData(_saveFileName);
      if (savedData != null) {
        state = HintState.fromJson(savedData);
      } else {
        await _save();
      }
    } finally {
      if (!_initialization.isCompleted) _initialization.complete();
    }
  }

  bool get _isAuthenticatedAccount {
    final user = SupabaseBootstrap.configured
        ? Supabase.instance.client.auth.currentUser
        : null;
    return user != null && !user.isAnonymous;
  }

  Future<void> _loadRemoteWallet() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'hint-wallet',
        body: const {'action': 'get'},
      );
      final raw = response.data is Map ? response.data['wallet'] : null;
      if (raw is! Map) return;
      state = state.copyWith(
        dailyMoveRemaining: (raw['daily_move_remaining'] as num?)?.toInt(),
        dailyLetterRemaining: (raw['daily_letter_remaining'] as num?)?.toInt(),
        dailyStrongRemaining: (raw['daily_strong_remaining'] as num?)?.toInt(),
        purchasedMove: (raw['purchased_move'] as num?)?.toInt(),
        purchasedLetter: (raw['purchased_letter'] as num?)?.toInt(),
        purchasedStrong: (raw['purchased_strong'] as num?)?.toInt(),
        adsWatchedToday: (raw['ads_claimed_today'] as num?)?.toInt(),
        lastResetDate: raw['reset_date'] as String?,
      );
    } catch (error) {
      debugPrint('[Hints] Remote wallet unavailable: $error');
      state = HintState.initial();
    }
  }

  Future<void> refresh() =>
      _isAuthenticatedAccount ? _loadRemoteWallet() : _init();

  Future<void> _save() async {
    await _persistence.saveJsonData(_saveFileName, state.toJson());
  }

  /// Consume a hint of the given type if available.
  /// Consumes free daily allowance first; if exhausted, consumes purchased hint balance.
  Future<bool> consumeHint(String hintType) async {
    if (_isAuthenticatedAccount) {
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'hint-wallet',
          body: {'action': 'consume', 'hint_type': hintType},
        );
        final result = response.data is Map ? response.data['result'] : null;
        if (result is! Map || result['granted'] != true) return false;
        final source = result['source'];
        if (hintType == 'move') {
          state = source == 'daily'
              ? state.copyWith(dailyMoveRemaining: state.dailyMoveRemaining - 1)
              : state.copyWith(purchasedMove: state.purchasedMove - 1);
        } else if (hintType == 'letter') {
          state = source == 'daily'
              ? state.copyWith(
                  dailyLetterRemaining: state.dailyLetterRemaining - 1,
                )
              : state.copyWith(purchasedLetter: state.purchasedLetter - 1);
        } else if (hintType == 'strong') {
          state = source == 'daily'
              ? state.copyWith(
                  dailyStrongRemaining: state.dailyStrongRemaining - 1,
                )
              : state.copyWith(purchasedStrong: state.purchasedStrong - 1);
        }
        return true;
      } catch (error) {
        debugPrint('[Hints] Remote consume failed: $error');
        return false;
      }
    }
    if (_mutationInFlight) return false;
    _mutationInFlight = true;
    try {
      return await _consumeHint(hintType);
    } finally {
      _mutationInFlight = false;
    }
  }

  Future<bool> _consumeHint(String hintType) async {
    if (hintType == 'move') {
      if (state.dailyMoveRemaining > 0) {
        state = state.copyWith(
          dailyMoveRemaining: state.dailyMoveRemaining - 1,
        );
        await _save();
        return true;
      } else if (state.purchasedMove > 0) {
        state = state.copyWith(purchasedMove: state.purchasedMove - 1);
        await _save();
        return true;
      }
    } else if (hintType == 'letter') {
      if (state.dailyLetterRemaining > 0) {
        state = state.copyWith(
          dailyLetterRemaining: state.dailyLetterRemaining - 1,
        );
        await _save();
        return true;
      } else if (state.purchasedLetter > 0) {
        state = state.copyWith(purchasedLetter: state.purchasedLetter - 1);
        await _save();
        return true;
      }
    } else if (hintType == 'strong') {
      if (state.dailyStrongRemaining > 0) {
        state = state.copyWith(
          dailyStrongRemaining: state.dailyStrongRemaining - 1,
        );
        await _save();
        return true;
      } else if (state.purchasedStrong > 0) {
        state = state.copyWith(purchasedStrong: state.purchasedStrong - 1);
        await _save();
        return true;
      }
    }
    return false;
  }

  /// Award a hint from watching a rewarded ad.
  Future<bool> grantAdReward(String hintType) async {
    if (_isAuthenticatedAccount) return false;
    if (!{'move', 'letter', 'strong'}.contains(hintType) ||
        state.adsWatchedToday >= AppConfig.dailyRewardedAdLimit) {
      return false;
    }

    if (hintType == 'move') {
      state = state.copyWith(
        dailyMoveRemaining: state.dailyMoveRemaining + 1,
        adsWatchedToday: state.adsWatchedToday + 1,
      );
    } else if (hintType == 'letter') {
      state = state.copyWith(
        dailyLetterRemaining: state.dailyLetterRemaining + 1,
        adsWatchedToday: state.adsWatchedToday + 1,
      );
    } else if (hintType == 'strong') {
      state = state.copyWith(
        dailyStrongRemaining: state.dailyStrongRemaining + 1,
        adsWatchedToday: state.adsWatchedToday + 1,
      );
    }
    await _save();
    return true;
  }

  /// Add purchased hints to separate persistent balance.
  Future<void> addPurchasedHints(String hintType, int count) async {
    if (_isAuthenticatedAccount) return;
    if (count <= 0 ||
        count > 100 ||
        !{'move', 'letter', 'strong'}.contains(hintType)) {
      return;
    }
    if (hintType == 'move') {
      state = state.copyWith(purchasedMove: state.purchasedMove + count);
    } else if (hintType == 'letter') {
      state = state.copyWith(purchasedLetter: state.purchasedLetter + count);
    } else if (hintType == 'strong') {
      state = state.copyWith(purchasedStrong: state.purchasedStrong + count);
    }
    await _save();
  }
}
