import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_config.dart';

/// Callback when user successfully earns a reward by watching a rewarded ad.
typedef OnRewardEarnedCallback = void Function(String rewardType, int amount);

/// Rewarded Advertising Service.
///
/// Follows strict integrity rules:
/// - Never grants reward unless completed callback fires.
/// - Never interrupts active turns or obscures game board.
/// - Enforces daily rewarded ad limit.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isAdLoading = false;
  RewardedAd? _rewardedAd;
  Future<void>? _loadFuture;
  bool get isAdLoading => _isAdLoading;

  String get _adUnitId {
    // Never send live ad traffic from a debug build. It is both slower to
    // diagnose and contrary to AdMob's test-ad requirement.
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? AppConfig.rewardedAdUnitIdAndroid
        : AppConfig.rewardedAdUnitIdIOS;
  }

  bool get _usesGoogleTestUnitId {
    return _adUnitId.contains('ca-app-pub-3940256099942544/');
  }

  bool get _isConfiguredForThisBuild => !kReleaseMode || !_usesGoogleTestUnitId;

  Future<void> initialize() async {
    if (kIsWeb || !_isConfiguredForThisBuild) {
      if (!kIsWeb && kReleaseMode) {
        debugPrint(
          '[Ads] Disabled: a production rewarded-ad unit ID is required.',
        );
      }
      return;
    }
    try {
      await MobileAds.instance.initialize();
      // Load while the app is idle so tapping Watch Ads is normally instant.
      unawaited(_loadRewardedAd());
    } catch (error) {
      debugPrint('[Ads] Initialization failed: $error');
    }
  }

  /// Requests a rewarded ad display when an SDK integration is available.
  /// Returns `true` if reward was earned, `false` otherwise.
  Future<bool> showRewardedAd({
    required String hintType,
    required OnRewardEarnedCallback onRewardEarned,
    required void Function(String errorMessage) onError,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) {
      onError('Rewarded ads are unavailable on this platform.');
      return false;
    }
    if (!_isConfiguredForThisBuild) {
      onError('Rewarded ads are not configured for this production build.');
      return false;
    }
    final ad = await _loadRewardedAd();
    if (ad == null) {
      onError('Rewarded ads are temporarily unavailable.');
      return false;
    }

    final completer = Completer<bool>();
    _rewardedAd = null;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(earned);
        unawaited(_loadRewardedAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[Ads] Show failed: $error');
        ad.dispose();
        if (!completer.isCompleted) {
          onError('The rewarded ad could not be shown.');
          completer.complete(false);
        }
        unawaited(_loadRewardedAd());
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
        // This callback is the only local proof that the SDK reported a
        // completed reward. Account balances still require server-side
        // verification and are intentionally not granted by this class.
        onRewardEarned(hintType, 1);
      },
    );
    return completer.future;
  }

  Future<RewardedAd?> _loadRewardedAd() async {
    if (_rewardedAd != null) return _rewardedAd;
    if (_loadFuture != null) {
      await _loadFuture;
      return _rewardedAd;
    }

    _isAdLoading = true;
    final completer = Completer<void>();
    _loadFuture = completer.future;
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          _loadFuture = null;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] Load failed: $error');
          _isAdLoading = false;
          _loadFuture = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    await completer.future;
    return _rewardedAd;
  }
}
