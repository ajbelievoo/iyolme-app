import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/ads_controller.dart';
import 'package:shortzz/common/service/api/scratch_collect_service.dart';
import 'package:shortzz/model/scratch_collect/scratch_collect_models.dart';
import 'package:shortzz/screen/scratch_collect/scratch_collect_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Inline Scratch Card page for reels feed (like ads)
/// - Appears inline in reels feed
/// - 70% scratch threshold for claim button
/// - Auto-smooth clear remaining 30%
/// - Professional design centered
class ReelScratchCardPage extends StatefulWidget {
  final VoidCallback? onComplete;

  const ReelScratchCardPage({super.key, this.onComplete});

  @override
  State<ReelScratchCardPage> createState() => _ReelScratchCardPageState();
}

class _ReelScratchCardPageState extends State<ReelScratchCardPage>
    with TickerProviderStateMixin {
  late AnimationController _autoClearController;
  late AnimationController _confettiController;

  // Scratch state
  final List<Offset> _scratchPoints = [];
  double _scratchProgress = 0.0;
  bool _isScratchedEnough = false;
  bool _isAutoClearing = false;
  bool _isAdWatched = false;
  bool _isWaitingForAd = false;

  // Reward state - ALGORITHM DECIDES ON INIT
  bool _isLoading = true;
  bool _isClaiming = false;
  bool _rewardRevealed = false;
  bool _cardShown = false;
  ClaimedReward? _reward;
  String? _error;

  @override
  void initState() {
    super.initState();
    
    // FIXED: Pause video when scratch card opens (only if controller exists)
    if (Get.isRegistered<ReelsScreenController>()) {
      final reelsController = Get.find<ReelsScreenController>();
      reelsController.pauseCurrentVideo();
    }
    
    _autoClearController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // ALGORITHM: Backend decides reward NOW
    _fetchRewardFromAlgorithm();
  }

  @override
  void dispose() {
    // FIXED: Resume video when scratch card closes (only if controller exists)
    if (Get.isRegistered<ReelsScreenController>()) {
      final reelsController = Get.find<ReelsScreenController>();
      reelsController.resumeCurrentVideo();
    }
    
    _autoClearController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  /// Stores reward from initial fetch - don't call API again when claiming
  ClaimedReward? _previewReward;

  /// FIXED: Fetch reward from backend on init so user can see what they won
  Future<void> _fetchRewardFromAlgorithm() async {
    debugPrint('[SCRATCH_FETCH] Fetching reward from backend...');
    
    try {
      // Fetch the reward from backend (this also reserves it)
      final reward = await ScratchCollectService.instance.claimReward();
      
      if (!mounted) return;
      
      debugPrint('[SCRATCH_FETCH] Reward fetched: isToken=${reward.isToken}, amount=${reward.tokenAmount}, asset=${reward.asset?.name}');
      
      setState(() {
        _previewReward = reward; // Store for later claim
        _reward = reward;
        _isLoading = false;
        _cardShown = true;
      });
    } catch (e) {
      debugPrint('[SCRATCH_FETCH] Error fetching reward: $e');
      if (!mounted) return;
      // Surface the server message (e.g. "Daily limit reached. Come back
      // tomorrow!") instead of a generic error.
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _isLoading = false;
        _cardShown = true;
        _error = msg.isNotEmpty
            ? msg
            : 'Failed to load reward. Please try again.';
      });
    }
  }

  /// Check if reward is claimable (has actual value)
  bool get _hasValidReward {
    if (_reward == null) return false;
    if (_reward!.isToken) {
      return (_reward!.tokenAmount ?? 0) > 0;
    }
    return _reward!.asset != null;
  }

  /// Calculate scratch progress - FIXED: requires more points for 70%
  void _calculateScratchProgress() {
    if (_scratchPoints.isEmpty) return;

    // Count all scratch points as active
    final activePoints = _scratchPoints.length;

    // FIXED: Better coverage calculation (card is 280x280 = 78400px)
    // Each scratch point with 35px radius covers ~3850px (pi * r^2)
    // But with overlap, actual coverage is less
    // We need ~200-250 points for 70% coverage (accounting for overlap)
    const totalCardArea = 280 * 280; // 78400
    const pointCoverageArea = 3800; // approx area per point with some overlap
    final coverage = (activePoints * pointCoverageArea) / totalCardArea;
    final progress = coverage.clamp(0.0, 1.0);

    setState(() {
      _scratchProgress = progress;
      if (progress >= 0.70 && !_isScratchedEnough) {
        _isScratchedEnough = true;
        _startAutoClear();
      }
    });
  }

  /// Auto clear remaining 30% smoothly and quickly
  void _startAutoClear() {
    setState(() {
      _isAutoClearing = true;
    });

    // Faster animation - 400ms for quick smooth clear
    _autoClearController.duration = const Duration(milliseconds: 400);
    
    // Animate remaining scratch with more points for smoother effect
    _autoClearController.addListener(() {
      if (!mounted) return;
      setState(() {
        if (_autoClearController.value < 1.0) {
          final random = Random();
          // More points per frame = smoother and faster clear
          final pointsToAdd = 20 + (random.nextInt(15)); // 20-35 points per frame
          
          for (int i = 0; i < pointsToAdd; i++) {
            // Add random scratch points for auto-clear
            final x = random.nextDouble() * 280;
            final y = random.nextDouble() * 280;
            
            // Add multiple connected points for line effect
            _scratchPoints.add(Offset(x, y));
            _scratchPoints.add(Offset(
              x + random.nextDouble() * 40 - 20, 
              y + random.nextDouble() * 40 - 20
            ));
            _scratchPoints.add(Offset(
              x + random.nextDouble() * 40 - 20, 
              y + random.nextDouble() * 40 - 20
            ));
          }
        }
      });
    });

    _autoClearController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _isAutoClearing = false;
      });
    });
  }

  /// Claim the reward after scratching and watching ad
  Future<void> _claimReward() async {
    if (!_isScratchedEnough || _isClaiming || _isWaitingForAd) return;

    // FIXED: Show ad first, then claim reward after ad is watched
    if (!_isAdWatched) {
      setState(() {
        _isWaitingForAd = true;
      });
      await _showRewardAd();
      return; // Wait for ad callback to proceed
    }

    // NOW claim the reward from backend (after ad is watched)
    setState(() {
      _isClaiming = true;
    });

    try {
      // FIXED: Use the already-fetched reward, don't call API again!
      final reward = _previewReward;
      if (reward == null) {
        setState(() {
          _error = 'No reward found. Please try again.';
          _isClaiming = false;
        });
        return;
      }
      
      if (!mounted) return;
      
      setState(() {
        _reward = reward;
        _rewardRevealed = true;
        _isClaiming = false;
      });

      // Confetti for legendary
      if (reward.isAsset && reward.asset?.rarity == AssetRarity.legendary) {
        _confettiController.forward();
      }

      // Record that user scratched a card today
      final scratchController = Get.find<ScratchCollectController>();
      scratchController.recordScratchCardUsed();
      
      // Add to history
      scratchController.addClaimedRewardToHistory(reward);

      // Refresh vault to show newly claimed asset - FIXED: Add delay and retry
      if (reward.isAsset) {
        debugPrint('[SCRATCH_REWARD] Refreshing vault data...');
        await scratchController.fetchVaultData();
        
        // FIXED: Wait a bit and refresh again to ensure backend has updated
        await Future.delayed(const Duration(seconds: 1));
        await scratchController.fetchVaultData();
        debugPrint('[SCRATCH_REWARD] Vault refreshed after claim');
      }

      // Auto dismiss after 2 seconds so the user can see the reward.
      // NOTE: call onComplete only once — a second call would remove the next
      // feed item at the same index.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          widget.onComplete?.call();
        }
      });
    } catch (e) {
      debugPrint('[SCRATCH_REWARD] Error claiming reward: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to claim reward. Please try again.';
        _isClaiming = false;
      });
    }
  }

  /// Show reward ad - FIXED: Uses AdsController.showRewardedAd for proper handling
  Future<void> _showRewardAd() async {
    debugPrint('[SCRATCH_AD] Showing reward ad via AdsController...');
    
    try {
      final adsController = Get.find<AdsController>();
      final reelsController = Get.isRegistered<ReelsScreenController>() 
          ? Get.find<ReelsScreenController>() 
          : null;
      
      // FIXED: Ensure reel stays paused during ad
      reelsController?.pauseCurrentVideo();
      
      // FIXED: Use the proper showRewardedAd method from AdsController
      final rewardEarned = await adsController.showRewardedAd(
        onRewardEarned: (reward) {
          debugPrint('[SCRATCH_AD] User earned reward: ${reward.amount} ${reward.type}');
          _onAdWatched();
        },
      );
      
      // If no reward earned (ad dismissed without watching)
      if (!rewardEarned) {
        debugPrint('[SCRATCH_AD] Ad dismissed without reward');
        setState(() {
          _isWaitingForAd = false;
        });
      }
    } catch (e) {
      debugPrint('[SCRATCH_AD] Error showing rewarded ad: $e');
      // Fallback on error - proceed without ad
      _onAdWatched();
    }
  }

  /// Called when ad is successfully watched
  void _onAdWatched() {
    debugPrint('[SCRATCH_AD] Ad watched successfully!');
    setState(() {
      _isAdWatched = true;
      _isWaitingForAd = false;
    });
    // Now proceed to claim reward
    _claimReward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackPure(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0d0d1a),
              Color(0xFF1a1a3e),
              Color(0xFF0d0d1a),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Confetti for legendary wins
              if (_rewardRevealed && _reward?.asset?.rarity == AssetRarity.legendary)
                Positioned.fill(
                  child: CustomPaint(
                    painter: ConfettiPainter(_confettiController),
                    size: Size.infinite,
                  ),
                ),

              // Main content - Centered
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      const Text(
                        'Mystery Reward',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scratch to reveal your prize!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Loading state
                      if (_isLoading)
                        Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a1a2e),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.amber),
                            ),
                          ),
                        )
                      else if (_cardShown)
                        // Scratch Card Container
                        Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _isScratchedEnough
                                    ? Colors.amber.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.1),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Hidden reward (underneath) - ALWAYS SHOW
                                SizedBox(
                                  width: 280,
                                  height: 280,
                                  child: _buildHiddenReward(),
                                ),

                                // Scratchable silver layer - FIXED: Use ClipPath to reveal reward
                                if (!_rewardRevealed)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanDown: (details) {
                                        setState(() {
                                          _scratchPoints.add(details.localPosition);
                                        });
                                        _calculateScratchProgress();
                                      },
                                      onPanUpdate: (details) {
                                        setState(() {
                                          _scratchPoints.add(details.localPosition);
                                        });
                                        _calculateScratchProgress();
                                      },
                                      child: ClipPath(
                                        clipper: ScratchRevealClipper(
                                          scratchPoints: _scratchPoints,
                                          isAutoClearing: _isAutoClearing,
                                        ),
                                        child: Container(
                                          width: 280,
                                          height: 280,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFc0c0c0),
                                                Color(0xFFe8e8e8),
                                                Color(0xFFa0a0a0),
                                                Color(0xFFd0d0d0),
                                              ],
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.touch_app,
                                                size: 48,
                                                color: Colors.white.withValues(
                                                  alpha: _scratchPoints.length > 100 
                                                    ? 0.3 
                                                    : 0.6
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'SCRATCH HERE',
                                                style: TextStyle(
                                                  color: Colors.black38.withValues(
                                                    alpha: _scratchPoints.length > 100 
                                                      ? 0.3 
                                                      : 1.0
                                                  ),
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Progress indicator
                      if (!_rewardRevealed && !_isLoading && _cardShown) ...[
                        Container(
                          width: 200,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _scratchProgress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.amber, Colors.orange],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_scratchProgress * 100).toInt()}% scratched${_isAutoClearing ? ' (auto-clearing...)' : ''}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Error message
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // FIXED: Show appropriate message based on reward validity
                      // - Valid reward + scratched enough = Claim button
                      // - Valid reward + not scratched = Keep Scratching
                      // - No valid reward (0 tokens) = Try Again / Good Luck message
                      if (!_rewardRevealed && !_isLoading && _cardShown)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: _isScratchedEnough && _hasValidReward
                              ? [BoxShadow(
                                  color: const Color(0xFFe94560).withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )]
                              : null,
                          ),
                          child: _hasValidReward
                            // Valid reward - show claim button
                            ? ElevatedButton(
                                onPressed: _isScratchedEnough && !_isClaiming && !_isWaitingForAd
                                    ? _claimReward
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isScratchedEnough
                                      ? const Color(0xFFe94560)
                                      : Colors.grey[700],
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[800],
                                  disabledForegroundColor: Colors.grey[500],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: _isScratchedEnough ? 8 : 2,
                                ),
                                child: _isClaiming
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _isWaitingForAd
                                            ? 'Watching Ad...'
                                            : (_isScratchedEnough
                                                ? (_isAdWatched ? 'CLAIM REWARD!' : 'WATCH AD TO CLAIM')
                                                : 'Keep Scratching...'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              )
                            // No valid reward (0 tokens) - show message instead of button
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.grey[600]!,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.sentiment_dissatisfied,
                                      color: Colors.grey[400],
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isScratchedEnough
                                          ? 'Good Luck Next Time!'
                                          : 'Scratch to Reveal...',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    if (_isScratchedEnough) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'No reward this time',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                        ),

                      // Success message
                      if (_rewardRevealed)
                        Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Reward Claimed!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Auto-closing in 2 seconds...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenReward() {
    if (_reward == null) {
      return Container(
        color: const Color(0xFF1a1a2e),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.amber),
          ),
        ),
      );
    }

    if (_reward!.isToken) {
      return Container(
        color: const Color(0xFF1a1a2e),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber[400]!, Colors.orange[600]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.monetization_on,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_reward!.tokenAmount?.toInt() ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Tokens',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    } else {
      final isLegendary = _reward!.asset?.rarity == AssetRarity.legendary;
      final assetName = _reward!.asset?.name ?? '';
      
      // FIXED: Map asset name to local image file
      final assetFileName = switch (assetName.toLowerCase()) {
        'cat' => 'cat.png',
        'dog' => 'dog.png',
        'tiger' => 'tiger.png',
        'lion' => 'loin.png', // Backend says "Lion" but file is "loin.png"
        'panda' => 'panda.png',
        _ => null,
      };
      
      return Container(
        color: const Color(0xFF1a1a2e),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: isLegendary
                    ? Border.all(color: Colors.amber, width: 3)
                    : null,
                boxShadow: isLegendary
                    ? [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: assetFileName != null
                    ? Image.asset(
                        'assets/mediapipe/$assetFileName',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderAsset(),
                      )
                    : (_reward!.asset?.imageUrl != null
                        ? Image.network(
                            _reward!.asset!.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholderAsset(),
                          )
                        : _buildPlaceholderAsset()),
              ),
            ),
            const SizedBox(height: 16),
            if (isLegendary)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'LEGENDARY!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _reward!.asset?.name ?? 'Mystery Asset',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPlaceholderAsset() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.card_giftcard,
          size: 50,
          color: Colors.white54,
        ),
      ),
    );
  }
}

