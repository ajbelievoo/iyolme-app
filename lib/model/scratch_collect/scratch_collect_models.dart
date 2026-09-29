import 'package:flutter/foundation.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

enum AssetRarity {
  common,
  rare,
  legendary,
}

extension AssetRarityExtension on AssetRarity {
  String get name {
    switch (this) {
      case AssetRarity.common:
        return 'Common';
      case AssetRarity.rare:
        return 'Rare';
      case AssetRarity.legendary:
        return 'Legendary';
    }
  }

  String get color {
    switch (this) {
      case AssetRarity.common:
        return '#9E9E9E';
      case AssetRarity.rare:
        return '#2196F3';
      case AssetRarity.legendary:
        return '#FFD700';
    }
  }
}

class Asset {
  final int id;
  final String name;
  final String description;
  final AssetRarity rarity;
  final String imageUrl;
  final int? maxDailyGlobal;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // FIXED: New fields from API docs for selling
  final String? price;
  final String? priceStatus;
  final String? sellStatus;
  final bool canSell;

  Asset({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.imageUrl,
    this.maxDailyGlobal,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    // FIXED: New fields with defaults
    this.price,
    this.priceStatus,
    this.sellStatus,
    this.canSell = false,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      rarity: _parseRarity(json['rarity']),
      imageUrl: json['image_url'] ?? '',
      maxDailyGlobal: json['max_daily_global'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      // FIXED: New fields from API
      price: json['price']?.toString(),
      priceStatus: json['price_status']?.toString(),
      sellStatus: json['sell_status']?.toString(),
      canSell: json['can_sell'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'rarity': rarity.name,
      'image_url': imageUrl,
      'max_daily_global': maxDailyGlobal,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // FIXED: New fields
      'price': price,
      'price_status': priceStatus,
      'sell_status': sellStatus,
      'can_sell': canSell,
    };
  }

  // FIXED: Helpers for UI logic per API docs
  bool get isPriceComingSoon => priceStatus == 'Coming Soon' || price == 'Coming Soon';
  bool get isSellComingSoon => sellStatus == 'Coming Soon';
  bool get showSellButton => canSell && !isSellComingSoon && rarity == AssetRarity.legendary;
  bool get showPrice => !isPriceComingSoon && price != null;

  static AssetRarity _parseRarity(String? rarity) {
    switch (rarity?.toLowerCase()) {
      case 'common':
        return AssetRarity.common;
      case 'rare':
        return AssetRarity.rare;
      case 'legendary':
        return AssetRarity.legendary;
      default:
        return AssetRarity.common;
    }
  }
}

class UserAsset {
  final int id;
  final int userId;
  final int assetId;
  final Asset? asset;
  final int quantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // NEW: Backend fusion fields from API
  final String? fusionProgress; // e.g., "2/5"
  final bool canFuse;

  UserAsset({
    required this.id,
    required this.userId,
    required this.assetId,
    this.asset,
    required this.quantity,
    this.createdAt,
    this.updatedAt,
    // NEW: Fusion fields
    this.fusionProgress,
    this.canFuse = false,
  });

  factory UserAsset.fromJson(Map<String, dynamic> json) {
    return UserAsset(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      assetId: json['asset_id'] ?? 0,
      asset: json['asset'] != null ? Asset.fromJson(json['asset']) : null,
      quantity: json['quantity'] ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      // NEW: Fusion fields from API
      fusionProgress: json['fusion_progress']?.toString(),
      canFuse: json['can_fuse'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'asset_id': assetId,
      'asset': asset?.toJson(),
      'quantity': quantity,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // NEW: Fusion fields
      'fusion_progress': fusionProgress,
      'can_fuse': canFuse,
    };
  }
}

class RewardConfig {
  final int id;
  final String rewardType;
  final int weight;
  final double? minAmount;
  final double? maxAmount;
  final int? assetId;
  final Asset? asset;
  final bool isActive;

  RewardConfig({
    required this.id,
    required this.rewardType,
    required this.weight,
    this.minAmount,
    this.maxAmount,
    this.assetId,
    this.asset,
    this.isActive = true,
  });

  factory RewardConfig.fromJson(Map<String, dynamic> json) {
    return RewardConfig(
      id: json['id'] ?? 0,
      rewardType: json['reward_type'] ?? 'token',
      weight: json['weight'] ?? 0,
      minAmount: _toDouble(json['min_amount']),
      maxAmount: _toDouble(json['max_amount']),
      assetId: json['asset_id'],
      asset: json['asset'] != null ? Asset.fromJson(json['asset']) : null,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reward_type': rewardType,
      'weight': weight,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'asset_id': assetId,
      'asset': asset?.toJson(),
      'is_active': isActive,
    };
  }
}

class FusionRule {
  final int id;
  final int sourceAssetId;
  final Asset? sourceAsset;
  final int sourceQuantity;
  final int targetAssetId;
  final Asset? targetAsset;
  final int successRate;
  final bool isActive;

  FusionRule({
    required this.id,
    required this.sourceAssetId,
    this.sourceAsset,
    required this.sourceQuantity,
    required this.targetAssetId,
    this.targetAsset,
    required this.successRate,
    this.isActive = true,
  });

  factory FusionRule.fromJson(Map<String, dynamic> json) {
    return FusionRule(
      id: json['id'] ?? 0,
      // FIXED: Handle both old API field names (input/output) and new (source/target)
      sourceAssetId: json['source_asset_id'] ?? json['input_asset_id'] ?? 0,
      sourceAsset: json['source_asset'] != null
          ? Asset.fromJson(json['source_asset'])
          : json['input_asset'] != null
              ? Asset.fromJson(json['input_asset'])
              : null,
      sourceQuantity: json['source_quantity'] ?? json['required_quantity'] ?? 5,
      targetAssetId: json['target_asset_id'] ?? json['output_asset_id'] ?? 0,
      targetAsset: json['target_asset'] != null
          ? Asset.fromJson(json['target_asset'])
          : json['output_asset'] != null
              ? Asset.fromJson(json['output_asset'])
              : null,
      successRate: json['success_rate'] ?? (json['success_probability'] != null
          ? int.tryParse(json['success_probability'].toString().split('.')[0]) ?? 100
          : 100),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_asset_id': sourceAssetId,
      'source_asset': sourceAsset?.toJson(),
      'source_quantity': sourceQuantity,
      'target_asset_id': targetAssetId,
      'target_asset': targetAsset?.toJson(),
      'success_rate': successRate,
      'is_active': isActive,
    };
  }
}

class ScratchSettings {
  final int id;
  final double tokenToCashRate;
  final int dailyGlobalLegendaryCap;
  final int minReelsForScratch;
  final int adIntervalSeconds;
  final bool isActive;
  // FIXED: New fields from backend
  final int minTokenReward;
  final int maxTokenReward;
  final int assetRewardChance;
  final int dailyCardLimit;
  final int pendingAdminCards;

  ScratchSettings({
    required this.id,
    required this.tokenToCashRate,
    required this.dailyGlobalLegendaryCap,
    required this.minReelsForScratch,
    required this.adIntervalSeconds,
    this.isActive = true,
    // FIXED: New fields with defaults
    this.minTokenReward = 10,
    this.maxTokenReward = 100,
    this.assetRewardChance = 20,
    this.dailyCardLimit = 5,
    this.pendingAdminCards = 0,
  });

  factory ScratchSettings.fromJson(Map<String, dynamic> json) {
    return ScratchSettings(
      id: json['id'] ?? 1,
      tokenToCashRate: _toDouble(json['token_to_cash_rate']) ?? 0.01,
      dailyGlobalLegendaryCap: json['daily_global_legendary_cap'] ?? 10,
      minReelsForScratch: json['min_reels_for_scratch'] ?? 3,
      adIntervalSeconds: json['ad_interval_seconds'] ?? 300,
      isActive: json['is_active'] ?? true,
      // FIXED: New fields from backend
      minTokenReward: json['min_token_reward'] ?? 10,
      maxTokenReward: json['max_token_reward'] ?? 100,
      assetRewardChance: json['asset_reward_chance'] ?? 20,
      dailyCardLimit: json['daily_card_limit'] ?? 5,
      pendingAdminCards: json['pending_admin_cards'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token_to_cash_rate': tokenToCashRate,
      'daily_global_legendary_cap': dailyGlobalLegendaryCap,
      'min_reels_for_scratch': minReelsForScratch,
      'ad_interval_seconds': adIntervalSeconds,
      'is_active': isActive,
      // FIXED: New fields
      'min_token_reward': minTokenReward,
      'max_token_reward': maxTokenReward,
      'asset_reward_chance': assetRewardChance,
      'daily_card_limit': dailyCardLimit,
      'pending_admin_cards': pendingAdminCards,
    };
  }

  double get tokensPerRupee => 1 / tokenToCashRate;
}

class ClaimedReward {
  final String rewardType;
  final double? tokenAmount;
  final int? assetId;
  final Asset? asset;
  final int? quantity;
  final DateTime claimedAt;

  ClaimedReward({
    required this.rewardType,
    this.tokenAmount,
    this.assetId,
    this.asset,
    this.quantity,
    DateTime? claimedAt,
  }) : claimedAt = claimedAt ?? DateTime.now();

  factory ClaimedReward.fromJson(Map<String, dynamic> json) {
    // Handle both wrapped (data: {}) and direct response formats
    final data = json['data'] ?? json;
    
    // FIXED: Handle case where token_amount comes as int or needs parsing
    final tokenAmount = _toDouble(data['token_amount'] ?? data['amount']);
    
    // DEBUG: Log the reward data
    debugPrint('[ClaimedReward.fromJson] Parsed: rewardType=${data['reward_type']}, tokenAmount=$tokenAmount, asset=${data['asset'] != null}');
    
    return ClaimedReward(
      rewardType: data['reward_type'] ?? data['type'] ?? 'token',
      tokenAmount: tokenAmount,
      assetId: data['asset_id'],
      asset: data['asset'] != null ? Asset.fromJson(data['asset']) : null,
      quantity: data['quantity'],
      claimedAt: DateTime.tryParse(
          '${data['claimed_at'] ?? data['created_at'] ?? ''}'),
    );
  }

  /// FIXED: Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'reward_type': rewardType,
      'token_amount': tokenAmount,
      'asset_id': assetId,
      'asset': asset?.toJson(),
      'quantity': quantity,
      'claimed_at': claimedAt.toIso8601String(),
    };
  }

  bool get isToken => rewardType == 'token';
  bool get isAsset => rewardType == 'asset';
}

class FusionResult {
  final bool success;
  final String message;
  final Asset? newAsset;
  final int? remainingSourceQuantity;

  FusionResult({
    required this.success,
    required this.message,
    this.newAsset,
    this.remainingSourceQuantity,
  });

  factory FusionResult.fromJson(Map<String, dynamic> json) {
    return FusionResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      newAsset: json['new_asset'] != null
          ? Asset.fromJson(json['new_asset'])
          : null,
      remainingSourceQuantity: json['remaining_source_quantity'],
    );
  }
}

class VaultData {
  final List<UserAsset> assets;
  final double tokenBalance;
  final double estimatedValue;

