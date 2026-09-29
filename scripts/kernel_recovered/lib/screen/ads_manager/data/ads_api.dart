import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/screen/ads_manager/data/ads_dto.dart';

class AdsManagerApi {
  AdsManagerApi._();

  static final AdsManagerApi instance = AdsManagerApi._();

  Future<AdsManagerCampaignCreateResponseDto> createCampaign({
    required AdsManagerCampaignCreateRequestDto request,
  }) async {
    final json = await ApiService.instance.call<Map<String, dynamic>>(
      url: WebService.adsManager.createCampaign,
      param: request.toJson(),
    );
    return AdsManagerCampaignCreateResponseDto.fromJson(json);
  }

  Future<AdsManagerCampaignListResponseDto> listCampaigns({int? lastItemId}) async {
    final Map<String, dynamic> json =
        await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.adsManager.listCampaigns,
      param: <String, dynamic>{
        if (lastItemId != null) 'lastItemId': lastItemId,
      },
    );
    return AdsManagerCampaignListResponseDto.fromJson(json);
  }

  Future<AdsManagerCampaignAnalyticsDto> fetchCampaignAnalytics({
    required int campaignId,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.adsManager.campaignAnalytics(campaignId),
      param: <String, dynamic>{},
    );
    return AdsManagerCampaignAnalyticsDto.fromJson(json);
  }

  Future<AdsManagerOverallAnalyticsResponseDto> fetchOverallAnalytics({
    required String range,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.adsManager.overallAnalytics,
      param: <String, dynamic>{
        'range': range,
      },
    );
    return AdsManagerOverallAnalyticsResponseDto.fromJson(json);
  }

  Future<AdsManagerWalletDto> fetchWallet() async {
    final Map<String, dynamic> json =
        await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.adsManager.wallet,
      param: <String, dynamic>{},
    );
    return AdsManagerWalletDto.fromJson(json);
  }

  Future<AdsManagerActionResponseDto> topUpAdsWallet({
    required Map<String, dynamic> payload,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.call<Map<String, dynamic>>(
      url: WebService.adsManager.walletTopUp,
      param: payload,
    );
    return AdsManagerActionResponseDto.fromJson(json);
  }

  Future<AdsManagerBoostSuggestedBudgetDto> fetchBoostSuggestedBudget({
    required int postId,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.get<Map<String, dynamic>>(
      url: WebService.adsManager.boostSuggestedBudget,
      param: <String, dynamic>{
        'postId': postId,
      },
    );
    return AdsManagerBoostSuggestedBudgetDto.fromJson(json);
  }

  Future<AdsManagerActionResponseDto> pauseCampaign({
    required int campaignId,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.call<Map<String, dynamic>>(
      url: WebService.adsManager.pauseCampaign,
      param: <String, dynamic>{
        'campaignId': campaignId,
      },
    );
    return AdsManagerActionResponseDto.fromJson(json);
  }

  Future<AdsManagerActionResponseDto> resumeCampaign({
    required int campaignId,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.call<Map<String, dynamic>>(
      url: WebService.adsManager.resumeCampaign,
      param: <String, dynamic>{
        'campaignId': campaignId,
      },
    );
    return AdsManagerActionResponseDto.fromJson(json);
  }

  Future<AdsManagerActionResponseDto> editBudget({
    required int campaignId,
    required num newBudget,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.call<Map<String, dynamic>>(
      url: WebService.adsManager.editBudget,
      param: <String, dynamic>{
        'campaignId': campaignId,
        'newBudget': newBudget,
      },
    );
    return AdsManagerActionResponseDto.fromJson(json);
  }

  Future<AdsManagerActionResponseDto> deleteCampaign({
    required int campaignId,
  }) async {
    final Map<String, dynamic> json =
        await ApiService.instance.call<Map<String, dynamic>>(
      url: WebService.adsManager.deleteCampaign,
      param: <String, dynamic>{
        'campaignId': campaignId,
      },
    );
    return AdsManagerActionResponseDto.fromJson(json);
  }
}
