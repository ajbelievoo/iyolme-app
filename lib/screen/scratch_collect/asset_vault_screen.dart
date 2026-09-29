import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/scratch_collect/scratch_collect_models.dart';
import 'package:shortzz/screen/scratch_collect/scratch_collect_controller.dart';
import 'package:shimmer/shimmer.dart';

/// NEW: Complete redesign of iYol Vault with character hierarchy and fusion progress
/// Hierarchy: Panda (Top) → Lion → Tiger → Cat → Dog (Bottom)
/// Each character shows count + fusion progress bar
/// Panda has special section with token value and sell status

class AssetVaultScreen extends StatelessWidget {
  const AssetVaultScreen({super.key});

  static Future<void> open() async {
    // onInit() already fetches data on first registration (main.dart puts it
    // permanently). Only refresh when the controller already exists to avoid
    // duplicate API calls on every open.
    final wasRegistered = Get.isRegistered<ScratchCollectController>();
    final controller = Get.put(ScratchCollectController());
    if (wasRegistered) {
      controller.fetchVaultData();
      controller.fetchFusionRules();
      controller.fetchRewardHistory();
    }
    Get.to(() => const AssetVaultScreen());
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ScratchCollectController>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0a14),
        body: Obx(() {
          if (controller.isLoading.value) {
            return _buildShimmerLoading();
          }

          return RefreshIndicator(
            onRefresh: () => Future.wait([
              controller.fetchVaultData(),
              controller.fetchFusionRules(),
              controller.fetchRewardHistory(),
            ]),
            color: Colors.amber,
            backgroundColor: const Color(0xFF1a1a2e),
            child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // NEW: Header with TabBar
              SliverToBoxAdapter(
                child: _buildHeader(controller),
              ),

              // NEW: TabBar for Collection / History
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a2e),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.collections),
                        text: LKey.collection.tr,
                      ),
                      Tab(
                        icon: const Icon(Icons.history),
                        text: LKey.history.tr,
                      ),
                    ],
                  ),
                ),
              ),

              // NEW: Tab Content
              SliverFillRemaining(
                child: TabBarView(
                  children: [
                    // Collection Tab - REACTIVE for fusion rules
                    Obx(() => _buildCollectionTab(controller)),
                    // History Tab
                    _buildHistoryTab(controller),
                  ],
                ),
              ),
            ],
            ),
          );
        }),
      ),
    );
  }

  // NEW: Collection Tab with Character Hierarchy
  // FIXED: Cat (Base) → Dog → Tiger → Lion → Panda per API docs
  Widget _buildCollectionTab(ScratchCollectController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panda (Legendary - Top Tier)
          _buildCharacterCard(
            controller: controller,
            characterName: 'Panda',
            characterType: 'Legendary',
            icon: Icons.workspace_premium,
            color: Colors.amber,
            gradientColors: [Colors.amber.shade400, Colors.orange.shade600],
            isTopTier: true,
            fusionFrom: 'Lion',
          ),

          const SizedBox(height: 16),

          // Lion (Rare)
          _buildCharacterCard(
            controller: controller,
            characterName: 'Lion',
            characterType: 'Rare',
            icon: Icons.emoji_nature,
            color: Colors.orange,
            gradientColors: [Colors.orange.shade400, Colors.deepOrange.shade600],
            fusionFrom: 'Tiger',
          ),

          const SizedBox(height: 16),

          // Tiger (Rare)
          _buildCharacterCard(
            controller: controller,
            characterName: 'Tiger',
            characterType: 'Rare',
            icon: Icons.filter_vintage,
            color: Colors.blue,
            gradientColors: [Colors.blue.shade400, Colors.indigo.shade600],
            fusionFrom: 'Dog',
          ),

          const SizedBox(height: 16),

          // Dog (Common) - comes from 5 Cats
          _buildCharacterCard(
            controller: controller,
            characterName: 'Dog',
            characterType: 'Common',
            icon: Icons.pets,
            color: Colors.grey,
            gradientColors: [Colors.grey.shade400, Colors.grey.shade600],
            fusionFrom: 'Cat',
          ),

          const SizedBox(height: 16),

          // Cat (Common - Base Tier)
          _buildCharacterCard(
            controller: controller,
            characterName: 'Cat',
            characterType: 'Common',
            icon: Icons.pets,
            color: Colors.brown,
            gradientColors: [Colors.brown.shade400, Colors.brown.shade600],
            isBaseTier: true,
          ),

          const SizedBox(height: 32),

          // Fusion Info Card
          _buildFusionInfoCard(controller),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // NEW: Character Card with Count and Fusion Progress
  Widget _buildCharacterCard({
    required ScratchCollectController controller,
    required String characterName,
    required String characterType,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    String? fusionFrom,
    bool isTopTier = false,
    bool isBaseTier = false,
  }) {
    // Get count from user assets
    final asset = controller.userAssets.firstWhereOrNull(
      (a) => a.asset?.name.toLowerCase() == characterName.toLowerCase(),
    );
    final count = asset?.quantity ?? 0;

    // For top tier (Panda), show special details
    final isPanda = characterName == 'Panda';
    final pandaAsset = isPanda ? asset?.asset : null;
    
    // FIXED: Get fusion count from backend rules instead of hardcoded 5
    int fusionCount = 5; // default fallback
    if (fusionFrom != null && !isBaseTier) {
      final rule = controller.fusionRules.firstWhereOrNull(
        (r) {
          final targetName = r.targetAsset?.name.toLowerCase() ?? '';
          // Handle both "Lion" (UI) and "Loin" (backend) spellings
          final characterNameLower = characterName.toLowerCase();
          if (characterNameLower == 'lion') {
            return targetName == 'lion' || targetName == 'loin';
          }
          return targetName == characterNameLower;
        },
      );
      if (rule != null) {
        fusionCount = rule.sourceQuantity;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPanda
              ? [
                  Colors.amber.withValues(alpha: 0.15),
                  const Color(0xFF1a1a2e),
                  const Color(0xFF0f0f1a),
                ]
              : [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF0f0f1a),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPanda 
              ? Colors.amber.withValues(alpha: 0.6) 
              : (isTopTier ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
          width: isPanda ? 3 : (isTopTier ? 2 : 1),
        ),
        boxShadow: isPanda
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ]
            : (isTopTier
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null),
      ),
      child: Column(
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Character Icon - USE LOCAL ASSET IMAGE
                _buildCharacterImage(characterName),
                const SizedBox(width: 16),

                // Character Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            characterName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isTopTier) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.workspace_premium,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          characterType,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Count Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // NEW: Panda Info Button (always visible for Panda)
          if (isPanda)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showPandaDetailsDialog(
                    asset ?? UserAsset(id: 0, userId: 0, assetId: 0, quantity: 0),
                    controller,
                  ),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: Text(
                    LKey.viewPandaDetails.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

          // Panda Special Section (Token Value & Sell) - only when count > 0
          if (isPanda && count > 0) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  // Token Value
                  Row(
                    children: [
                      const Icon(
                        Icons.token,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pandaAsset?.isPriceComingSoon == true
                            ? '${LKey.valueLabel.tr}: ${LKey.comingSoon.tr}'
                            : '${LKey.valueLabel.tr}: ${pandaAsset?.price ?? 'N/A'} ${LKey.tokens.tr}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sell Status
                  if (pandaAsset?.showSellButton == true)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showSellDialog(asset!, controller),
                            icon: const Icon(Icons.sell, size: 18),
                            label: Text(
                              '${LKey.sellFor.tr} ${pandaAsset?.price} ${LKey.tokens.tr}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // NEW: View Details Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showPandaDetailsDialog(asset!, controller),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: Text(
                              LKey.viewDetails.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber,
                              side: const BorderSide(color: Colors.amber),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (pandaAsset?.isSellComingSoon == true)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                LKey.sellingComingSoon.tr,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // NEW: View Details Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showPandaDetailsDialog(asset!, controller),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: Text(
                              LKey.viewDetails.tr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber,
                              side: const BorderSide(color: Colors.amber),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Not Sellable',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // NEW: View Details Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showPandaDetailsDialog(asset!, controller),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: Text(
                              LKey.viewDetails.tr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber,
                              side: const BorderSide(color: Colors.amber),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Fusion Progress Section (for non-base tiers)
          if (!isBaseTier && fusionFrom != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Header with backend fusionProgress if available
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LKey.fusionProgress.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // FIXED: Use backend fusionProgress if available
                      Text(
                        asset?.fusionProgress ?? '$count / $fusionCount needed',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fusionCount <= 0
                          ? 0.0
                          : (count / fusionCount).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Fusion Info Text
                  Row(
                    children: [
                      Icon(
                        Icons.merge_type,
                        color: color.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Fuse $fusionCount ${fusionFrom}s → 1 $characterName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  // Fuse Button (when ready) - FIXED: Use backend canFuse field
                  if (asset?.canFuse == true || count >= fusionCount)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showFusionDialog(
                            characterName,
                            fusionFrom,
                            fusionCount,
                            controller,
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            LKey.fuseIntoNow.trParams({'name': characterName}),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Base Tier Info
          if (isBaseTier) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: color.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LKey.baseTierInfo.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// NEW: Build character image from local Android assets
  Widget _buildCharacterImage(String characterName) {
    // Map character names to asset file names
    // Note: Lion is stored as "loin.png" in assets
    final assetFileName = switch (characterName.toLowerCase()) {
      'cat' => 'cat.png',
      'dog' => 'dog.png',
      'tiger' => 'tiger.png',
      'lion' => 'loin.png', // Backend says "Lion" but file is "loin.png"
      'panda' => 'panda.png',
      _ => 'cat.png',
    };

    final assetPath = 'assets/mediapipe/$assetFileName';

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image fails to load
            debugPrint('[VAULT] Failed to load asset: $assetPath, error: $error');
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getGradientColors(characterName),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getIconForCharacter(characterName),
                color: Colors.white,
                size: 32,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Get gradient colors for character fallback
  List<Color> _getGradientColors(String characterName) {
    switch (characterName.toLowerCase()) {
      case 'panda':
        return [Colors.amber.shade400, Colors.orange.shade600];
      case 'lion':
        return [Colors.orange.shade400, Colors.deepOrange.shade600];
      case 'tiger':
        return [Colors.blue.shade400, Colors.indigo.shade600];
      case 'dog':
        return [Colors.grey.shade400, Colors.grey.shade600];
      case 'cat':
        return [Colors.brown.shade400, Colors.brown.shade600];
      default:
        return [Colors.grey.shade400, Colors.grey.shade600];
    }
  }

  /// Get icon for character fallback
  IconData _getIconForCharacter(String characterName) {
    switch (characterName.toLowerCase()) {
      case 'panda':
        return Icons.workspace_premium;
      case 'lion':
        return Icons.emoji_nature;
      case 'tiger':
        return Icons.filter_vintage;
      case 'dog':
      case 'cat':
        return Icons.pets;
      default:
        return Icons.pets;
    }
  }

  // NEW: Fusion Info Card - DYNAMIC from backend
  Widget _buildFusionInfoCard(ScratchCollectController controller) {
    final rules = controller.fusionRules;
    
    if (rules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.withValues(alpha: 0.2),
              Colors.blue.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                Text(
                  LKey.howFusionWorks.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              LKey.loadingFusionRules.tr,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withValues(alpha: 0.2),
            Colors.blue.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tips_and_updates,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                LKey.howFusionWorks.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // DYNAMIC: Build steps from backend fusion rules
          ...rules.map((rule) {
            final sourceName = rule.sourceAsset?.name ?? 'Unknown';
            final targetName = rule.targetAsset?.name ?? 'Unknown';
            final count = rule.sourceQuantity;
            final colors = _getFusionColors(targetName);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildFusionStep(
                '$count $sourceName',
                '1 $targetName',
                colors[0],
                colors[1],
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LKey.pandaUltimateGoal.tr,
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get colors based on target character
  List<Color> _getFusionColors(String characterName) {
    switch (characterName.toLowerCase()) {
      case 'cat':
        return [Colors.grey, Colors.blue];
      case 'tiger':
        return [Colors.blue, Colors.orange];
      case 'lion':
        return [Colors.orange, Colors.amber];
      case 'panda':
        return [Colors.amber, Colors.amber.shade700];
      default:
        return [Colors.brown, Colors.grey];
    }
  }

  Widget _buildFusionStep(String from, String to, Color fromColor, Color toColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: fromColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            from,
            style: TextStyle(
              color: fromColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.arrow_forward,
          color: Colors.white.withValues(alpha: 0.3),
          size: 16,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: toColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            to,
            style: TextStyle(
              color: toColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // NEW: History Tab - backend-synced history preferred, local as fallback
  Widget _buildHistoryTab(ScratchCollectController controller) {
    final remote = controller.remoteHistory;

    if (remote.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: remote.length,
        itemBuilder: (context, index) => _buildRemoteHistoryItem(remote[index]),
      );
    }

    final historyItems = controller.claimedRewardsHistory;

    if (historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              LKey.noHistoryYet.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LKey.startScratchingToBuildHistory.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyItems.length,
      itemBuilder: (context, index) {
        final item = historyItems[index];
        return _buildHistoryItemFromReward(item);
      },
    );
  }

  // FIXED: Build history item from ClaimedReward
  Widget _buildHistoryItemFromReward(ClaimedReward reward) {
    final isAsset = reward.isAsset;
    final timeAgo = _getTimeAgo(reward.claimedAt);
    final assetName = reward.asset?.name ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // FIXED: Show animal image for assets, token icon for tokens
          isAsset && assetName.isNotEmpty
            ? _buildCharacterImage(assetName)
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 28,
                ),
              ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAsset
                      ? 'Got ${reward.asset?.name ?? 'Asset'}'
                      : 'Won ${reward.tokenAmount?.toInt() ?? 0} Tokens',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${LKey.scratchCard.tr} • $timeAgo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Rarity badge for assets
          if (isAsset && reward.asset != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRarityColor(reward.asset!.rarity).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reward.asset!.rarity.name.toUpperCase(),
                style: TextStyle(
                  color: _getRarityColor(reward.asset!.rarity),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper to get color based on rarity
  Color _getRarityColor(AssetRarity rarity) {
    switch (rarity) {
      case AssetRarity.common:
        return Colors.grey;
      case AssetRarity.rare:
        return Colors.blue;
      case AssetRarity.legendary:
        return Colors.amber;
    }
  }

  /// History row from backend (claim / sell / fusion / redeem)
  Widget _buildRemoteHistoryItem(RewardHistoryItem item) {
    final (icon, color) = switch (item.type) {
      'sell' => (Icons.sell, Colors.green),
      'fusion' => (Icons.auto_awesome, Colors.purple),
      'redeem' => (Icons.currency_exchange, Colors.blue),
      _ => (Icons.card_giftcard, Colors.amber),
    };
    final timeAgo =
        item.createdAt != null ? _getTimeAgo(item.createdAt!) : '';
    final assetName = item.assetName ?? '';
    final hasAssetImage = item.rewardType == 'asset' && assetName.isNotEmpty;

    final String amountText;
    if (item.type == 'redeem' && item.cashAmount != null) {
      amountText = '+\$${item.cashAmount!.toStringAsFixed(2)}';
    } else if (item.tokenAmount != null && item.tokenAmount! > 0) {
      amountText = '+${item.tokenAmount!.toInt()} ${LKey.tokens.tr}';
    } else {
      amountText = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          hasAssetImage
              ? _buildCharacterImage(assetName)
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description?.isNotEmpty == true
                      ? item.description!
                      : item.type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.type} • $timeAgo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (amountText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                amountText,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Redeem tokens → wallet cash dialog
  // Backend enforces the same minimum — keep in sync.
  static const int _minRedeemTokens = 1000;

  void _showRedeemDialog(ScratchCollectController controller) {
    final balance = controller.tokenBalance.value.toInt();
    final rate = controller.settings.value.tokenToCashRate;
    final amountController =
        TextEditingController(text: balance > 0 ? '$balance' : '');
    int entered = balance;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              final cash = entered * rate;
              final canRedeem =
                  entered >= _minRedeemTokens && entered <= balance;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.currency_exchange,
                      size: 48, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    LKey.redeemTokens.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LKey.redeemToWallet.tr,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (v) =>
                        setState(() => entered = int.tryParse(v) ?? 0),
                    decoration: InputDecoration(
                      labelText: LKey.tokensToRedeem.tr,
                      labelStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      suffixText: '/ $balance',
                      suffixStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LKey.minRedeemHint.tr,
                    style: TextStyle(
                      color: entered > 0 && entered < _minRedeemTokens
                          ? Colors.orange
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${LKey.youWillGet.tr}: \$${cash.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white54),
                          child: Text(LKey.cancel.tr),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(() => ElevatedButton(
                              onPressed: canRedeem && !controller.isRedeeming.value
                                  ? () async {
                                      Get.back();
                                      final result =
                                          await controller.redeemTokens(entered);
                                      if (result != null) {
                                        _showRedeemResult(result);
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white12,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: controller.isRedeeming.value
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text(LKey.redeem.tr),
                            )),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showRedeemResult(RedeemResult result) {
    if (!result.success) {
      Get.snackbar(
        LKey.errorTitle.tr,
        result.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                child: const Icon(Icons.check, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                '+\$${result.cashCredited.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.message.isNotEmpty
                    ? result.message
                    : LKey.tokensInstantlyAdded.tr,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1a1a2e),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(LKey.continueText.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  // Header
  Widget _buildHeader(ScratchCollectController controller) {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF0a0a14),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  LKey.iYolVault.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            LKey.yourDigitalCollection.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          // Token Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.amber,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${controller.tokenBalance.value.toInt()} ${LKey.tokens.tr}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Daily streak chip
          if (controller.streakDays.value > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.deepOrange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.deepOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${controller.streakDays.value} ${LKey.dayStreak.tr}',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Redeem tokens → wallet cash
          TextButton.icon(
            onPressed: () => _showRedeemDialog(controller),
            icon: const Icon(
              Icons.currency_exchange,
              color: Colors.amber,
              size: 16,
            ),
            label: Text(
              LKey.redeemTokens.tr,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // NEW: Stats Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  LKey.assets.tr,
                  '${controller.userAssets.fold(0, (sum, a) => sum + a.quantity)}',
                  Icons.inventory_2,
                  Colors.purple,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _buildStatItem(
                  LKey.tokens.tr,
                  '${controller.tokenBalance.value.toInt()}',
                  Icons.monetization_on,
                  Colors.amber,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _buildStatItem(
                  LKey.valueLabel.tr,
                  '₹${controller.estimatedValue.value.toStringAsFixed(0)}',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sell Dialog
  void _showSellDialog(UserAsset userAsset, ScratchCollectController controller) {
    final asset = userAsset.asset;
    if (asset == null) return;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sell,
                size: 48,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                LKey.sellPanda.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sell 1 ${asset.name} for ${asset.price} Tokens?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.token,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${asset.price} Tokens',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                      ),
                      child: Text(LKey.cancel.tr),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        await controller.sellAsset(userAsset);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(LKey.sellNow.tr),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Panda Details Dialog
  void _showPandaDetailsDialog(UserAsset userAsset, ScratchCollectController controller) {
    final asset = userAsset.asset;
    
    // FIXED: Handle case when user has 0 Pandas (asset is null)
    final isPriceComingSoon = asset?.isPriceComingSoon ?? true;
    final isSellComingSoon = asset?.isSellComingSoon ?? true;
    final canSell = asset?.canSell ?? false;
    final price = asset?.price ?? LKey.comingSoon.tr;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // FIXED: Panda Image instead of icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/mediapipe/panda.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade400, Colors.orange.shade600],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          size: 48,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                LKey.pandaDetails.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                LKey.legendaryAssetUltimatePrize.tr,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                ),
              ),
              // Show message if user has no Pandas
              if (asset == null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(() {
                          // Find Panda fusion rule (Lion -> Panda)
                          final pandaRule = controller.fusionRules.firstWhereOrNull(
                            (rule) => rule.targetAsset?.name.toLowerCase() == 'panda',
                          );
                          final requiredLions = pandaRule?.sourceQuantity ?? 50;
                          final sourceName = pandaRule?.sourceAsset?.name ?? 'Lions';
                          
                          return Text(
                            'You don\'t have any Pandas yet. Fuse $requiredLions $sourceName to create one!',
                            style: const TextStyle(color: Colors.orange, fontSize: 12),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Value Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.token,
                          color: Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LKey.tokenValue.tr,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPriceComingSoon
                                    ? LKey.comingSoon.tr
                                    : '$price ${LKey.tokens.tr}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isPriceComingSoon) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.orange,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              LKey.priceAnnouncedByAdmin.tr,
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Selling Status Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: canSell
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canSell
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sell,
                          color: canSell ? Colors.green : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LKey.sellingStatus.tr,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSellComingSoon
                                    ? LKey.comingSoon.tr
                                    : canSell
                                        ? LKey.availableNow.tr
                                        : LKey.notAvailable.tr,
                                style: TextStyle(
                                  color: canSell ? Colors.green : Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isSellComingSoon) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              LKey.sellingEnabledByAdmin.tr,
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // How Selling Works
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LKey.howSellingWorks.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            LKey.onlyPandasCanBeSold.tr,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            LKey.sellAnytimePriceActive.tr,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            LKey.tokensInstantlyAdded.tr,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    LKey.gotIt.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fusion Dialog
  void _showFusionDialog(
    String targetCharacter,
    String sourceCharacter,
    int requiredCount,
    ScratchCollectController controller,
  ) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 48,
                color: Colors.purple,
              ),
              const SizedBox(height: 16),
              Text(
                'Fuse $sourceCharacter → $targetCharacter',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use $requiredCount $sourceCharacter to create 1 $targetCharacter?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                      ),
                      child: Text(LKey.cancel.tr),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _runFusion(targetCharacter, controller);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(LKey.fuseNow.tr),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolve the backend fusion rule for [targetCharacter] and run the real
  /// fuse API (previously this dialog only showed a "Fusion Started" toast).
  Future<void> _runFusion(
    String targetCharacter,
    ScratchCollectController controller,
  ) async {
    final target = targetCharacter.toLowerCase();
    final rule = controller.fusionRules.firstWhereOrNull((r) {
      final t = r.targetAsset?.name.toLowerCase() ?? '';
      // Handle backend "Loin" spelling for Lion
      if (target == 'lion') return t == 'lion' || t == 'loin';
      return t == target;
    });

    if (rule == null) {
      Get.snackbar(
        LKey.errorTitle.tr,
        LKey.fusionRuleUnavailable.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final result = await controller.fuseAssets(rule.id);
    if (result != null) {
      _showFusionResult(result);
    }
  }

  // Fusion Result Dialog
  void _showFusionResult(FusionResult result) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: result.success ? Colors.green : Colors.orange,
                  ),
                  child: Icon(
                    result.success ? Icons.check : Icons.close,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                result.success ? LKey.fusionSuccessful.tr : LKey.fusionFailed.tr,
                style: TextStyle(
                  color: result.success ? Colors.green : Colors.orange,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (result.success && result.newAsset != null) ...[
                const SizedBox(height: 16),
                _buildCharacterImage(result.newAsset!.name),
                const SizedBox(height: 8),
                Text(
                  result.newAsset!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1a1a2e),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(LKey.continueText.tr),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // Shimmer Loading
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1a1a2e),
      highlightColor: const Color(0xFF2a2a3e),
      child: ListView(
        padding: const EdgeInsets.only(top: 50),
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),
          for (int i = 0; i < 5; i++) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // NEW: Helper method for stats
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