  VaultData({
    required this.assets,
    required this.tokenBalance,
    required this.estimatedValue,
  });

  factory VaultData.fromJson(Map<String, dynamic> json) {
    return VaultData(
      assets: (json['assets'] as List?)
              ?.map((e) => UserAsset.fromJson(e))
              .toList() ??
          [],
      tokenBalance: _toDouble(json['token_balance']) ?? 0.0,
      estimatedValue: _toDouble(json['estimated_value']) ?? 0.0,
    );
  }

  int get totalAssets => assets.fold(0, (sum, a) => sum + a.quantity);

  Map<AssetRarity, List<UserAsset>> get assetsByRarity {
    final map = <AssetRarity, List<UserAsset>>{};
    for (final rarity in AssetRarity.values) {
      map[rarity] = assets
          .where((a) => a.asset?.rarity == rarity)
          .toList();
    }
    return map;
  }
}

class RewardConfigResponse {
  final List<RewardConfig> rewards;
  final ScratchSettings settings;

  RewardConfigResponse({
    required this.rewards,
    required this.settings,
  });

  factory RewardConfigResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return RewardConfigResponse(
      rewards: (data['rewards'] as List?)
              ?.map((e) => RewardConfig.fromJson(e))
              .toList() ??
          [],
      settings: data['settings'] != null
          ? ScratchSettings.fromJson(data['settings'])
          : ScratchSettings(
              id: 1,
              tokenToCashRate: 0.01,
              dailyGlobalLegendaryCap: 10,
              minReelsForScratch: 3,
              adIntervalSeconds: 300,
              // FIXED: New fields from backend
              minTokenReward: data['min_token_reward'] ?? 10,
              maxTokenReward: data['max_token_reward'] ?? 100,
              assetRewardChance: data['asset_reward_chance'] ?? 20,
              dailyCardLimit: data['daily_card_limit'] ?? 5,
              pendingAdminCards: data['pending_admin_cards'] ?? 0,
            ),
    );
  }
}

