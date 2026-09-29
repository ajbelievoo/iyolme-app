import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/scratch_collect/scratch_collect_models.dart';

class ScratchCollectService {
  ScratchCollectService._();

  static final ScratchCollectService instance = ScratchCollectService._();

  Future<RewardConfigResponse> getRewardConfig() async {
    try {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.scratchCollect.getRewardConfig,
      );
      return RewardConfigResponse.fromJson(response);
    } catch (e) {
      Loggers.error('[ScratchCollect] Error fetching reward config: $e');
      rethrow;
    }
  }

  Future<ClaimedReward> claimReward() async {
    try {
      Loggers.info('[ScratchCollect] Calling claimReward API...');
      
      final response = await ApiService.instance.call<Map<String, dynamic>>(
        url: WebService.scratchCollect.claimReward,
      );

      Loggers.info('[ScratchCollect] Raw response: $response');

      // Backend returns status:false (HTTP 200) for e.g. daily limit reached —
      // surface the server message instead of parsing an empty reward.
      if (response['status'] == false) {
        throw Exception('${response['message'] ?? 'Claim failed'}');
      }

      final data = response['data'] ?? response;
      
      Loggers.info('[ScratchCollect] Extracted data: $data');
      Loggers.info('[ScratchCollect] token_amount field: ${data['token_amount']}, type: ${data['token_amount']?.runtimeType}');
      Loggers.info('[ScratchCollect] reward_type field: ${data['reward_type']}');
      
      final reward = ClaimedReward.fromJson(data);
      
      Loggers.info('[ScratchCollect] Parsed reward: type=${reward.rewardType}, tokens=${reward.tokenAmount}, asset=${reward.asset?.name}');
      
      return reward;
    } catch (e, stack) {
      Loggers.error('[ScratchCollect] Error claiming reward: $e\n$stack');
      rethrow;
    }
  }

  Future<VaultData> getUserVault() async {
    try {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.scratchCollect.getUserVault,
      );

      final data = response['data'] ?? response;
      return VaultData.fromJson(data);
    } catch (e) {
      Loggers.error('[ScratchCollect] Error fetching user vault: $e');
      rethrow;
    }
  }

  Future<List<FusionRule>> getFusionRules() async {
    try {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.scratchCollect.getFusionRules,
      );

      final data = response['data'] ?? response;
      final rules = (data['rules'] as List?)
              ?.map((e) => FusionRule.fromJson(e))
              .toList() ??
          [];
      return rules;
    } catch (e) {
      Loggers.error('[ScratchCollect] Error fetching fusion rules: $e');
      rethrow;
    }
  }

  Future<FusionResult> fuseAssets({required int ruleId}) async {
    try {
      final response = await ApiService.instance.call<Map<String, dynamic>>(
        url: WebService.scratchCollect.fuseAssets,
        param: {'rule_id': ruleId},
      );

      final data = response['data'] ?? response;
      return FusionResult.fromJson(data);
    } catch (e) {
      Loggers.error('[ScratchCollect] Error fusing assets: $e');
      rethrow;
    }
  }

  /// FIXED: Fetch pending scratch cards from admin panel
  Future<PendingCardsResponse> getPendingCards() async {
    try {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        url: WebService.scratchCollect.getPendingCards,
      );
      return PendingCardsResponse.fromJson(response);
    } catch (e) {
      Loggers.error('[ScratchCollect] Error fetching pending cards: $e');
      rethrow;
    }
  }

  /// Sell a collected asset for tokens (POST v1/assets/sell)
  Future<SellResult> sellAsset({required int assetId, int quantity = 1}) async {
    try {
      final response = await ApiService.instance.call<Map<String, dynamic>>(
        url: WebService.scratchCollect.sellAsset,
        param: {'asset_id': assetId, 'quantity': quantity},
      );

      if (response['status'] == false) {
        return SellResult(
          success: false,
          message: '${response['message'] ?? 'Sell failed'}',
        );
      }
      final data = response['data'] ?? response;
      return SellResult.fromJson(data);
    } catch (e) {
      Loggers.error('[ScratchCollect] Error selling asset: $e');
      rethrow;
    }
  }

  /// Reward history sync (GET v1/rewards/history)
  Future<List<RewardHistoryItem>> getRewardsHistory({int limit = 50}) async {
    try {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        url: '${WebService.scratchCollect.getRewardsHistory}?limit=$limit',
      );

      // Backend returns rows under BOTH 'history' and 'data' (spec aliases) —
      // read 'history' first because 'data' is a List here, not a Map.
      final list = (response['history'] as List?) ??
          (response['data'] as List?) ??
          const [];
      return list
          .map((e) => RewardHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Loggers.error('[ScratchCollect] Error fetching reward history: $e');
      rethrow;
    }
  }

  /// Redeem vault tokens to wallet cash (POST v1/wallet/redeem-tokens)
  Future<RedeemResult> redeemTokens({required int tokens}) async {
    try {
      final response = await ApiService.instance.call<Map<String, dynamic>>(
        url: WebService.scratchCollect.redeemTokens,
        param: {'tokens': tokens},
      );

      if (response['status'] == false) {
        return RedeemResult(
          success: false,
          message: '${response['message'] ?? 'Redemption failed'}',
        );
      }
      final data = response['data'] ?? response;
      return RedeemResult.fromJson(data);
    } catch (e) {
      Loggers.error('[ScratchCollect] Error redeeming tokens: $e');
      rethrow;
    }
  }
}
