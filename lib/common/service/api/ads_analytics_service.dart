import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/model/ads/ads_analytics_model.dart';

class AdsAnalyticsService {
  AdsAnalyticsService._();

  static final AdsAnalyticsService instance = AdsAnalyticsService._();

  Future<AdsAnalyticsResponse> fetchMyAdsAnalytics() async {
    final AdsAnalyticsResponse model = await ApiService.instance.call(
      url: WebService.analytics.fetchMyAdsAnalytics,
      fromJson: AdsAnalyticsResponse.fromJson,
      param: const {},
    );
    final keys = model.data?.toJson().keys.map((e) => e.toString()).toList() ?? <String>[];
    keys.sort();
    Loggers.info('MyAdsAnalytics keys: $keys');
    return model;
  }
}
