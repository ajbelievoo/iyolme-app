import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shortzz/common/service/api/scratch_collect_service.dart';
import 'package:shortzz/model/scratch_collect/scratch_collect_models.dart';

const String _historyKey = 'scratch_claimed_history';

class ScratchCollectController extends GetxController {
  static ScratchCollectController get instance => Get.find<ScratchCollectController>();

  final RxList<UserAsset> userAssets = <UserAsset>[].obs;
  final RxDouble tokenBalance = 0.0.obs;
  final RxDouble estimatedValue = 0.0.obs;
  final RxList<FusionRule> fusionRules = <FusionRule>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isFusing = false.obs;
  final RxInt reelsWatched = 0.obs;
  final RxInt adsWatched = 0.obs;
  final RxInt scratchCardsAvailable = 0.obs;
  
  // FIXED: Backend scratch cards from admin panel (priority over algorithm)
  final RxInt backendScratchCards = 0.obs;
  
  // FIXED: Daily card limit tracking
  final RxInt cardsScratchedToday = 0.obs;
  final Rx<DateTime> lastScratchDate = DateTime.now().obs;
  
  // FIXED: Store settings from API
  final Rx<ScratchSettings> settings = ScratchSettings(
    id: 1,
    tokenToCashRate: 0.01,
    dailyGlobalLegendaryCap: 10,
    minReelsForScratch: 3,
    adIntervalSeconds: 300,
  ).obs;

  // FIXED: Use fixed min reels from API (no dynamic scroll speed)
  int _currentMinReelsForScratch = 3;
  
  // Use API settings or fallback to default
  int get minReelsForScratch => _currentMinReelsForScratch;
  double get progressPercent => (reelsWatched.value / minReelsForScratch).clamp(0.0, 1.0);
  bool get canScratch => reelsWatched.value >= minReelsForScratch;
  bool get hasScratchCardsAvailable => scratchCardsAvailable.value > 0;
  int get availableScratchCards => scratchCardsAvailable.value;
  
  // FIXED: Backend cards getters
  bool get hasBackendScratchCards => backendScratchCards.value > 0;
  int get availableBackendCards => backendScratchCards.value;
  
  // FIXED: Daily limit check
  bool get canScratchToday {
    // Check if it's a new day
    final today = DateTime.now();
    final lastScratch = lastScratchDate.value;
    if (today.day != lastScratch.day || today.month != lastScratch.month || today.year != lastScratch.year) {
      cardsScratchedToday.value = 0;
    }
    return cardsScratchedToday.value < settings.value.dailyCardLimit;
  }
  int get remainingDailyCards => settings.value.dailyCardLimit - cardsScratchedToday.value;

  final RxList<ClaimedReward> claimedRewardsHistory = <ClaimedReward>[].obs;

  // Callback for auto-popup
  VoidCallback? onScratchCardAvailable;

  @override
  void onInit() {
    super.onInit();
    // FIXED: Load saved history first
    _loadSavedHistory();
    
    // FIXED: Fetch reward config first to get settings from API
    fetchRewardConfig();
    fetchVaultData();
    fetchFusionRules();
    fetchPendingCards(); // FIXED: Fetch admin-added pending cards
    
    // Listen for scratch card availability
    ever(scratchCardsAvailable, (count) {
      if (count > 0) {
        onScratchCardAvailable?.call();
      }
    });
  }

