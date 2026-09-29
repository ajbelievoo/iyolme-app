import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/api/platform_ads_service.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/ads/ad_estimate.dart';
import 'package:shortzz/model/general/status_model.dart';

class UserAdsService {
  UserAdsService._();

  static final UserAdsService instance = UserAdsService._();

  Future<AdEstimateResponse> getEstimate({
    required double budget,
    required int durationHours,
    required String placement,
    required String billing,
  }) async {
    final response = await ApiService.instance.call(
      url: WebService.userAds.estimate,
      fromJson: AdEstimateResponse.fromJson,
      param: {
        Params.budget: budget,
        Params.durationHours: durationHours,
        Params.placement: placement,
        Params.billing: billing,
      },
    );
    return response;
  }

  Future<StatusModel> createUserAdRequest({
    required String title,
    String? description,
    required String mediaPath,
    required String mediaType,
    required String placement,
    required String billing,
    required double budget,
    int? durationHours,
    String? ctaUrl,
    String? keywords,
    String? metadataJson,
  }) async {
    final param = {
      Params.title: title,
      if ((description ?? '').trim().isNotEmpty) Params.descriptionText: description,
      Params.mediaPath: mediaPath,
      Params.mediaType: mediaType,
      Params.placement: placement,
      Params.billing: billing,
      Params.budget: budget,
      if (durationHours != null) Params.durationHours: durationHours,
      if ((ctaUrl ?? '').trim().isNotEmpty) Params.ctaUrl: ctaUrl,
      if ((keywords ?? '').trim().isNotEmpty) 'keywords': keywords,
      if (metadataJson != null) Params.metadataJson: metadataJson,
      if (metadataJson != null) Params.metadata: metadataJson,
    };

    try {
      final StatusModel model = await ApiService.instance.call(
        url: WebService.userAds.createRequest,
        fromJson: StatusModel.fromJson,
        param: param,
      );
      return model;
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('URL Error: 404')) {
        rethrow;
      }
    }

    // Backward-compatible fallback
    return PlatformAdsService.instance.createAdRequest(
      placement: placement,
      title: title,
      description: description,
      mediaPath: mediaPath,
      mediaType: mediaType,
      billing: billing,
      budget: budget,
      durationHours: durationHours,
      ctaUrl: ctaUrl,
      metadataJson: metadataJson,
    );
  }

  Future<Map<String, dynamic>> listMyRequests() async {
    // Some backends expose this as GET, others as POST.
    try {
      final Map<String, dynamic> json = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.userAds.myRequests,
      );
      return json;
    } catch (_) {
      // fallthrough
    }

    try {
      final Map<String, dynamic> json = await ApiService.instance.call<Map<String, dynamic>>(
        url: WebService.userAds.myRequests,
        param: const <String, dynamic>{},
      );
      return json;
    } catch (_) {
      // fallthrough
    }

    // Legacy fallback (best-effort). Some backends used /ads/myRequests.
    final legacyUrl = WebService.platformAds.createAdRequest.replaceAll('createRequest', 'myRequests');
    try {
      final Map<String, dynamic> json = await ApiService.instance.get<Map<String, dynamic>>(
        url: legacyUrl,
      );
      return json;
    } catch (_) {
      // fallthrough
    }

    final Map<String, dynamic> json = await ApiService.instance.call<Map<String, dynamic>>(
      url: legacyUrl,
      param: const <String, dynamic>{},
    );
    return json;
  }

  Future<Map<String, dynamic>> getAdAnalytics({required int adId}) async {
    try {
      final Map<String, dynamic> json = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.userAds.analytics(adId),
      );

      final data = json['data'] ?? json['analytics'] ?? json['result'] ?? json;
      if (data is Map) {
        final keys = data.keys.map((e) => e.toString()).toList()..sort();
        Loggers.info('AdAnalytics keys(adId=$adId): $keys');
      } else {
        Loggers.info('AdAnalytics keys(adId=$adId): <non-map:${data.runtimeType}>');
      }
      return json;
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('URL Error: 404')) {
        rethrow;
      }
    }

    final Map<String, dynamic> json = await ApiService.instance.get<Map<String, dynamic>>(
      url: "${WebService.platformAds.createAdRequest.replaceAll('createRequest', 'analytics')}/$adId",
    );

    final data = json['data'] ?? json['analytics'] ?? json['result'] ?? json;
    if (data is Map) {
      final keys = data.keys.map((e) => e.toString()).toList()..sort();
      Loggers.info('AdAnalytics keys(adId=$adId): $keys');
    } else {
      Loggers.info('AdAnalytics keys(adId=$adId): <non-map:${data.runtimeType}>');
    }
    return json;
  }
}
