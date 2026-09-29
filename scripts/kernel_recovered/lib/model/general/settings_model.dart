// To parse this JSON data, do
//
//     final settingModel = settingModelFromJson(jsonString);

import 'dart:convert';

import 'package:shortzz/model/user_model/user_model.dart';

SettingModel settingModelFromJson(String str) =>
    SettingModel.fromJson(json.decode(str));

String settingModelToJson(SettingModel data) => json.encode(data.toJson());

class SettingModel {
  bool? status;
  String? message;
  Setting? data;

  SettingModel({
    this.status,
    this.message,
    this.data,
  });

  factory SettingModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json["data"];
    Setting? parsed;
    if (rawData is Map) {
      parsed = Setting.fromJson(rawData.cast<String, dynamic>());
    } else {
      parsed = Setting.fromJson(json);
    }
    return SettingModel(
      status: json["status"],
      message: json["message"],
      data: parsed,
    );
  }

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class Setting {
  int? id;
  String? appName;
  String? currency;
  double? coinValue;
  int? minRedeemCoins;
  int? minRedeemCoinsFirst;
  int? registrationBonusStatus;
  int? registrationBonusAmount;
  int? referralBonusStatus;
  int? referralBonusAmount;
  int? minFollowersForLive;
  String? admobBanner;
  String? admobInt;
  String? admobRewarded;
  String? admobBannerIos;
  String? admobIntIos;
  String? admobRewardedIos;
  int? admobAndroidStatus;
  int? admobIosStatus;
  int? maxUploadDaily;
  int? maxStoryDaily;
  int? maxCommentDaily;
  int? maxCommentReplyDaily;
  int? maxPostPins;
  int? maxCommentPins;
  int? maxImagesPerPost;
  int? maxUserLinks;
  int? liveMinViewers;
  int? liveTimeout;
  int? liveBattle;
  int? liveDummyShow;
  String? liveProvider;
  String? livekitWsUrl;
  String? livekitApiKey;
  String? livekitApiSecret;
  bool? arManagerEnabled;
  String? arApiBaseUrl;
  String? activeArProvider;
  int? isCompress;
  int? isDeepAr;
  String? cameraEngine;
  int? isWithdrawalOn;
  String? helpMail;
  int? isContentModeration;
  String? sightEngineApiUser;
  String? sightEngineApiSecret;
  String? sightEngineImageWorkflowId;
  String? sightEngineVideoWorkflowId;
  int? gifSupport;
  String? giphyKey;
  int? watermarkStatus;
  String? watermarkImage;
  String? privacyPolicy;
  String? termsOfUses;
  String? placeApiAccessToken;
  String? deeparAndroidKey;
  String? deeparIOSKey;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? itemBaseUrl;
  List<Language>? languages;
  List<OnBoarding>? onBoarding;
  List<CoinPackage>? coinPackages;
  List<AdWalletPackage>? adWalletPackages;
  List<RedeemGateway>? redeemGateways;
  List<Gift>? gifts;
  List<MusicCategory>? musicCategories;
  List<UserLevel>? userLevels;
  List<DummyLive>? dummyLives;
  AppOpenPopup? appOpenPopup;
  List<ReportReason>? reportReason;
  List<DeepARFilters>? deepARFilters;
  List<LutItem>? luts;
  Gateways? gateways;
  String? razorpayKeyId;
  String? cashfreeAppId;
  String? cashfreeEndpoint;

  Setting({
    this.id,
    this.appName,
    this.currency,
    this.coinValue,
    this.minRedeemCoins,
    this.minRedeemCoinsFirst,
    this.minFollowersForLive,
    this.registrationBonusStatus,
    this.registrationBonusAmount,
    this.referralBonusStatus,
    this.referralBonusAmount,
    this.admobBanner,
    this.admobInt,
    this.admobRewarded,
    this.admobBannerIos,
    this.admobIntIos,
    this.admobRewardedIos,
    this.admobAndroidStatus,
    this.admobIosStatus,
    this.maxUploadDaily,
    this.maxStoryDaily,
    this.maxCommentDaily,
    this.maxCommentReplyDaily,
    this.maxPostPins,
    this.maxCommentPins,
    this.maxImagesPerPost,
    this.maxUserLinks,
    this.liveMinViewers,
    this.liveTimeout,
    this.liveBattle,
    this.liveDummyShow,
    this.liveProvider,
    this.livekitWsUrl,
    this.livekitApiKey,
    this.livekitApiSecret,
    this.arManagerEnabled,
    this.arApiBaseUrl,
    this.activeArProvider,
    this.isCompress,
    this.isDeepAr,
    this.cameraEngine,
    this.isWithdrawalOn,
    this.helpMail,
    this.isContentModeration,
    this.sightEngineApiUser,
    this.sightEngineApiSecret,
    this.sightEngineImageWorkflowId,
    this.sightEngineVideoWorkflowId,
    this.gifSupport,
    this.giphyKey,
    this.watermarkStatus,
    this.watermarkImage,
    this.privacyPolicy,
    this.termsOfUses,
    this.placeApiAccessToken,
    this.itemBaseUrl,
    this.deeparAndroidKey,
    this.deeparIOSKey,
    this.razorpayKeyId,
    this.cashfreeAppId,
    this.cashfreeEndpoint,
    this.createdAt,
    this.updatedAt,
    this.languages,
    this.onBoarding,
    this.coinPackages,
    this.adWalletPackages,
    this.redeemGateways,
    this.gifts,
    this.musicCategories,
    this.userLevels,
    this.dummyLives,
    this.appOpenPopup,
    this.reportReason,
    this.deepARFilters,
    this.luts,
    this.gateways,
  });

  static bool? _parseBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v.toInt() == 1;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
      if (s == '0' || s == 'false' || s == 'no') return false;
    }
    return null;
  }

  factory Setting.fromJson(Map<String, dynamic> json) => Setting(
        id: json["id"],
        appName: json["app_name"],
        currency: json["currency"],
        registrationBonusStatus: json["registration_bonus_status"],
        registrationBonusAmount: json["registration_bonus_amount"],
        referralBonusStatus: json["referral_bonus_status"] ??
            json["referralBonusStatus"] ??
            json["refer_bonus_status"] ??
            json["referBonusStatus"] ??
            json["ref_bonus_status"] ??
            json["refBonusStatus"],
        referralBonusAmount: json["referral_bonus_amount"] ??
            json["referralBonusAmount"] ??
            json["referral_bonus"] ??
            json["referralBonus"] ??
            json["refer_bonus_amount"] ??
            json["referBonusAmount"] ??
            json["refer_bonus"] ??
            json["referBonus"] ??
            json["ref_bonus_amount"] ??
            json["refBonusAmount"] ??
            json["ref_bonus"] ??
            json["refBonus"],
        coinValue: json["coin_value"]?.toDouble(),
        minRedeemCoins: json["min_redeem_coins"],
        minRedeemCoinsFirst: json["min_redeem_coins_first"],
        minFollowersForLive: json["min_followers_for_live"],
        admobBanner: json["admob_banner"] ?? json["admob_banner_android"],
        admobInt: json["admob_int"] ?? json["admob_interstitial_android"],
        admobRewarded: json["admob_rewarded"] ?? json["admob_rewarded_android"],
        admobBannerIos: json["admob_banner_ios"],
        admobIntIos: json["admob_int_ios"] ?? json["admob_interstitial_ios"],
        admobRewardedIos: json["admob_rewarded_ios"],
        admobAndroidStatus: json["admob_android_status"],
        admobIosStatus: json["admob_ios_status"],
        maxUploadDaily: json["max_upload_daily"],
        maxStoryDaily: json["max_story_daily"],
        maxCommentDaily: json["max_comment_daily"],
        maxCommentReplyDaily: json["max_comment_reply_daily"],
        maxPostPins: json["max_post_pins"],
        maxCommentPins: json["max_comment_pins"],
        maxImagesPerPost: json["max_images_per_post"],
        maxUserLinks: json["max_user_links"],
        liveMinViewers: json["live_min_viewers"],
        liveTimeout: json["live_timeout"],
        liveBattle: json["live_battle"],
        liveDummyShow: json["live_dummy_show"],
        liveProvider: json["live_provider"]?.toString().trim().toLowerCase(),
        livekitWsUrl: (json['livekit_ws_url'] ??
                json['livekit_url'] ??
                json['livekitWsUrl'])
            ?.toString(),
        livekitApiKey:
            (json['livekit_api_key'] ?? json['livekitApiKey'])?.toString(),
        livekitApiSecret:
            (json['livekit_api_secret'] ?? json['livekitApiSecret'])
                ?.toString(),
        arManagerEnabled:
            _parseBool(json['ar_manager_enabled'] ?? json['arManagerEnabled']),
        arApiBaseUrl:
            (json['ar_api_base_url'] ?? json['arApiBaseUrl'])?.toString(),
        activeArProvider:
            (json['active_ar_provider'] ?? json['activeArProvider'])
                ?.toString()
                .trim()
                .toLowerCase(),
        isCompress: json["is_compress"],
        isDeepAr: json["is_deepAR"],
        cameraEngine: (json['camera_engine'] ?? json['cameraEngine'])
            ?.toString()
            .trim()
            .toLowerCase(),
        isWithdrawalOn: json["is_withdrawal_on"],
        helpMail: json["help_mail"],
        isContentModeration: json["is_content_moderation"],
        sightEngineApiUser: json["sight_engine_api_user"],
        sightEngineApiSecret: json["sight_engine_api_secret"],
        sightEngineImageWorkflowId: json["sight_engine_image_workflow_id"],
        sightEngineVideoWorkflowId: json["sight_engine_video_workflow_id"],
        gifSupport: json["gif_support"],
        giphyKey: json["giphy_key"],
        watermarkStatus: json["watermark_status"],
        watermarkImage: json["watermark_image"],
        privacyPolicy: json["privacy_policy"],
        termsOfUses: json["terms_of_uses"],
        placeApiAccessToken: json["place_api_access_token"],
        itemBaseUrl: (json["itemBaseUrl"] ??
                json["item_base_url"] ??
                json["itemBaseURL"] ??
                json["base_url"] ??
                json["baseUrl"])
            ?.toString(),
        deeparAndroidKey: json["deepar_android_key"],
        deeparIOSKey: json["deepar_iOS_key"],
        razorpayKeyId: json["razorpay_key_id"] ?? json["razorpayKeyId"],
        cashfreeAppId: json["cashfree_app_id"] ?? json["cashfreeAppId"],
        cashfreeEndpoint: json["cashfree_endpoint"] ?? json["cashfreeEndpoint"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        languages: json["languages"] == null
            ? []
            : List<Language>.from(
                json["languages"]?.map((x) => Language.fromJson(x))),
        onBoarding: json["onBoarding"] == null
            ? []
            : List<OnBoarding>.from(
                json["onBoarding"]?.map((x) => OnBoarding.fromJson(x))),
        coinPackages: () {
          final raw = json["coinPackages"] ??
              json["coin_packages"] ??
              json["coin_packages_list"];
          dynamic list = raw;
          if (list is Map) {
            list = list['coinPackages'] ??
                list['coin_packages'] ??
                list['data'] ??
                list['items'];
          }
          if (list is! List) return <CoinPackage>[];
          return List<CoinPackage>.from(
              list.map((x) => CoinPackage.fromJson(x)));
        }(),
        adWalletPackages: () {
          final raw = json['adWalletPackages'] ??
              json['adsWalletPackages'] ??
              json['ad_wallet_packages'] ??
              json['ads_wallet_packages'] ??
              json['adWalletPackageList'] ??
              json['ad_wallet_package_list'] ??
              json['ad_wallet_packages_list'] ??
              json['ad_wallet_plans'] ??
              json['ads_wallet_plans'] ??
              json['adWalletPlans'] ??
              json['adsWalletPlans'];
          dynamic list = raw;
          if (list is Map) {
            dynamic next = list['adWalletPackages'] ??
                list['adsWalletPackages'] ??
                list['ad_wallet_packages'] ??
                list['ads_wallet_packages'] ??
                list['data'] ??
                list['items'];

            // Some backends return: { data: { data: [...] } }
            if (next is Map) {
              next = next['data'] ?? next['items'] ?? next['list'] ?? next['packages'];
            }

            list = next;
          }
          if (list is! List) return <AdWalletPackage>[];
          return List<AdWalletPackage>.from(
            list.map((x) => AdWalletPackage.fromJson(x)),
          );
        }(),
        redeemGateways: json["redeemGateways"] == null
            ? []
            : List<RedeemGateway>.from(
                json["redeemGateways"]?.map((x) => RedeemGateway.fromJson(x))),
        gifts: json["gifts"] == null
            ? []
            : List<Gift>.from(json["gifts"]?.map((x) => Gift.fromJson(x))),
        musicCategories: json["musicCategories"] == null
            ? []
            : List<MusicCategory>.from(
                json["musicCategories"]?.map((x) => MusicCategory.fromJson(x))),
        userLevels: json["userLevels"] == null
            ? []
            : List<UserLevel>.from(
                json["userLevels"]?.map((x) => UserLevel.fromJson(x))),
        dummyLives: json["dummyLives"] == null
            ? []
            : List<DummyLive>.from(
                json["dummyLives"]?.map((x) => DummyLive.fromJson(x))),
        appOpenPopup: json['app_open_popup'] == null
            ? null
            : AppOpenPopup.fromJson(
                (json['app_open_popup'] as Map).cast<String, dynamic>(),
              ),
        reportReason: json["reportReasons"] == null
            ? []
            : List<ReportReason>.from(
                json["reportReasons"]?.map((x) => ReportReason.fromJson(x))),
        deepARFilters: json["deepARFilters"] == null
            ? []
            : List<DeepARFilters>.from(
                json["deepARFilters"]?.map((x) => DeepARFilters.fromJson(x))),
        luts: () {
          final raw = json['luts'];
          if (raw is List) {
            return raw
                .whereType<Map>()
                .map((e) => LutItem.fromJson(e.cast<String, dynamic>()))
                .toList();
          }
          return <LutItem>[];
        }(),
        gateways: json["gateways"] == null
            ? null
            : Gateways.fromJson(json["gateways"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "app_name": appName,
        "currency": currency,
        "registration_bonus_status": registrationBonusStatus,
        "registration_bonus_amount": registrationBonusAmount,
        "referral_bonus_status": referralBonusStatus,
        "referral_bonus_amount": referralBonusAmount,
        "coin_value": coinValue,
        "min_redeem_coins": minRedeemCoins,
        "min_redeem_coins_first": minRedeemCoinsFirst,
        "min_followers_for_live": minFollowersForLive,
        "admob_banner": admobBanner,
        "admob_int": admobInt,
        "admob_rewarded": admobRewarded,
        "admob_banner_ios": admobBannerIos,
        "admob_int_ios": admobIntIos,
        "admob_rewarded_ios": admobRewardedIos,
        "admob_android_status": admobAndroidStatus,
        "admob_ios_status": admobIosStatus,
        "max_upload_daily": maxUploadDaily,
        "max_story_daily": maxStoryDaily,
        "max_comment_daily": maxCommentDaily,
        "max_comment_reply_daily": maxCommentReplyDaily,
        "max_post_pins": maxPostPins,
        "max_comment_pins": maxCommentPins,
        "max_images_per_post": maxImagesPerPost,
        "max_user_links": maxUserLinks,
        "live_min_viewers": liveMinViewers,
        "live_timeout": liveTimeout,
        "live_battle": liveBattle,
        "live_dummy_show": liveDummyShow,
        "live_provider": liveProvider,
        "livekit_ws_url": livekitWsUrl,
        "livekit_api_key": livekitApiKey,
        "livekit_api_secret": livekitApiSecret,
        "ar_manager_enabled": arManagerEnabled,
        "ar_api_base_url": arApiBaseUrl,
        "active_ar_provider": activeArProvider,
        "is_compress": isCompress,
        "is_deepAR": isDeepAr,
        "camera_engine": cameraEngine,
        "is_withdrawal_on": isWithdrawalOn,
        "help_mail": helpMail,
        "is_content_moderation": isContentModeration,
        "sight_engine_api_user": sightEngineApiUser,
        "sight_engine_api_secret": sightEngineApiSecret,
        "sight_engine_image_workflow_id": sightEngineImageWorkflowId,
        "sight_engine_video_workflow_id": sightEngineVideoWorkflowId,
        "gif_support": gifSupport,
        "giphy_key": giphyKey,
        "watermark_status": watermarkStatus,
        "watermark_image": watermarkImage,
        "privacy_policy": privacyPolicy,
        "terms_of_uses": termsOfUses,
        "place_api_access_token": placeApiAccessToken,
        "deepar_android_key": deeparAndroidKey,
        "deepar_iOS_key": deeparIOSKey,
        "razorpay_key_id": razorpayKeyId,
        "cashfree_app_id": cashfreeAppId,
        "cashfree_endpoint": cashfreeEndpoint,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "item_base_url": itemBaseUrl,
        "languages": languages?.map((x) => x.toJson()).toList(),
        "onBoarding": onBoarding?.map((x) => x.toJson()).toList(),
        "coinPackages": coinPackages?.map((x) => x.toJson()).toList(),
        "adWalletPackages": adWalletPackages?.map((x) => x.toJson()).toList(),
        "redeemGateways": redeemGateways?.map((x) => x.toJson()).toList(),
        "gifts": gifts?.map((x) => x.toJson()).toList(),
        "musicCategories": musicCategories?.map((x) => x.toJson()).toList(),
        "userLevels": userLevels?.map((x) => x.toJson()).toList(),
        "dummyLives": dummyLives?.map((x) => x.toJson()).toList(),
        "appOpenPopup": appOpenPopup?.toJson(),
        "reportReason": reportReason?.map((x) => x.toJson()).toList(),
        "deepARFilters": deepARFilters?.map((x) => x.toJson()).toList(),
        "luts": luts?.map((x) => x.toJson()).toList(),
        "gateways": gateways?.toJson(),
      };
}

class Gateways {
  bool? razorpay;
  bool? cashfree;
  bool? paypal;
  bool? stripe;

  Gateways({
    this.razorpay,
    this.cashfree,
    this.paypal,
    this.stripe,
  });

  factory Gateways.fromJson(Map<String, dynamic> json) => Gateways(
        razorpay: Setting._parseBool(json["razorpay"]),
        cashfree: Setting._parseBool(json["cashfree"]),
        paypal: Setting._parseBool(json["paypal"]),
        stripe: Setting._parseBool(json["stripe"]),
      );

  Map<String, dynamic> toJson() => {
        "razorpay": razorpay,
        "cashfree": cashfree,
        "paypal": paypal,
        "stripe": stripe,
      };
}

class LutItem {
  LutItem({
    this.id,
    this.title,
    this.image,
    this.file,
    this.createdAt,
    this.updatedAt,
  });

  int? id;
  String? title;
  String? image;
  String? file;
  String? createdAt;
  String? updatedAt;

  factory LutItem.fromJson(Map<String, dynamic> json) => LutItem(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse('${json['id']}'),
        title: json['title']?.toString(),
        image:
            (json['image'] ?? json['thumbnail'] ?? json['thumb'])?.toString(),
        file: (json['file'] ?? json['lut_file'] ?? json['lut'] ?? json['path'])
            ?.toString(),
        createdAt: json['created_at']?.toString(),
        updatedAt: json['updated_at']?.toString(),
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['title'] = title;
    map['image'] = image;
    map['file'] = file;
    map['created_at'] = createdAt;
    map['updated_at'] = updatedAt;
    return map;
  }
}

class AppOpenPopup {
  AppOpenPopup({
    this.id,
    this.title,
    this.description,
    this.ctaUrl,
    this.mediaUrl,
    this.frequencyJson,
  });

  int? id;
  String? title;
  String? description;
  String? ctaUrl;
  String? mediaUrl;
  String? frequencyJson;

  factory AppOpenPopup.fromJson(Map<String, dynamic> json) => AppOpenPopup(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse('${json['id']}'),
        title: json['title']?.toString(),
        description: json['description']?.toString(),
        ctaUrl: json['cta_url']?.toString(),
        mediaUrl: json['media_url']?.toString(),
        frequencyJson: json['frequency_json']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'cta_url': ctaUrl,
        'media_url': mediaUrl,
        'frequency_json': frequencyJson,
      };
}

class AdWalletPackage {
  int? id;
  String? name;
  String? image;
  int? status;
  int? amount;
  int? price;
  String? currency;
  String? androidProductId;
  String? iosProductId;
  DateTime? createdAt;
  DateTime? updatedAt;

  AdWalletPackage({
    this.id,
    this.name,
    this.image,
    this.status,
    this.amount,
    this.price,
    this.currency,
    this.androidProductId,
    this.iosProductId,
    this.createdAt,
    this.updatedAt,
  });

  factory AdWalletPackage.fromJson(Map<String, dynamic> json) =>
      AdWalletPackage(
        id: json["id"],
        name: json['name']?.toString() ?? json['title']?.toString(),
        image: json["image"],
        status: json["status"] is bool
            ? ((json["status"] as bool) ? 1 : 0)
            : json["status"],
        amount: () {
          final dynamic amountRaw =
              json['amount'] ?? json['price'] ?? json['usd'] ?? json['value'];
          if (amountRaw is num) return amountRaw.toInt();
          return int.tryParse('$amountRaw');
        }(),
        price: json["price"] is num
            ? (json["price"] as num).toInt()
            : int.tryParse('${json["price"]}'),
        currency: json['currency']?.toString(),
        androidProductId: json['android_product_id']?.toString() ??
            json['androidProductId']?.toString() ??
            json['play_store_product_id']?.toString() ??
            json['playstore_product_id']?.toString() ??
            json['play_product_id']?.toString() ??
            json['playProductId']?.toString(),
        iosProductId: json['ios_product_id']?.toString() ??
            json['iosProductId']?.toString() ??
            json['app_store_product_id']?.toString() ??
            json['appstore_product_id']?.toString() ??
            json['app_store_product_id']?.toString() ??
            json['appStoreProductId']?.toString(),
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "image": image,
        "status": status,
        "amount": amount,
        "price": price,
        "currency": currency,
        "android_product_id": androidProductId,
        "ios_product_id": iosProductId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class CoinPackage {
  int? id;
  String? image;
  int? status;
  int? coinAmount;
  int? coinPlanPrice;
  String? playStoreProductId;
  String? appstoreProductId;
  int? price;
  DateTime? createdAt;
  DateTime? updatedAt;

  CoinPackage({
    this.id,
    this.image,
    this.status,
    this.coinAmount,
    this.coinPlanPrice,
    this.playStoreProductId,
    this.appstoreProductId,
    this.createdAt,
    this.updatedAt,
  });

  factory CoinPackage.fromJson(Map<String, dynamic> json) => CoinPackage(
        id: json["id"],
        image: json["image"],
        status: json["status"] is bool
            ? ((json["status"] as bool) ? 1 : 0)
            : json["status"],
        coinAmount: json["coin_amount"] is num
            ? (json["coin_amount"] as num).toInt()
            : int.tryParse('${json["coin_amount"]}'),
        coinPlanPrice: json["coin_plan_price"] is num
            ? (json["coin_plan_price"] as num).toInt()
            : int.tryParse('${json["coin_plan_price"]}'),
        playStoreProductId: json["playstore_product_id"]?.toString() ??
            json["play_store_product_id"]?.toString() ??
            json["android_product_id"]?.toString() ??
            json["androidProductId"]?.toString(),
        appstoreProductId: json["appstore_product_id"]?.toString() ??
            json["app_store_product_id"]?.toString() ??
            json["ios_product_id"]?.toString() ??
            json["iosProductId"]?.toString(),
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "image": image,
        "status": status,
        "coin_amount": coinAmount,
        "coin_plan_price": coinPlanPrice,
        "playstore_product_id": playStoreProductId,
        "appstore_product_id": appstoreProductId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class DummyLive {
  int? id;
  int? status;
  String? title;
  int? userId;
  String? link;
  DateTime? createdAt;
  DateTime? updatedAt;
  User? user;

  DummyLive({
    this.id,
    this.status,
    this.title,
    this.userId,
    this.link,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  factory DummyLive.fromJson(Map<String, dynamic> json) => DummyLive(
        id: json["id"],
        status: json["status"],
        title: json["title"],
        userId: json["user_id"],
        link: json["link"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        user: json["user"] == null ? null : User.fromJson(json["user"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "status": status,
        "title": title,
        "user_id": userId,
        "link": link,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "user": user?.toJson(),
      };
}

class Gift {
  int? id;
  int? coinPrice;
  String? image;
  DateTime? createdAt;
  DateTime? updatedAt;

  Gift({
    this.id,
    this.coinPrice,
    this.image,
    this.createdAt,
    this.updatedAt,
  });

  factory Gift.fromJson(Map<String, dynamic> json) => Gift(
        id: json["id"],
        coinPrice: json["coin_price"],
        image: json["image"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "coin_price": coinPrice,
        "image": image,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class Language {
  int? id;
  String? code;
  String? title;
  String? localizedTitle;
  String? csvFile;
  int? status;
  int? isDefault;
  DateTime? createdAt;
  DateTime? updatedAt;

  Language({
    this.id,
    this.code,
    this.title,
    this.localizedTitle,
    this.csvFile,
    this.status,
    this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  factory Language.fromJson(Map<String, dynamic> json) => Language(
        id: json["id"],
        code: json["code"],
        title: json["title"],
        localizedTitle: json["localized_title"],
        csvFile: json["csv_file"],
        status: json["status"],
        isDefault: json["is_default"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "code": code,
        "title": title,
        "localized_title": localizedTitle,
        "csv_file": csvFile,
        "status": status,
        "is_default": isDefault,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class MusicCategory {
  int? id;
  String? name;
  String? image;
  int? isDeleted;
  DateTime? createdAt;
  DateTime? updatedAt;
  int? musicsCount;

  MusicCategory({
    this.id,
    this.name,
    this.image,
    this.isDeleted,
    this.createdAt,
    this.updatedAt,
    this.musicsCount,
  });

  factory MusicCategory.fromJson(Map<String, dynamic> json) => MusicCategory(
        id: json["id"],
        name: json["name"],
        image: json["image"],
        isDeleted: json["is_deleted"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        musicsCount: json["musics_count"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "image": image,
        "is_deleted": isDeleted,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "musics_count": musicsCount,
      };
}

class OnBoarding {
  int? id;
  int? position;
  String? image;
  String? title;
  String? description;
  DateTime? createdAt;
  DateTime? updatedAt;

  OnBoarding({
    this.id,
    this.position,
    this.image,
    this.title,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory OnBoarding.fromJson(Map<String, dynamic> json) => OnBoarding(
        id: json["id"],
        position: json["position"],
        image: json["image"],
        title: json["title"],
        description: json["description"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "position": position,
        "image": image,
        "title": title,
        "description": description,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class RedeemGateway {
  int? id;
  String? title;
  DateTime? createdAt;
  DateTime? updatedAt;

  RedeemGateway({
    this.id,
    this.title,
    this.createdAt,
    this.updatedAt,
  });

  factory RedeemGateway.fromJson(Map<String, dynamic> json) => RedeemGateway(
        id: json["id"],
        title: json["title"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class UserLevel {
  int? id;
  int? level;
  int coinsCollection;
  DateTime? createdAt;
  DateTime? updatedAt;

  UserLevel({
    this.id,
    this.level,
    this.coinsCollection = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory UserLevel.fromJson(Map<String, dynamic> json) => UserLevel(
        id: json["id"],
        level: json["level"],
        coinsCollection: json["coins_collection"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "level": level,
        "coins_collection": coinsCollection,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class ReportReason {
  int? id;
  String? title;
  String? createdAt;
  String? updatedAt;

  ReportReason({this.id, this.title, this.createdAt, this.updatedAt});

  ReportReason.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
  }
}

class DeepARFilters {
  DeepARFilters({
    this.id,
    this.title,
    this.image,
    this.filterFile,
    this.createdAt,
    this.updatedAt,
  });

  DeepARFilters.fromJson(dynamic json) {
    id = json['id'];
    title = json['title'];
    image = json['image'];
    filterFile = json['filter_file'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  int? id;
  String? title;
  String? image;
  String? filterFile;
  String? createdAt;
  String? updatedAt;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['title'] = title;
    map['image'] = image;
    map['filter_file'] = filterFile;
    map['created_at'] = createdAt;
    map['updated_at'] = updatedAt;
    return map;
  }
}
