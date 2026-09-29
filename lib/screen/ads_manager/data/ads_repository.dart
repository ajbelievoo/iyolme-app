import 'package:shortzz/screen/ads_manager/data/ads_api.dart';
import 'package:shortzz/screen/ads_manager/data/ads_dto.dart';
import 'package:shortzz/screen/ads_manager/mock/ads_manager_mock_data.dart';
import 'package:shortzz/common/service/api/boost_service.dart';

class AdsManagerRepository {
  AdsManagerRepository({AdsManagerApi? api}) : _api = api ?? AdsManagerApi.instance;

  final AdsManagerApi _api;

  String _mapStatus(int? code, String? raw) {
    if (code != null) {
      switch (code) {
        case 0:
          return 'Pending';
        case 1:
          return 'Active';
        case 2:
          return 'Rejected';
        case 3:
          return 'Paused';
        case 4:
          return 'Completed';
      }
    }
    final s = (raw ?? '').trim();
    return s.isEmpty ? 'Unknown' : s;
  }

  Future<int> createCampaign({
    required AdsManagerCampaignCreateRequestDto request,
  }) async {
    final res = await _api.createCampaign(request: request);
    if (res.status != true) {
      throw Exception(res.message ?? 'Failed to create campaign');
    }
    return res.campaignId ?? -1;
  }

  Future<List<AdsManagerCampaignItem>> listCampaigns({int? lastItemId}) async {
    final res = await _api.listCampaigns(lastItemId: lastItemId);
    return res.items
        .where((e) => e.id > 0)
        .map(
          (e) => AdsManagerCampaignItem(
            id: e.id,
            title: e.title,
            mediaUrl: e.mediaUrl,
            status: _mapStatus(e.statusCode, e.status),
            placement: e.placement ?? '-',
            spend: e.spend ?? 0,
            budget: e.budget ?? 0,
            dailyBudget: e.dailyBudget ?? 0,
            impressions: e.impressions ?? 0,
            clicks: e.clicks ?? 0,
            createdAt: e.createdAt ?? DateTime.now(),
          ),
        )
        .toList();
  }

  Future<List<AdsManagerCampaignItem>> listBoostCampaigns() async {
    final items = await BoostService.instance.fetchMyBoostRequests();
    String readPlacement(dynamic metadata) {
      try {
        if (metadata is Map) {
          final m = Map<String, dynamic>.from(metadata);
          final p = (m['placement'] ?? m['place'] ?? '').toString().trim();
          if (p.isNotEmpty) return p;
        } else if (metadata is String) {
          final s = metadata.trim().toLowerCase();
          if (s.contains('reel')) return 'reel';
          if (s.contains('story')) return 'story';
          if (s.contains('feed')) return 'feed';
          if (s.contains('profile')) return 'profile';
        }
      } catch (_) {}
      return '-';
    }

    String mapBoostStatus(String? raw) {
      final s = (raw ?? '').trim().toLowerCase();
      if (s.isEmpty) return 'Unknown';
      // accept number or text
      if (s == '0' || s == 'pending') return 'Pending';
      if (s == '1' || s == 'active' || s == 'running') return 'Active';
      if (s == '5' || s == 'draft') return 'Draft';
      if (s == '2' || s == 'rejected') return 'Rejected';
      if (s == '4' || s == 'completed' || s == 'done') return 'Completed';
      return raw ?? 'Unknown';
    }

    DateTime parseDate(String? raw) {
      if (raw == null) return DateTime.now();
      final d = DateTime.tryParse(raw);
      return d ?? DateTime.now();
    }

    return items.map((br) {
      final placement = readPlacement(br.metadata);
      return AdsManagerCampaignItem(
        id: br.id ?? -1,
        title: 'Boost Post #${br.postId ?? br.id ?? '-'}',
        mediaUrl: null,
        status: mapBoostStatus(br.status),
        placement: placement,
        spend: br.spend ?? 0,
        budget: br.budget ?? 0,
        dailyBudget: 0,
        impressions: 0,
        clicks: 0,
        createdAt: parseDate(br.createdAt),
      );
    }).where((e) => e.id > 0).toList();
  }

  Future<AdsManagerWalletDto> fetchWalletRaw() {
    return _api.fetchWallet();
  }

  Future<num> fetchWalletBalance() async {
    final wallet = await _api.fetchWallet();
    return wallet.balance;
  }

  Future<AdsManagerBoostSuggestedBudgetDto> fetchBoostSuggestedBudget({
    required int postId,
  }) {
    return _api.fetchBoostSuggestedBudget(postId: postId);
  }

  Future<AdsManagerCampaignAnalyticsDto> fetchCampaignAnalytics({
    required int campaignId,
  }) {
    return _api.fetchCampaignAnalytics(campaignId: campaignId);
  }

  Future<AdsManagerOverallAnalyticsDto> fetchOverallAnalytics({
    required String range,
  }) async {
    final res = await _api.fetchOverallAnalytics(range: range);
    if (res.status != true) {
      throw Exception(res.message ?? 'Failed to load analytics');
    }
    final data = res.data;
    if (data == null) {
      throw Exception(res.message ?? 'Analytics is empty');
    }
    return data;
  }

  Future<void> pauseCampaign({required int campaignId}) async {
    final res = await _api.pauseCampaign(campaignId: campaignId);
    if (res.status != true) {
      throw Exception(res.message ?? 'Failed to pause campaign');
    }
  }

  Future<void> resumeCampaign({required int campaignId}) async {
    final res = await _api.resumeCampaign(campaignId: campaignId);
    if (res.status != true) {
      throw Exception(res.message ?? 'Failed to resume campaign');
    }
  }

  Future<void> editBudget({
    required int campaignId,
    required num newBudget,
  }) async {
    final res = await _api.editBudget(
      campaignId: campaignId,
      newBudget: newBudget,
    );
    if (res.status != true) {
      throw Exception(res.message ?? 'Failed to update budget');
    }
  }

  Future<void> topUpAdsWallet({
    required Map<String, dynamic> payload,
  }) async {
    final res = await _api.topUpAdsWallet(payload: payload);
    if (res.status != true) {
      throw Exception(res.message ?? 'Top-up failed');
    }
  }

  Future<void> deleteCampaign({required int campaignId}) async {
    final res = await _api.deleteCampaign(campaignId: campaignId);
    if (res.status != true) {
      throw Exception(res.message ?? 'Failed to delete campaign');
    }
  }
}
