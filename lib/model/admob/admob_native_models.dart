import 'dart:developer';
import 'dart:io';

/// Model for AdMob Native Ad configuration from backend
class AdMobNativeConfig {
  final bool isEnabled;
  final int adInterval;
  final String? nativeAdUnitIdAndroid;
  final String? nativeAdUnitIdIos;
  // Interstitial ad unit IDs
  final String? interstitialAdUnitIdAndroid;
  final String? interstitialAdUnitIdIos;
  // Rewarded ad unit IDs
  final String? rewardedAdUnitIdAndroid;
  final String? rewardedAdUnitIdIos;
  final int maxAdsPerSession;
  final int adRepeatIntervalMinutes;
  final bool testMode;

  AdMobNativeConfig({
    this.isEnabled = true, // Default enabled for testing
    this.adInterval = 3,   // Show ad every 3 posts
    this.nativeAdUnitIdAndroid,
    this.nativeAdUnitIdIos,
    // Interstitial
    this.interstitialAdUnitIdAndroid,
    this.interstitialAdUnitIdIos,
    // Rewarded
    this.rewardedAdUnitIdAndroid,
    this.rewardedAdUnitIdIos,
    this.maxAdsPerSession = 100,
    this.adRepeatIntervalMinutes = 0,
    this.testMode = false,  // Default to REAL ads, not test mode
  });

  factory AdMobNativeConfig.fromJson(Map<String, dynamic> json) {
    log('[AdMobNativeConfig] Parsing JSON: $json');
    final config = AdMobNativeConfig(
      isEnabled: json['is_admob_enabled'] == 1 || json['is_admob_enabled'] == true,
      adInterval: json['ad_interval'] ?? 5,
      // Native ads
      nativeAdUnitIdAndroid: json['admob_native_android'] ?? json['native_ad_unit_id_android'],
      nativeAdUnitIdIos: json['admob_native_ios'] ?? json['native_ad_unit_id_ios'],
      // Interstitial ads
      interstitialAdUnitIdAndroid: json['admob_interstitial_android'] ?? json['admob_int_android'],
      interstitialAdUnitIdIos: json['admob_interstitial_ios'] ?? json['admob_int_ios'],
      // Rewarded ads
      rewardedAdUnitIdAndroid: json['admob_rewarded_android'] ?? json['admob_rewarded'],
      rewardedAdUnitIdIos: json['admob_rewarded_ios'],
      maxAdsPerSession: json['max_ads_per_session'] ?? 10,
      adRepeatIntervalMinutes: json['ad_repeat_interval_minutes'] ?? 5,
      testMode: json['test_mode'] == 1 || json['test_mode'] == true,
    );
    log('[AdMobNativeConfig] Parsed: nativeAndroid=${config.nativeAdUnitIdAndroid}, nativeIos=${config.nativeAdUnitIdIos}, interstitialAndroid=${config.interstitialAdUnitIdAndroid}, rewardedAndroid=${config.rewardedAdUnitIdAndroid}, testMode=${config.testMode}');
    return config;
  }

  String? get nativeAdUnitId {
    if (Platform.isAndroid) {
      return nativeAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return nativeAdUnitIdIos;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'is_admob_enabled': isEnabled,
      'ad_interval': adInterval,
      'native_ad_unit_id_android': nativeAdUnitIdAndroid,
      'native_ad_unit_id_ios': nativeAdUnitIdIos,
      'admob_interstitial_android': interstitialAdUnitIdAndroid,
      'admob_interstitial_ios': interstitialAdUnitIdIos,
      'admob_rewarded_android': rewardedAdUnitIdAndroid,
      'admob_rewarded_ios': rewardedAdUnitIdIos,
      'max_ads_per_session': maxAdsPerSession,
      'ad_repeat_interval_minutes': adRepeatIntervalMinutes,
      'test_mode': testMode,
    };
  }
}

/// Model for tracking AdMob ad events
class AdMobAdEvent {
  final String eventType;
  final String? adUnitId;
  final String? placement;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AdMobAdEvent({
    required this.eventType,
    this.adUnitId,
    this.placement,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'ad_unit_id': adUnitId,
      'placement': placement,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Wrapper for feed items that can be either a Post or an AdMob Ad
class FeedItem {
  final FeedItemType type;
  final dynamic data;
  final int? adIndex;

  FeedItem.post(this.data)
      : type = FeedItemType.post,
        adIndex = null;

  FeedItem.adMobNative(this.adIndex)
      : type = FeedItemType.adMobNative,
        data = null;

  FeedItem.backendAd(this.data)
      : type = FeedItemType.backendAd,
        adIndex = null;

  FeedItem.scratchCard()
      : type = FeedItemType.scratchCard,
        data = null,
        adIndex = null;

  bool get isPost => type == FeedItemType.post;
  bool get isAdMobNative => type == FeedItemType.adMobNative;
  bool get isBackendAd => type == FeedItemType.backendAd;
  bool get isScratchCard => type == FeedItemType.scratchCard;
  bool get isAnyAd => isAdMobNative || isBackendAd;
}

enum FeedItemType {
  post,
  adMobNative,
  backendAd,
  scratchCard,
}
