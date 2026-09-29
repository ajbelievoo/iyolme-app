import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_border_round_icon.dart';
import 'package:shortzz/common/widget/dashed_circle_painter.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/camera_screen/camera_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class CameraBottomView extends StatelessWidget {
  final CameraScreenType cameraType;

  const CameraBottomView({super.key, required this.cameraType});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CameraScreenController>();
    final isReelType = cameraType == CameraScreenType.post;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter/Effect views
          Obx(() => IgnorePointer(
              ignoring: controller.isRecording.value,
              child: _buildFilterEffectViews(controller))),

          // Main control buttons
          Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gallery button / Undo
                Obx(() => IgnorePointer(
                      ignoring: controller.isRecording.value,
                      child: controller.isStartingRecording.value
                          ? InkWell(
                              onTap: controller.onUndo,
                              child: const SizedBox(
                                width: 37,
                                height: 37,
                                child: Icon(Icons.undo,
                                    color: Colors.white, size: 28),
                              ))
                          : CustomBorderRoundIcon(
                              image: AssetRes.icImage,
                              onTap: controller.onMediaTap),
                    )),

                // Recording control button
                _buildRecordingButton(controller),

                // Stop recording button
                Obx(() => IgnorePointer(
                    ignoring: controller.isRecording.value,
                    child: _buildStopRecordingButton(controller))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEffectViews(CameraScreenController controller) {
    return Obx(() {
      if (controller.isEffectShow.value) {
        return _EffectList(controller);
      }
      if (controller.isTriggerShow.value) {
        return _DeepArTriggerPanel(controller);
      }
      if (controller.isBeautyShow.value) {
        return _DeepArBeautyPanel(controller);
      }

      return const SizedBox();
    });
  }

  Widget _buildRecordingButton(CameraScreenController controller) {
    return RecordingControlButton(controller: controller);
  }

  Widget _buildStopRecordingButton(CameraScreenController controller) {
    return Obx(() {
      // Only show Next button if we have recorded chunks or recording started
      // User wants "Next" button even if not full.
      // logic: if isStartingRecording (session active)
      final showNext = controller.isStartingRecording.value;

      return Visibility(
        visible: showNext,
        replacement: const SizedBox(width: 37),
        child: InkWell(
          onTap: controller.onNextTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Next',
              style: TextStyleCustom.outFitSemiBold600(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _DeepArTriggerPanel extends StatelessWidget {
  final CameraScreenController controller;

  const _DeepArTriggerPanel(this.controller);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.deepArPresetTriggers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final t = controller.deepArPresetTriggers[index];
                return InkWell(
                  onTap: () => controller.fireDeepArTrigger(t),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: whitePure(context).withAlpha(22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: whitePure(context).withAlpha(80),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t,
                        style: TextStyleCustom.outFitRegular400(
                          color: whitePure(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => controller.deepArCustomTrigger.value = v,
                  style: TextStyleCustom.outFitRegular400(
                    color: whitePure(context),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Custom trigger',
                    hintStyle: TextStyleCustom.outFitRegular400(
                      color: whitePure(context).withAlpha(130),
                      fontSize: 13,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: whitePure(context).withAlpha(16),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: whitePure(context).withAlpha(40),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: whitePure(context).withAlpha(40),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: whitePure(context).withAlpha(120),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CustomBorderRoundIcon(
                image: AssetRes.icCheck,
                onTap: () => controller
                    .fireDeepArTrigger(controller.deepArCustomTrigger.value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeepArBeautyPanel extends StatefulWidget {
  final CameraScreenController controller;

  const _DeepArBeautyPanel(this.controller);

  @override
  State<_DeepArBeautyPanel> createState() => _DeepArBeautyPanelState();
}

class _DeepArBeautyPanelState extends State<_DeepArBeautyPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: Obx(() {
              final sliderValue =
                  (widget.controller.deepArSkinSmoothing.value.clamp(0.0, 1.0) *
                          99.0) +
                      1.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Beauty',
                        style: TextStyleCustom.outFitSemiBold600(
                          color: whitePure(context),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        sliderValue.round().toString(),
                        style: TextStyleCustom.outFitRegular400(
                          color: whitePure(context).withAlpha(180),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: sliderValue,
                    min: 1.0,
                    max: 100.0,
                    divisions: 99,
                    onChanged: (v) {
                      final normalized = ((v - 1.0) / 99.0).clamp(0.0, 1.0);
                      widget.controller.setDeepArBeautyParameter(
                          'skin_smoothing', normalized);
                    },
                    activeColor: whitePure(context),
                    inactiveColor: whitePure(context).withAlpha(60),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1 = natural, 100 = smooth',
                    style: TextStyleCustom.outFitRegular400(
                      color: whitePure(context).withAlpha(150),
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EffectList extends StatelessWidget {
  final CameraScreenController controller;

  const _EffectList(this.controller);

  @override
  Widget build(BuildContext context) {
    List<DeepARFilters> deepARFilters =
        controller.appSetting?.deepARFilters ?? [];
    deepARFilters.insert(
        0, DeepARFilters(id: -1, title: 'None', image: AssetRes.icNoFilter));
    return SizedBox(
      height: 89,
      child: ListView.builder(
        itemCount: deepARFilters.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          DeepARFilters effect = deepARFilters[index];

          return InkWell(
            onTap: () => controller.onSelectArEffect(effect),
            child: Obx(() {
              final isSelected = controller.selectedEffect.value == effect;
              controller.selectedEffect.value.id == effect.id;
              final borderColor =
                  whitePure(context).withAlpha(isSelected ? 255 : 76);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 79,
                height: 89,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Filter thumbnail
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: whitePure(context),
                          shape: BoxShape.circle,
                        ),
                        child: ClipSmoothRect(
                          radius: SmoothBorderRadius(cornerRadius: 30),
                          child: effect.id == -1
                              ? Image.asset(effect.image ?? '',
                                  height: 36, width: 36)
                              : Image.network(effect.image?.addBaseURL() ?? '',
                                  height: 36, width: 36),
                        ),
                      ),
                    ),

                    // Filter name
                    Text(
                      effect.title ?? '',
                      style: TextStyleCustom.outFitLight300(
                        color: whitePure(context),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class RecordingControlButton extends StatelessWidget {
  final CameraScreenController controller;

  const RecordingControlButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canRecord = !controller.isCameraBooting.value &&
          (!controller.useDeepAr || controller.isDeepARInitialized.value);

      debugPrint(
          '[RecordBtn] canRecord=$canRecord booting=${controller.isCameraBooting.value} useDeepAr=${controller.useDeepAr} deepArInit=${controller.isDeepARInitialized.value} isRecording=${controller.isRecording.value} isStarting=${controller.isStartingRecording.value}');
      return SizedBox(
        width: 90,
        height: 90,
        child: GestureDetector(
          onTap: () {
            if (!canRecord) {
              debugPrint('[RecordBtn] tap ignored: canRecord=false');
              return;
            }
            // Tap-to-toggle recording for reels: start/pause/resume anytime.
            controller.onPlayPauseToggle();
          },
          onVerticalDragStart: (details) {
            if (!canRecord) return;
            controller.startRecordZoomDrag();
          },
          onVerticalDragUpdate: (details) {
            if (!canRecord) return;
            controller.updateRecordZoomDrag(details.delta.dy);
          },
          onVerticalDragEnd: (_) {
            if (!canRecord) return;
            controller.endRecordZoomDrag();
          },
          child: CustomPaint(
            painter: DashedCirclePainter(
                controller.progress / controller.selectedSecond.value),
            child: Center(
              child: Obx(() {
                if (controller.isStartingRecording.value &&
                    !controller.isRecording.value) {
                  // Session paused -> Show Record icon to resume
                  return _buildRecordButton();
                }

                return controller.isRecording.value
                    ? _buildPauseIndicator(
                        context) // Active recording -> Show Pause/Stop
                    : _buildRecordButton(); // Idle -> Show Record
              }),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPauseIndicator(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(2, (index) {
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 3),
            child: Container(
              height: 30,
              width: 12,
              decoration: ShapeDecoration(
                color: whitePure(context),
                shape: SmoothRectangleBorder(
                  borderRadius:
                      SmoothBorderRadius(cornerRadius: 2, cornerSmoothing: 1),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Container(
      width: 65,
      height: 65,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      ),
    );
  }
}