/// Scratch point data
class ScratchPoint {
  final Offset offset;
  final bool isActive;

  ScratchPoint(this.offset, this.isActive);
}

/// Painter for scratchable silver layer
class ScratchLayerPainter extends CustomPainter {
  final List<ScratchPoint> points;
  final bool isAutoClearing;

  ScratchLayerPainter({
    required this.points,
    this.isAutoClearing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base silver metallic layer
    final baseRect = Rect.fromLTWH(0, 0, size.width, size.height);
    const baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFE8E8E8),
        Color(0xFFB8B8B8),
        Color(0xFFD0D0D0),
        Color(0xFFE8E8E8),
      ],
      stops: [0.0, 0.3, 0.7, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(baseRect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(baseRect, basePaint);

    // Metallic pattern overlay
    _drawMetallicPattern(canvas, size);

    // Scratch paths (transparent to reveal underneath)
    final scratchPaint = Paint()
      ..blendMode = BlendMode.srcOut
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 35
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Draw scratch lines
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].isActive && points[i + 1].isActive) {
        canvas.drawLine(
          points[i].offset,
          points[i + 1].offset,
          scratchPaint,
        );
      }
    }

    // Auto-clear effect
    if (isAutoClearing) {
      final autoClearPaint = Paint()
        ..blendMode = BlendMode.srcOut
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.7,
        autoClearPaint,
      );
    }
  }

  void _drawMetallicPattern(Canvas canvas, Size size) {
    // Diagonal lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    for (double i = -size.height; i < size.width; i += 12) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }

    // Sparkle effects
    final random = Random(42);
    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleSize = random.nextDouble() * 2 + 0.5;

      final sparklePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2 + random.nextDouble() * 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), sparkleSize, sparklePaint);
    }

    // "Scratch to Reveal" text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'SCRATCH HERE',
        style: TextStyle(
          color: Colors.black38,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ScratchLayerPainter oldDelegate) => true;
}