/// Backend reward history row (GET v1/rewards/history)
class RewardHistoryItem {
  final int id;
  final String type; // claim | sell | fusion | redeem
  final String? rewardType; // asset | token
  final double? tokenAmount;
  final double? cashAmount;
  final int? assetId;
  final String? assetName;
  final int? quantity;
  final String? description;
  final DateTime? createdAt;

  RewardHistoryItem({
    required this.id,
    required this.type,
    this.rewardType,
    this.tokenAmount,
    this.cashAmount,
    this.assetId,
    this.assetName,
    this.quantity,
    this.description,
    this.createdAt,
  });

  factory RewardHistoryItem.fromJson(Map<String, dynamic> json) {
    return RewardHistoryItem(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
      type: json['type']?.toString() ?? 'claim',
      rewardType: json['reward_type']?.toString(),
      tokenAmount: _toDouble(json['token_amount']),
      cashAmount: _toDouble(json['cash_amount']),
      assetId: json['asset_id'] is num ? (json['asset_id'] as num).toInt() : int.tryParse('${json['asset_id']}'),
      assetName: json['asset_name']?.toString() ??
          (json['asset'] is Map ? json['asset']['name']?.toString() : null),
      quantity: json['quantity'] is num ? (json['quantity'] as num).toInt() : int.tryParse('${json['quantity']}'),
      description: json['description']?.toString(),
      createdAt: DateTime.tryParse(
          '${json['created_at'] ?? json['claimed_at'] ?? ''}'),
    );
  }
}

