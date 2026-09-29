import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/admob_native_service.dart';
import 'package:shortzz/model/admob/admob_native_models.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/common/manager/logger.dart';

class AdsManager {
  AdsManager._();

  static final instance = AdsManager._();

  void loadBannerAd({required Function(Ad) onAdLoaded}) async {
    if (!kReleaseMode) return;
    Setting? setting = SessionManager.instance.getSettings();
    if (Platform.isAndroid && setting?.admobAndroidStatus == 0) {
      return;
    }
    if (Platform.isIOS && setting?.admobIosStatus == 0) {
      return;
    }
    BannerAd(
      adUnitId: Platform.isAndroid
          ? (setting?.admobBanner ?? '')
          : (setting?.admobBannerIos ?? ''),
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    ).load();
  }

  Future<void> loadInterstitialAd(
      {required Function(InterstitialAd) onAdLoaded}) async {
    Loggers.info('[AdsManager] loadInterstitialAd called');
    Setting? setting = SessionManager.instance.getSettings();
    Loggers.info('[AdsManager] Platform: ${Platform.isAndroid ? "Android" : "iOS"}, admobAndroidStatus: ${setting?.admobAndroidStatus}, admobIosStatus: ${setting?.admobIosStatus}');
    
    // Skip platform checks in debug mode
    if (kReleaseMode) {
      if (Platform.isAndroid && setting?.admobAndroidStatus == 0) {
        Loggers.info('[AdsManager] Interstitial blocked: Android ads disabled');
        return;
      }
      if (Platform.isIOS && setting?.admobIosStatus == 0) {
        Loggers.info('[AdsManager] Interstitial blocked: iOS ads disabled');
        return;
      }
    } else {
      Loggers.info('[AdsManager] Debug mode - skipping platform ad status check');
    }
    
    // Use AdMobNativeService config as fallback if SessionManager settings are empty
    String adUnitId;
    if (Platform.isAndroid) {
      adUnitId = setting?.admobInt?.isNotEmpty == true 
          ? setting!.admobInt! 
          : _getAdMobNativeConfig().interstitialAdUnitIdAndroid ?? '';
    } else {
      adUnitId = setting?.admobIntIos?.isNotEmpty == true 
          ? setting!.admobIntIos! 
          : _getAdMobNativeConfig().interstitialAdUnitIdIos ?? '';
    }
    
    Loggers.info('[AdsManager] Interstitial adUnitId: $adUnitId, isRelease: $kReleaseMode');
    
    if (adUnitId.isEmpty) {
      Loggers.info('[AdsManager] Interstitial ad unit ID is empty');
      return;
    }
    
    Loggers.info('[AdsManager] Loading interstitial ad...');
    await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            Loggers.info('[AdsManager] ✅ InterstitialAd loaded successfully!');
            onAdLoaded(ad);
          },
          onAdFailedToLoad: (LoadAdError error) {
            Loggers.info('[AdsManager] ❌ InterstitialAd failed to load: ${error.message}, code: ${error.code}');
          },
        ));
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd(
      {required Function(RewardedAd) onAdLoaded}) async {
    Loggers.info('[AdsManager] loadRewardedAd called');
    Setting? setting = SessionManager.instance.getSettings();
    Loggers.info('[AdsManager] Rewarded - Platform: ${Platform.isAndroid ? "Android" : "iOS"}, admobAndroidStatus: ${setting?.admobAndroidStatus}');
    
    // Skip platform checks in debug mode
    if (kReleaseMode) {
      if (Platform.isAndroid && setting?.admobAndroidStatus == 0) {
        Loggers.info('[AdsManager] Rewarded blocked: Android ads disabled');
        return;
      }
      if (Platform.isIOS && setting?.admobIosStatus == 0) {
        Loggers.info('[AdsManager] Rewarded blocked: iOS ads disabled');
        return;
      }
    } else {
      Loggers.info('[AdsManager] Debug mode - skipping platform ad status check for rewarded');
    }
    
    // Use AdMobNativeService config as fallback if SessionManager settings are empty
    String adUnitId;
    if (Platform.isAndroid) {
      adUnitId = setting?.admobRewarded?.isNotEmpty == true 
          ? setting!.admobRewarded! 
          : _getAdMobNativeConfig().rewardedAdUnitIdAndroid ?? '';
    } else {
      adUnitId = setting?.admobRewardedIos?.isNotEmpty == true 
          ? setting!.admobRewardedIos! 
          : _getAdMobNativeConfig().rewardedAdUnitIdIos ?? '';
    }
    
    Loggers.info('[AdsManager] Rewarded adUnitId: $adUnitId');
    
    if (adUnitId.isEmpty) {
      Loggers.info('[AdsManager] Rewarded ad unit ID is empty');
      return;
    }
    
    Loggers.info('[AdsManager] Loading rewarded ad...');
    await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            Loggers.info('[AdsManager] ✅ RewardedAd loaded successfully!');
            onAdLoaded(ad);
          },
          onAdFailedToLoad: (LoadAdError error) {
            Loggers.info('[AdsManager] ❌ RewardedAd failed to load: ${error.message}, code: ${error.code}');
          },
        ));
  }

  /// Get AdMobNativeConfig safely - returns empty config if service not initialized
  AdMobNativeConfig _getAdMobNativeConfig() {
    try {
      return AdMobNativeService.instance.config.value;
    } catch (e) {
      Loggers.info('[AdsManager] AdMobNativeService not initialized yet, using empty config');
      return AdMobNativeConfig();
    }
  }

  void requestConsentInfoUpdate() {
    if (!kReleaseMode) return;
    final params = ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
            debugGeography: DebugGeography.debugGeographyEea,
            testIdentifiers: ['D5E5A833CA124D2CD5E33A574AF9EA88']));
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          loadForm();
        }
      },
      (FormError error) {
        // Handle the error
      },
    );
  }

  void loadForm() {
    if (!kReleaseMode) return;
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((formError) {
            loadForm();
          });
        }
      },
      (FormError formError) {
        // Handle the error
      },
    );
  }
}
