import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/camera_screen/camera_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class CameraRightView extends StatelessWidget {
  const CameraRightView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CameraScreenController>();
    final isStory = controller.cameraType == CameraScreenType.story;

    final h = MediaQuery.of(context).size.height;
    final top = (h * 0.12).clamp(16.0, 80.0);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: top, right: 10),
        child: Align(
          alignment: Alignment.topRight,
          child: Obx(() {
            final isRecording = controller.isRecording.value;
            // Hide tools when recording
            if (isRecording) return const SizedBox();

            final expanded = controller.isToolsExpanded.value;

            return Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                // 1. Text (Story Mode Only)
                if (isStory)
                  _buildToolItem(
                    context,
                    icon: AssetRes.icText,
                    label: 'Aa',
                    onTap: controller.onNavigateTextStory,
                  ),

                // 2. Audio
                if (controller.selectedMusic.value == null)
                  _buildToolItem(
                    context,
                    icon: AssetRes.icMusic,
                    label: 'Audio',
                    onTap: controller.onMusicTap,
                  ),

                // 3. Beauty
                if (controller.useDeepAr)
                  _buildToolItem(
                    context,
                    icon: AssetRes.icStar,
                    label: 'Beauty',
                    isActive: controller.isBeautyShow.value,
                    onTap: controller.onBeautyToggle,
                  ),

                // 4. Effects
                if (controller.useDeepAr)
                  _buildToolItem(
                    context,
                    icon: AssetRes.icFilter,
                    label: 'Effects',
                    isActive: controller.isEffectShow.value,
                    onTap: controller.onEffectToggle,
                  ),

                // 5. Length / Timer (Reel Mode Only)
                if (!isStory && controller.isSecondListShow.value)
                  _buildToolItem(
                    context,
                    label: 'Length',
                    child: _buildDurationBadge(context, controller),
                    onTap: () {
                      final current = controller.selectedSecond.value;
                      final list = controller.secondsList;
                      final index = list.indexOf(current);
                      final nextIndex = (index + 1) % list.length;
                      controller.selectedSecond.value = list[nextIndex];
                    },
                  ),

                // 6. Speed (Reel Mode Only)
                if (!isStory)
                  _buildToolItem(
                    context,
                    label: 'Speed',
                    child: _buildSpeedIcon(context, controller),
                    onTap: () => _showSpeedSheet(context, controller),
                  ),

                // 7. Gesture Control
                _buildToolItem(
                  context,
                  child: Icon(Icons.back_hand,
                      color: controller.isGestureControlEnabled.value
                          ? Colors.blue
                          : Colors.white,
                      size: 22),
                  label: 'Gesture',
                  isActive: controller.isGestureControlEnabled.value,
                  onTap: controller.onGestureToggle,
                ),

                // Expandable items
                if (expanded) ...[
                  // Flash
                  _buildToolItem(
                    context,
                    icon: controller.isTorchOn.value
                        ? AssetRes.icNoFlash
                        : AssetRes.icFlash,
                    label: 'Flash',
                    onTap: controller.onToggleFlash,
                  ),

                  // Flip
                  _buildToolItem(
                    context,
                    icon: AssetRes.icCameraFlip,
                    label: 'Flip',
                    onTap: controller.onToggleCamera,
                  ),
                  
                  if (isStory)
                     _buildToolItem(
                        context,
                        child: const Icon(Icons.grid_3x3, color: Colors.white, size: 22),
                        label: 'Layout',
                        onTap: () {
                          // Placeholder for Layout mode
                          Get.snackbar('Layout', 'Coming soon');
                        },
                      ),
                ],

                // Toggle Button
                _buildToolItem(
                  context,
                  child: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: expanded ? 'Close' : 'More',
                  onTap: controller.onToggleTools,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSpeedIcon(
      BuildContext context, CameraScreenController controller) {
    return Text(
      '${controller.recordingSpeed.value}x',
      style: TextStyleCustom.outFitBold700(
        fontSize: 12,
        color: Colors.white,
      ),
    );
  }

  void _showSpeedSheet(
      BuildContext context, CameraScreenController controller) {
    Get.bottomSheet(
      Container(
        color: blackPure(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Recording Speed',
                style: TextStyleCustom.outFitSemiBold600(
                    color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [0.3, 0.5, 1.0, 2.0, 3.0].map((speed) {
                return InkWell(
                  onTap: () {
                    controller.onSpeedChange(speed);
                    Get.back();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: controller.recordingSpeed.value == speed
                          ? Colors.white
                          : Colors.white10,
                    ),
                    child: Text(
                      '${speed}x',
                      style: TextStyleCustom.outFitSemiBold600(
                          color: controller.recordingSpeed.value == speed
                              ? Colors.black
                              : Colors.white,
                          fontSize: 14),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToolItem(
    BuildContext context, {
    String? icon,
    String? label,
    Widget? child,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.transparent,
              border:
                  isActive ? null : Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: child ??
                (icon != null
                    ? Image.asset(
                        icon,
                        width: 22,
                        height: 22,
                        color: isActive ? Colors.black : Colors.white,
                      )
                    : const SizedBox()),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyleCustom.outFitRegular400(
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationBadge(
      BuildContext context, CameraScreenController controller) {
    return Text(
      '${controller.selectedSecond.value}s',
      style: TextStyleCustom.outFitBold700(
        fontSize: 12,
        color: Colors.white,
      ),
    );
  }
}