  /// FIXED: Load history from SharedPreferences
  Future<void> _loadSavedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey);
      
      if (historyJson != null && historyJson.isNotEmpty) {
        final loadedHistory = historyJson
            .map((json) => ClaimedReward.fromJson(jsonDecode(json)))
            .toList();
        claimedRewardsHistory.value = loadedHistory;
        debugPrint('[SCRATCH_DEBUG] Loaded ${loadedHistory.length} items from saved history');
      }
    } catch (e) {
      debugPrint('[SCRATCH_DEBUG] Error loading saved history: $e');
    }
  }

  /// FIXED: Save history to SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = claimedRewardsHistory
          .map((reward) => jsonEncode(reward.toJson()))
          .toList();
      await prefs.setStringList(_historyKey, historyJson);
      debugPrint('[SCRATCH_DEBUG] Saved ${historyJson.length} items to history');
    } catch (e) {
      debugPrint('[SCRATCH_DEBUG] Error saving history: $e');
    }
  }

  /// FIXED: Fetch pending scratch cards from admin panel
  Future<void> fetchPendingCards() async {
    try {
      final response = await ScratchCollectService.instance.getPendingCards();
      
      // Update backend cards count from API
      backendScratchCards.value = response.pendingCards;
      
      // Also update from settings if available
      if (settings.value.pendingAdminCards > 0) {
        backendScratchCards.value = settings.value.pendingAdminCards;
      }
      
      debugPrint('[SCRATCH_DEBUG] Loaded pending cards: ${backendScratchCards.value} (total rewards: ${response.totalPendingRewards})');
    } catch (e) {
      debugPrint('[SCRATCH_DEBUG] Error fetching pending cards: $e');
      // Fallback to settings value
      backendScratchCards.value = settings.value.pendingAdminCards;
    }
  }

  /// FIXED: Record scroll event - NO dynamic adjustment, use fixed value from API
  void recordScrollEvent() {
    // Just log the scroll, don't change minReelsForScratch
    // It stays fixed as per API settings
    debugPrint('[SCRATCH_DEBUG] Scroll recorded - fixed minReels: $_currentMinReelsForScratch');
  }

  /// FIXED: Reset - just reload from API settings
  void resetScrollTracking() {
    _currentMinReelsForScratch = settings.value.minReelsForScratch;
    debugPrint('[SCRATCH_DEBUG] Reset minReels to: $_currentMinReelsForScratch');
  }

  /// FIXED: Fetch reward config from API and update settings
  Future<void> fetchRewardConfig() async {
    try {
      isLoading.value = true;
      final config = await ScratchCollectService.instance.getRewardConfig();
      
      // Update settings from API
      settings.value = config.settings;
      _currentMinReelsForScratch = config.settings.minReelsForScratch;
      
      debugPrint('[SCRATCH_DEBUG] Loaded config from API: minReelsForScratch = $_currentMinReelsForScratch');
    } catch (e) {
      debugPrint('[SCRATCH_DEBUG] Error fetching reward config: $e');
      // Use default values on error
      _currentMinReelsForScratch = 3;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchVaultData() async {
    try {
      isLoading.value = true;
      final vaultData = await ScratchCollectService.instance.getUserVault();
      userAssets.value = vaultData.assets;
      tokenBalance.value = vaultData.tokenBalance;
      estimatedValue.value = vaultData.estimatedValue;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load your collection',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchFusionRules() async {
    try {
      debugPrint('[FUSION_DEBUG] Starting fetchFusionRules...');
      final rules = await ScratchCollectService.instance.getFusionRules();
      debugPrint('[FUSION_DEBUG] Received ${rules.length} fusion rules from API');
      for (var rule in rules) {
        debugPrint('[FUSION_DEBUG] Rule: ${rule.sourceAsset?.name} (${rule.sourceQuantity}) → ${rule.targetAsset?.name}');
      }
      fusionRules.value = rules;
      debugPrint('[FUSION_DEBUG] fusionRules updated in controller, length: ${fusionRules.length}');
    } catch (e, stackTrace) {
      debugPrint('[FUSION_DEBUG] ERROR fetching fusion rules: $e');
      debugPrint('[FUSION_DEBUG] Stack trace: $stackTrace');
      // FALLBACK: Use hardcoded rules if API fails (404 or other errors)
      debugPrint('[FUSION_DEBUG] Using fallback hardcoded fusion rules');
      fusionRules.value = _getFallbackFusionRules();
    }
  }

  // FALLBACK: Hardcoded fusion rules when backend API is not available
  List<FusionRule> _getFallbackFusionRules() {
    return [
      // 5 Cats → 1 Dog
      FusionRule(
        id: 1,
        sourceAssetId: 1,
        sourceAsset: Asset(
          id: 1,
          name: 'Cat',
          description: 'Base tier character',
          rarity: AssetRarity.common,
          imageUrl: '',
        ),
        sourceQuantity: 5,
        targetAssetId: 2,
        targetAsset: Asset(
          id: 2,
          name: 'Dog',
          description: 'Upgrade from 5 Cats',
          rarity: AssetRarity.common,
          imageUrl: '',
        ),
        successRate: 100,
      ),
      // 5 Dogs → 1 Tiger
      FusionRule(
        id: 2,
        sourceAssetId: 2,
        sourceAsset: Asset(
          id: 2,
          name: 'Dog',
          description: 'Common tier character',
          rarity: AssetRarity.common,
          imageUrl: '',
        ),
        sourceQuantity: 5,
        targetAssetId: 3,
        targetAsset: Asset(
          id: 3,
          name: 'Tiger',
          description: 'Rare tier character',
          rarity: AssetRarity.rare,
          imageUrl: '',
        ),
        successRate: 100,
      ),
      // 5 Tigers → 1 Lion
      FusionRule(
        id: 3,
        sourceAssetId: 3,
        sourceAsset: Asset(
          id: 3,
          name: 'Tiger',
          description: 'Rare tier character',
          rarity: AssetRarity.rare,
          imageUrl: '',
        ),
        sourceQuantity: 5,
        targetAssetId: 4,
        targetAsset: Asset(
          id: 4,
          name: 'Lion',
          description: 'Rare tier character',
          rarity: AssetRarity.rare,
          imageUrl: '',
        ),
        successRate: 100,
      ),
      // 5 Lions → 1 Panda
      FusionRule(
        id: 4,
        sourceAssetId: 4,
        sourceAsset: Asset(
          id: 4,
          name: 'Lion',
          description: 'Rare tier character',
          rarity: AssetRarity.rare,
          imageUrl: '',
        ),
        sourceQuantity: 5,
        targetAssetId: 5,
        targetAsset: Asset(
          id: 5,
          name: 'Panda',
          description: 'Legendary tier character - Ultimate Goal!',
          rarity: AssetRarity.legendary,
          imageUrl: '',
        ),
        successRate: 100,
      ),
    ];
  }

  Future<FusionResult?> fuseAssets(int ruleId) async {
    try {
      isFusing.value = true;
      final result = await ScratchCollectService.instance.fuseAssets(
        ruleId: ruleId,
      );

      if (result.success) {
        await fetchVaultData();
        Get.snackbar(
          'Fusion Successful!',
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        await fetchVaultData();
        Get.snackbar(
          'Fusion Failed',
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      return result;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Fusion failed. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isFusing.value = false;
    }
  }

  void incrementReelsWatched() {
    reelsWatched.value++;
    // FIXED: Use dynamic minReelsForScratch
    if (reelsWatched.value >= minReelsForScratch) {
      scratchCardsAvailable.value++;
      reelsWatched.value = 0;
    }
  }

  void resetProgress() {
    reelsWatched.value = 0;
  }

  void decrementScratchCards() {
    if (scratchCardsAvailable.value > 0) {
      scratchCardsAvailable.value--;
    }
  }

  /// FIXED: Decrement backend scratch cards count
  void decrementBackendScratchCards() {
    if (backendScratchCards.value > 0) {
      backendScratchCards.value--;
      debugPrint('[SCRATCH_DEBUG] Backend card used! Remaining: ${backendScratchCards.value}');
    }
  }

  /// FIXED: Record that user scratched a card today
  void recordScratchCardUsed() {
    // Check if it's a new day
    final today = DateTime.now();
    final lastScratch = lastScratchDate.value;
    if (today.day != lastScratch.day || today.month != lastScratch.month || today.year != lastScratch.year) {
      cardsScratchedToday.value = 0;
    }
    
    cardsScratchedToday.value++;
    lastScratchDate.value = today;
    
    debugPrint('[SCRATCH_DEBUG] Card scratched today: ${cardsScratchedToday.value}/${settings.value.dailyCardLimit}');
  }

  // Instagram-like watch time tracking
  DateTime? _currentReelStartTime;
  int _currentReelId = 0;
  final int minWatchTimeSeconds = 5; // Minimum 5 seconds to count as watched

  /// Start tracking watch time for a reel
  void startReelWatch(int reelId) {
    _currentReelStartTime = DateTime.now();
    _currentReelId = reelId;
  }

  /// End tracking and check if reel was fully watched
  void endReelWatch(int reelId) {
    if (_currentReelStartTime == null || _currentReelId != reelId) return;
    
    final watchDuration = DateTime.now().difference(_currentReelStartTime!);
    final secondsWatched = watchDuration.inSeconds;
    
    // Only count if watched for at least minWatchTimeSeconds
    if (secondsWatched >= minWatchTimeSeconds) {
      _incrementReelsWatched();
      debugPrint('[SCRATCH_DEBUG] Reel $reelId counted - watched ${secondsWatched}s');
    } else {
      debugPrint('[SCRATCH_DEBUG] Reel $reelId NOT counted - only watched ${secondsWatched}s (min: $minWatchTimeSeconds)');
    }
    
    _currentReelStartTime = null;
  }

  void _incrementReelsWatched() {
    reelsWatched.value++;
    // FIXED: Use dynamic minReelsForScratch
    if (reelsWatched.value >= minReelsForScratch) {
      scratchCardsAvailable.value++;
      reelsWatched.value = 0;
      debugPrint('[SCRATCH_DEBUG] Scratch card earned! Total: ${scratchCardsAvailable.value} (minReels: $minReelsForScratch)');
    }
  }

  @override
  void onClose() {
    _currentReelStartTime = null;
    super.onClose();
  }

  /// FIXED: Add claimed reward to history and save to SharedPreferences
  void addClaimedRewardToHistory(ClaimedReward reward) {
    claimedRewardsHistory.insert(0, reward);
    debugPrint('[SCRATCH_DEBUG] Added to history: ${reward.rewardType} - ${reward.asset?.name ?? reward.tokenAmount}');
    // FIXED: Persist history
    _saveHistory();
  }

  // Asset helper methods
  List<UserAsset> getAssetsByRarity(AssetRarity rarity) {
    return userAssets.where((a) => a.asset?.rarity == rarity).toList();
  }

  int getAssetQuantity(int assetId) {
    final asset = userAssets.firstWhereOrNull((a) => a.assetId == assetId);
    return asset?.quantity ?? 0;
  }

  bool canFuse(int ruleId) {
    final rule = fusionRules.firstWhereOrNull((r) => r.id == ruleId);
    if (rule == null) return false;

    final sourceQuantity = getAssetQuantity(rule.sourceAssetId);
    return sourceQuantity >= rule.sourceQuantity;
  }
}