/// Result of POST v1/assets/sell
class SellResult {
  final bool success;
  final String message;
  final int tokensEarned;
  final double? newTokenBalance;

  SellResult({
    required this.success,
    required this.message,
    this.tokensEarned = 0,
    this.newTokenBalance,
  });

  factory SellResult.fromJson(Map<String, dynamic> json) {
    return SellResult(
      success: json['status'] == true || json['success'] == true,
      message: json['message']?.toString() ?? '',
      tokensEarned: () {
        final v = json['tokens_earned'] ?? json['tokens_credited'];
        return v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      }(),
      newTokenBalance: _toDouble(json['new_token_balance']),
    );
  }
}

/// Result of POST v1/wallet/redeem-tokens
class RedeemResult {
  final bool success;
  final String message;
  final int tokensRedeemed;
  final double cashCredited;
  final double? newTokenBalance;
  final double? newWalletBalance;

  RedeemResult({
    required this.success,
    required this.message,
    this.tokensRedeemed = 0,
    this.cashCredited = 0,
    this.newTokenBalance,
    this.newWalletBalance,
  });

  factory RedeemResult.fromJson(Map<String, dynamic> json) {
    return RedeemResult(
      success: json['status'] == true || json['success'] == true,
      message: json['message']?.toString() ?? '',
      tokensRedeemed: json['tokens_redeemed'] is num
          ? (json['tokens_redeemed'] as num).toInt()
          : int.tryParse('${json['tokens_redeemed']}') ?? 0,
      cashCredited: _toDouble(json['cash_credited']) ?? 0,
      newTokenBalance: _toDouble(json['new_token_balance']),
      newWalletBalance:
          _toDouble(json['new_wallet_balance'] ?? json['wallet_balance']),
    );
  }
}

/// FIXED: Pending scratch cards from admin panel
class PendingCardsResponse {
  final int pendingCards;
  final double totalPendingRewards;
  final List<PendingCard> cards;

  PendingCardsResponse({
    required this.pendingCards,
    required this.totalPendingRewards,
    required this.cards,
  });

  factory PendingCardsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return PendingCardsResponse(
      pendingCards: data['pending_cards'] ?? 0,
      totalPendingRewards: _toDouble(data['total_pending_rewards']) ?? 0.0,
      cards: (data['cards'] as List?)
              ?.map((e) => PendingCard.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// FIXED: Individual pending card from admin
class PendingCard {
  final int id;
  final String rewardType;
  final double? tokenAmount;
  final Asset? asset;
  final String addedBy;
  final DateTime createdAt;

  PendingCard({
    required this.id,
    required this.rewardType,
    this.tokenAmount,
    this.asset,
    required this.addedBy,
    required this.createdAt,
  });

  factory PendingCard.fromJson(Map<String, dynamic> json) {
    return PendingCard(
      id: json['id'] ?? 0,
      rewardType: json['reward_type'] ?? 'token',
      tokenAmount: _toDouble(json['token_amount']),
      asset: json['asset'] != null ? Asset.fromJson(json['asset']) : null,
      addedBy: json['added_by'] ?? 'admin',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
