import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/ads_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/logger.dart';

class AdsController extends BaseController {
  InterstitialAd? interstitialAd;
  RewardedAd? rewardedAd;

  @override
  void onInit() {
    // Use print for visibility - log() might be filtered
    Loggers.info('[AdsController] ========================================');
    Loggers.info('[AdsController] onInit CALLED - STARTING AD LOAD');
    Loggers.info('[AdsController] isPlusActive: ${SessionManager.instance.isPlusActive.value}');
    Loggers.info('[AdsController] ========================================');
    
    super.onInit();
    loadInterstitialAd(); // preload when controller initializes
    loadRewardedAd(); // preload rewarded ad too
  }

  Future<void> showInterstitialAdIfAvailable({bool isPopScope = false}) async {
    log('[AdsController] showInterstitialAdIfAvailable called');
    final setting = SessionManager.instance.getSettings();

    // Check ad status for platform
    final isAdDisabled =
        (Platform.isAndroid && setting?.admobAndroidStatus == 0) ||
            (Platform.isIOS && setting?.admobIosStatus == 0);

    log('[AdsController] isAdDisabled: $isAdDisabled, isPlusActive: ${SessionManager.instance.isPlusActive.value}, interstitialAd: ${interstitialAd != null}');

    // Early return if ads are disabled or user is subscribed or ad is not loaded
    if (isAdDisabled || SessionManager.instance.isPlusActive.value == 1 || interstitialAd == null) {
      log('[AdsController] Cannot show interstitial - blocked');
      if (!isPopScope) {
        Get.back();
      }
      return;
    }
    if (!isPopScope) {
      Get.back();
    }
    log('[AdsController] Showing interstitial ad...');
    await interstitialAd!.show(); // Safe to use `!` after null check
  }

  Future<void> loadInterstitialAd() async {
    Loggers.info('[AdsController] loadInterstitialAd() CALLED');
    if (SessionManager.instance.isPlusActive.value == 1) {
      Loggers.info('[AdsController] Interstitial skipped: User has Plus');
      return;
    }

    Loggers.info('[AdsController] Calling AdsManager.instance.loadInterstitialAd...');
    AdsManager.instance.loadInterstitialAd(onAdLoaded: (ad) {
      Loggers.info('[AdsController] Interstitial ad loaded callback received!');
      interstitialAd = ad;

      interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          Loggers.info('[AdsController] Interstitial dismissed');
          ad.dispose();
          loadInterstitialAd(); // Reload for next time
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          Loggers.info('[AdsController] Interstitial failed to show: ${error.message}');
          ad.dispose();
          loadInterstitialAd();
        },
        onAdShowedFullScreenContent: (ad) {
          Loggers.info('[AdsController] Interstitial showed successfully');
        },
      );
    });
  }

  /// Load rewarded ad - FIXED: Returns Future that completes when ad is loaded or fails
  Future<void> loadRewardedAd() async {
    Loggers.info('[AdsController] loadRewardedAd() CALLED');
    if (SessionManager.instance.isPlusActive.value == 1) {
      Loggers.info('[AdsController] Rewarded skipped: User has Plus');
      return;
    }

    // If already loaded, don't reload
    if (rewardedAd != null) {
      Loggers.info('[AdsController] Rewarded ad already loaded, skipping');
      return;
    }

    Loggers.info('[AdsController] Calling AdsManager.instance.loadRewardedAd...');
    
    final completer = Completer<void>();
    
    AdsManager.instance.loadRewardedAd(onAdLoaded: (ad) {
      Loggers.info('[AdsController] Rewarded ad loaded callback received!');
      rewardedAd = ad;

      rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          Loggers.info('[AdsController] Rewarded dismissed');
          ad.dispose();
          rewardedAd = null;
          loadRewardedAd(); // Reload for next time
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          Loggers.info('[AdsController] Rewarded failed to show: ${error.message}');
          ad.dispose();
          rewardedAd = null;
          loadRewardedAd();
        },
        onAdShowedFullScreenContent: (ad) {
          Loggers.info('[AdsController] Rewarded showed successfully');
        },
      );
      
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    
    // Timeout after 5 seconds
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        Loggers.info('[AdsController] Rewarded ad load timed out');
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );
  }

  /// Show rewarded ad with proper callback tracking
  /// Returns: true if reward was earned, false otherwise
  /// FIXED: Now loads ad if not available instead of returning false immediately
  Future<bool> showRewardedAd({required Function(RewardItem) onRewardEarned}) async {
    Loggers.info('[AdsController] showRewardedAd called');
    
    // FIXED: Try to load ad if not available
    if (rewardedAd == null) {
      Loggers.info('[AdsController] No rewarded ad available, attempting to load...');
      await loadRewardedAd();
      
      // Wait a bit for ad to load
      await Future.delayed(const Duration(seconds: 1));
      
      // Check again after loading attempt
      if (rewardedAd == null) {
        Loggers.info('[AdsController] Failed to load ad, proceeding without reward');
        return false;
      }
    }
    
    final completer = Completer<bool>();
    bool rewardEarned = false;
    
    // Set up full screen content callback
    rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        Loggers.info('[AdsController] Rewarded ad showed successfully');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        Loggers.info('[AdsController] Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        rewardedAd = null;
        loadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        Loggers.info('[AdsController] Rewarded ad dismissed, rewardEarned=$rewardEarned');
        ad.dispose();
        rewardedAd = null;
        loadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
    );
    
    // Show the ad with onUserEarnedReward callback
    try {
      await rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          Loggers.info('[AdsController] User earned reward: ${reward.amount} ${reward.type}');
          rewardEarned = true;
          onRewardEarned(reward);
        },
      );
      
      Loggers.info('[AdsController] Ad show() returned, waiting for reward callback...');
    } catch (e) {
      Loggers.info('[AdsController] Error showing rewarded ad: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
    
    // Wait for either reward earned OR ad dismissed
    return completer.future.timeout(
      const Duration(minutes: 2), // Max 2 min wait (ad duration + buffer)
      onTimeout: () {
        Loggers.info('[AdsController] Rewarded ad timed out waiting for callback');
        return rewardEarned;
      },
    );
  }

  /// Show rewarded ad if available - LEGACY method, use showRewardedAd instead
  Future<void> showRewardedAdIfAvailable() async {
    log('[AdsController] showRewardedAdIfAvailable called');
    if (rewardedAd == null) {
      log('[AdsController] No rewarded ad available');
      return;
    }

    await rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      log('[AdsController] User earned reward: ${reward.amount} ${reward.type}');
      // NOTE: Reward the user here. Integrate with your coin/reward service.
    });
  }
}