// Confetti painter
class ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final List<ConfettiParticle> particles;
  final Random random = Random();

  ConfettiPainter(this.animation)
      : particles = List.generate(
          100,
          (index) => ConfettiParticle(
            x: Random().nextDouble() * 400,
            y: Random().nextDouble() * 800 - 800,
            color: [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.orange,
              Colors.pink,
              Colors.amber,
              Colors.cyan,
              Colors.lime,
            ][Random().nextInt(10)],
            size: Random().nextDouble() * 10 + 5,
            speed: Random().nextDouble() * 4 + 3,
            angle: Random().nextDouble() * 2 * pi,
          ),
        ),
        super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;

    for (final particle in particles) {
      final y = particle.y + particle.speed * progress * 300;
      final x = particle.x + sin(particle.angle + progress * 6) * 30;
      final rotation = progress * 6 * pi;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: 1 - progress * 0.3);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ConfettiParticle {
  final double x;
  final double y;
  final Color color;
  final double size;
  final double speed;
  final double angle;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speed,
    required this.angle,
  });
}

// Custom clipper for scratch effect
class ScratchClipper extends CustomClipper<Path> {
  final List<Offset> points;
  final bool isAutoClearing;

  ScratchClipper(this.points, this.isAutoClearing);

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // If no points, return full rect (silver layer fully visible, reward hidden)
    if (points.isEmpty) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    // Create path from scratch points (circles at each point)
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      // Add circle for each scratch point (35 radius for brush size)
      path.addOval(Rect.fromCircle(center: point, radius: 35));
    }

    // If auto-clearing, add large circle in center
    if (isAutoClearing) {
      path.addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width * 0.8,
      ));
    }

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

