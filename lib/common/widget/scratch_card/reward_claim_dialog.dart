import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shortzz/common/service/api/scratch_collect_service.dart';
import 'package:shortzz/model/scratch_collect/scratch_collect_models.dart';

/// Full screen scratch card reward dialog
/// - Shows full screen overlay (hides ads/reels completely)
/// - Interactive finger scratching
/// - Algorithm-based rewards from backend
/// - Claim button only active after scratching
class RewardClaimDialog extends StatefulWidget {
  final VoidCallback? onClaimed;

  const RewardClaimDialog({super.key, this.onClaimed});

  static Future<void> show(BuildContext context, {VoidCallback? onClaimed}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.98), // Dark overlay hides ads/reels
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: RewardClaimDialog(onClaimed: onClaimed),
        );
      },
    );
  }

  @override
  State<RewardClaimDialog> createState() => _RewardClaimDialogState();
}

class _RewardClaimDialogState extends State<RewardClaimDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _confettiController;

  // Scratch state
  final List<ScratchPoint> _scratchPoints = [];
  bool _isScratching = false;
  double _scratchProgress = 0.0;
  bool _isScratchedEnough = false;

  // Reward state - ALGORITHM DECIDES ON INIT
  bool _isLoading = true;
  bool _isClaiming = false;
  bool _rewardRevealed = false;
  ClaimedReward? _reward;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Full screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // ALGORITHM: Backend decides reward NOW (before user sees)
    _fetchRewardFromAlgorithm();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  /// ALGORITHM-BASED: Fetch reward from backend on init
  Future<void> _fetchRewardFromAlgorithm() async {
    try {
      final reward = await ScratchCollectService.instance.claimReward();
      setState(() {
        _reward = reward;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reward. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Calculate scratch progress
  void _calculateScratchProgress() {
    if (_scratchPoints.isEmpty) return;

    // Count active scratch points
    int activePoints = 0;
    for (int i = 0; i < _scratchPoints.length; i++) {
      if (_scratchPoints[i].isActive) activePoints++;
    }

    // Approximate coverage (each point covers roughly 25*25 = 625 pixels)
    // Card is 280x280 = 78400 pixels
    final coverage = (activePoints * 625) / 78400;
    final progress = coverage.clamp(0.0, 1.0);

    setState(() {
      _scratchProgress = progress;
      if (progress >= 0.35 && !_isScratchedEnough) {
        _isScratchedEnough = true;
      }
    });
  }

  /// Claim the reward after scratching
  Future<void> _claimReward() async {
    if (!_isScratchedEnough || _isClaiming) return;

    setState(() {
      _isClaiming = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _rewardRevealed = true;
      _isClaiming = false;
    });

    // Confetti for legendary
    if (_reward?.isAsset == true && _reward?.asset?.rarity == AssetRarity.legendary) {
      _confettiController.forward();
    }

    widget.onClaimed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                          fontSize: 32,
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
                      else
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
                                // Hidden reward (underneath)
                                _buildHiddenReward(),

                                // Scratchable silver layer
                                if (!_rewardRevealed)
                                  GestureDetector(
                                    onPanDown: (details) {
                                      setState(() {
                                        _isScratching = true;
                                        _scratchPoints.add(ScratchPoint(
                                          details.localPosition,
                                          true,
                                        ));
                                      });
                                      _calculateScratchProgress();
                                    },
                                    onPanUpdate: (details) {
                                      setState(() {
                                        _scratchPoints.add(ScratchPoint(
                                          details.localPosition,
                                          true,
                                        ));
                                      });
                                      _calculateScratchProgress();
                                    },
                                    onPanEnd: (details) {
                                      setState(() {
                                        _isScratching = false;
                                        _scratchPoints.add(ScratchPoint(
                                          Offset.zero,
                                          false,
                                        ));
                                      });
                                    },
                                    child: CustomPaint(
                                      size: const Size(280, 280),
                                      painter: ScratchLayerPainter(
                                        points: _scratchPoints,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Progress indicator
                      if (!_rewardRevealed && !_isLoading) ...[
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _scratchProgress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.amber, Colors.orange],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_scratchProgress * 100).toInt()}% scratched',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
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

                      // Claim Button (only active after scratching)
                      if (!_rewardRevealed && !_isLoading)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isScratchedEnough
                                  ? 1.0 + (_pulseController.value * 0.05)
                                  : 1.0,
                              child: ElevatedButton(
                                onPressed: _isScratchedEnough && !_isClaiming
                                    ? _claimReward
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isScratchedEnough
                                      ? const Color(0xFFe94560)
                                      : Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 64,
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: _isScratchedEnough ? 8 : 0,
                                ),
                                child: _isClaiming
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _isScratchedEnough
                                            ? 'Claim Reward!'
                                            : 'Scratch More...',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),

                      // Close button after claiming
                      if (_rewardRevealed)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1a1a2e),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 64,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Awesome!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Close button (top right)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 24,
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
                child: _reward!.asset?.imageUrl != null
                    ? Image.network(
                        _reward!.asset!.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderAsset(),
                      )
                    : _buildPlaceholderAsset(),
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

  ScratchLayerPainter({required this.points});

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
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 25
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

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
  }

  void _drawMetallicPattern(Canvas canvas, Size size) {
    // Diagonal lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    for (double i = -size.height; i < size.width; i += 15) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }

    // Sparkle effects
    final random = Random(42);
    for (int i = 0; i < 30; i++) {
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
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
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
