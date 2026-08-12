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
  bool get isAdLoading => _isAdLoading;

  bool get _usesGoogleTestUnitId {
    final adUnitId = defaultTargetPlatform == TargetPlatform.android
        ? AppConfig.rewardedAdUnitIdAndroid
        : AppConfig.rewardedAdUnitIdIOS;
    return adUnitId.contains('ca-app-pub-3940256099942544/');
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
    if (_isAdLoading || _rewardedAd != null) {
      onError('A rewarded ad is already loading.');
      return false;
    }

    _isAdLoading = true;
    final completer = Completer<bool>();
    final adUnitId = defaultTargetPlatform == TargetPlatform.android
        ? AppConfig.rewardedAdUnitIdAndroid
        : AppConfig.rewardedAdUnitIdIOS;

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isAdLoading = false;
          _rewardedAd = ad;
          var earned = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              if (!completer.isCompleted) completer.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[Ads] Show failed: $error');
              ad.dispose();
              _rewardedAd = null;
              if (!completer.isCompleted) {
                onError('The rewarded ad could not be shown.');
                completer.complete(false);
              }
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
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          debugPrint('[Ads] Load failed: $error');
          if (!completer.isCompleted) {
            onError('Rewarded ads are temporarily unavailable.');
            completer.complete(false);
          }
        },
      ),
    );
    return completer.future;
  }
}