/// FIXED: Clipper that KEEPS the silver layer UNLESS scratched (reveals reward underneath)
class ScratchRevealClipper extends CustomClipper<Path> {
  final List<Offset> scratchPoints;
  final bool isAutoClearing;

  ScratchRevealClipper({
    required this.scratchPoints,
    this.isAutoClearing = false,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Start with full rect (entire silver layer visible)
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // If no scratch points, show full silver layer
    if (scratchPoints.isEmpty && !isAutoClearing) {
      return path;
    }
    
    // Create holes where user scratched using PathOperation.difference
    // This REMOVES the scratched areas from the silver layer
    final holesPath = Path();
    
    for (final point in scratchPoints) {
      // Add hole (circle at scratch point)
      holesPath.addOval(Rect.fromCircle(center: point, radius: 35));
    }
    
    // Auto-clear: add large circle in center
    if (isAutoClearing) {
      holesPath.addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width * 0.9,
      ));
    }
    
    // Return path with holes (silver layer will NOT be drawn in holes)
    // The holes reveal the reward widget underneath
    return Path.combine(
      PathOperation.difference,
      path, // Full silver layer
      holesPath, // Minus the holes
    );
  }

  @override
  bool shouldReclip(covariant ScratchRevealClipper oldClipper) => true;
}

// Keep old class for backwards compatibility but mark as deprecated
@deprecated
class ScratchCardPainter extends CustomPainter {
  final List<Offset> scratchPoints;
  final bool isAutoClearing;
  final ClaimedReward? reward;

  ScratchCardPainter({
    required this.scratchPoints,
    this.isAutoClearing = false,
    this.reward,
  });

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
