import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/scratch_card/reward_claim_dialog.dart';
import 'package:shortzz/screen/scratch_collect/scratch_collect_controller.dart';

class ProgressTrackerBar extends StatelessWidget {
  final VoidCallback? onScratchCardShown;

  const ProgressTrackerBar({
    super.key,
    this.onScratchCardShown,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ScratchCollectController());

    return Obx(() {
      final progress = controller.progressPercent;
      final canScratch = controller.canScratch;
      final remaining = controller.minReelsForScratch - controller.reelsWatched.value;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canScratch ? Colors.amber.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
            width: canScratch ? 2 : 1,
          ),
          boxShadow: canScratch
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      canScratch ? Icons.card_giftcard : Icons.play_circle_outline,
                      color: canScratch ? Colors.amber : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      canScratch ? 'Scratch Card Ready!' : 'Next Mystery Reward',
                      style: TextStyle(
                        color: canScratch ? Colors.amber : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (canScratch)
                  GestureDetector(
                    onTap: () => _showScratchCard(context, controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'OPEN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    '$remaining more',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            Stack(
              children: [
                // Background
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Progress
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 8,
                  width: (MediaQuery.of(context).size.width - 64) * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canScratch
                          ? [Colors.amber, Colors.orange]
                          : [Colors.purple, Colors.blue],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: canScratch
                        ? [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                // Dots for milestones
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      controller.minReelsForScratch,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < controller.reelsWatched.value
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  canScratch
                      ? 'Claim your scratch card now!'
                      : 'Watch $remaining more reels for a mystery reward',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: canScratch ? Colors.amber : Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _showScratchCard(BuildContext context, ScratchCollectController controller) async {
    onScratchCardShown?.call();
    await RewardClaimDialog.show(
      context,
      onClaimed: () {
        controller.decrementScratchCards();
        controller.resetProgress();
      },
    );
  }
}

class FloatingScratchCardButton extends StatelessWidget {
  final VoidCallback? onTap;

  const FloatingScratchCardButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ScratchCollectController>();

    return Obx(() {
      if (controller.scratchCardsAvailable.value == 0) {
        return const SizedBox.shrink();
      }

      return Positioned(
        right: 16,
        bottom: 100,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${controller.scratchCardsAvailable.value} Card${controller.scratchCardsAvailable.value > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.orange,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class MiniProgressBar extends StatelessWidget {
  const MiniProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ScratchCollectController>();

    return Obx(() {
      final progress = controller.progressPercent;
      final canScratch = controller.canScratch;

      if (canScratch) {
        return GestureDetector(
          onTap: () {
            RewardClaimDialog.show(context, onClaimed: () {
              controller.decrementScratchCards();
              controller.resetProgress();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  'OPEN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        width: 100,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.blue],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    });
  }
}
