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
}
o