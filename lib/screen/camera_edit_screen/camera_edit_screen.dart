import 'dart:async';
import 'dart:math' as math;

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_border_round_icon.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/location/location_service.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/common/service/video_timeline/video_segment.dart';
import 'package:shortzz/model/general/location_place_model.dart';
import 'package:shortzz/screen/camera_edit_screen/camera_edit_screen_controller.dart';
import 'package:shortzz/screen/camera_edit_screen/text_story/story_text_view.dart';
import 'package:shortzz/screen/camera_edit_screen/text_story/story_text_view_controller.dart';
import 'package:shortzz/screen/camera_edit_screen/text_story/widget/text_editor_sheet.dart';
import 'package:shortzz/screen/camera_screen/camera_screen_controller.dart';
import 'package:shortzz/screen/camera_screen/widget/camera_top_view.dart';
import 'package:shortzz/screen/color_filter_screen/color_filter_view.dart';
import 'package:shortzz/screen/gif_sheet/gif_sheet.dart';
import 'package:shortzz/screen/gif_sheet/gif_sheet_controller.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:shortzz/screen/sticker_sheet/sticker_sheet.dart';
import 'package:shortzz/screen/sticker_sheet/sticker_sheet_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:video_player/video_player.dart';

import '../../common/extensions/string_extension.dart';

class CameraEditScreen extends StatelessWidget {
  final PostStoryContent content;

  const CameraEditScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CameraEditScreenController(content.obs));
    if (!Get.isRegistered<StoryTextViewController>()) {
      Get.put(StoryTextViewController(controller));
    }
    final type = controller.content.value.type;
    final isVideoType = [
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type);

    if (isVideoType) {
      return WillPopScope(
        onWillPop: () async {
          if (controller.isEditorMode.value) {
            controller.exitEditorMode();
            return false;
          }
          Get.back();
          return false;
        },
        child: Scaffold(
          backgroundColor: blackPure(context),
          resizeToAvoidBottomInset:
              false, // Prevent layout resize on keyboard open
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GenerateContentView(controller: controller),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            // Top Bar (Close & Undo/Redo)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (controller.isEditorMode.value) {
                                      controller.exitEditorMode();
                                    } else {
                                      Get.back();
                                    }
                                  },
                                  child: Container(
                                    height: 36,
                                    width: 36,
                                    decoration: BoxDecoration(
                                      color: blackPure(context)
                                          .withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Obx(() => Icon(
                                          controller.isEditorMode.value
                                              ? Icons
                                                  .keyboard_arrow_down_rounded
                                              : Icons.arrow_back_rounded,
                                          color: whitePure(context),
                                          size: 20,
                                        )),
                                  ),
                                ),
                                // Undo/Redo Buttons
                                Obx(() {
                                  if (!controller.isEditorMode.value) {
                                    return const SizedBox();
                                  }
                                  return Row(
                                    children: [
                                      // Undo
                                      IgnorePointer(
                                        ignoring: !controller.canUndo,
                                        child: InkWell(
                                          onTap: controller.undo,
                                          child: Opacity(
                                            opacity:
                                                controller.canUndo ? 1.0 : 0.4,
                                            child: Container(
                                              height: 36,
                                              width: 36,
                                              margin: const EdgeInsets.only(
                                                  right: 10),
                                              decoration: BoxDecoration(
                                                color: blackPure(context)
                                                    .withValues(alpha: 0.45),
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.undo_rounded,
                                                color: whitePure(context),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Redo
                                      IgnorePointer(
                                        ignoring: !controller.canRedo,
                                        child: InkWell(
                                          onTap: controller.redo,
                                          child: Opacity(
                                            opacity:
                                                controller.canRedo ? 1.0 : 0.4,
                                            child: Container(
                                              height: 36,
                                              width: 36,
                                              decoration: BoxDecoration(
                                                color: blackPure(context)
                                                    .withValues(alpha: 0.45),
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.redo_rounded,
                                                color: whitePure(context),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Sidebar Tools
                    Obx(() {
                      if (controller.isEditorMode.value) {
                        return const SizedBox();
                      }
                      return Positioned(
                        right: 10,
                        top: 60,
                        bottom: 120,
                        child: CameraEditRightSidebar(controller: controller),
                      );
                    }),
                    // Bottom Bar (Edit Video)
                    Obx(() {
                      if (controller.isEditorMode.value) {
                        return const SizedBox();
                      }
                      return _ReelPreviewBottomBar(controller: controller);
                    }),
                    
                    // Instagram Style Bottom Bar - only for stories, not reels
                    Obx(() {
                      final type = controller.content.value.type;
                      final isReel = type == PostStoryContentType.reel;
                      if (controller.isEditorMode.value || isReel) {
                        return const SizedBox();
                      }
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _InstagramStyleStoryBottomBar(controller: controller),
                      );
                    }),

                    // Filter View (Overlay)
                    FilterAndMusicView(controller: controller),

                    // Loading Overlay when processing video
                    Obx(() {
                      if (controller.isMergingVideo.value) {
                        return Container(
                          color: Colors.black.withValues(alpha: 0.7),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Processing video...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    }),

                    // Fixed Editor Panel at Bottom (Overlay)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Obx(() {
                        if (controller.isEditorMode.value) {
                          return _FixedEditorPanel(controller: controller);
                        }
                        return const SizedBox();
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6.0, vertical: 20),
                child: Stack(
                  children: [
                    GenerateContentView(controller: controller),
                    Positioned(
                      right: 10,
                      top: 60,
                      bottom: 120,
                      child: CameraEditRightSidebar(controller: controller),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CameraEditTopViewTools(controller: controller),
                        FilterAndMusicView(controller: controller)
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _InstagramStyleStoryBottomBar(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _InstagramStyleStoryBottomBar extends StatelessWidget {
  final CameraEditScreenController controller;

  const _InstagramStyleStoryBottomBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final myUser = SessionManager.instance.getUser();
    final type = controller.content.value.type;
    final isReel = type == PostStoryContentType.reel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isReel) ...[
            // Reel: No buttons here - Next is in _ReelPreviewBottomBar
            const SizedBox.shrink(),
          ] else ...[
            // Story: Show Your Story and Close Friends buttons
            Expanded(
              child: InkWell(
                onTap: () {
                  controller.setStoryAudience(StoryAudience.public);
                  controller.handleContentUpload();
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CustomImage(
                            image: myUser?.profilePhoto,
                            size: const Size(24, 24),
                          ),
                       ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Story',
                        style: TextStyleCustom.outFitMedium500(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () {
                  controller.setStoryAudience(StoryAudience.closeFriends);
                  controller.handleContentUpload();
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Close Friends',
                        style: TextStyleCustom.outFitMedium500(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
           const SizedBox(width: 10),
           InkWell(
             onTap: () {
                 // Discard or other options
                 controller.onDiscard();
             },
             child: Container(
               height: 44,
               width: 44,
               decoration: BoxDecoration(
                 color: Colors.white.withValues(alpha: 0.15),
                 shape: BoxShape.circle,
               ),
               child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
             ),
           ),
        ],
      ),
    );
  }
}

class _ReelPreviewBottomBar extends StatelessWidget {
  final CameraEditScreenController controller;

  const _ReelPreviewBottomBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final type = controller.content.value.type;
    final isReel = type == PostStoryContentType.reel;

    return Positioned(
      left: 14,
      right: 14,
      bottom: 14 + bottomPad,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Edit button
          InkWell(
            onTap: () {
              controller.enterEditorMode();
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: whitePure(context).withAlpha(16),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: whitePure(context).withAlpha(26)),
              ),
              alignment: Alignment.center,
              child: Text(
                'Edit video',
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context).withAlpha(240),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          // Right: Next button (for reels only)
          if (isReel)
            Obx(() {
              final isProcessing = controller.isMergingVideo.value;
              return AbsorbPointer(
                absorbing: isProcessing,
                child: Opacity(
                  opacity: isProcessing ? 0.5 : 1.0,
                  child: InkWell(
                    onTap: isProcessing
                        ? null
                        : () {
                            controller.handleReelUpload();
                          },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isProcessing ? 'Processing...' : 'Next',
                            style: TextStyleCustom.outFitMedium500(
                              color: Colors.black,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.black, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _FixedEditorPanel extends StatelessWidget {
  final CameraEditScreenController controller;

  const _FixedEditorPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    // We use a simpler approach: Flexible for the timeline area to prevent overflow
    // The panel itself will take available space but no more than needed.
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: blackPure(context),
        border: Border(
          top: BorderSide(color: whitePure(context).withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              // Timeline Area
              // We remove the hard constraint to allow the timeline to expand naturally
              // The SingleChildScrollView above handles the scrolling if it gets too tall.
              _ReelEditorTimeline(controller: controller),
              const SizedBox(height: 6),
              // Tools Row
              Obx(() {
                return SizedBox(
                  height: 64,
                  child: controller.clipToolsVisible.value
                      ? _VideoEditToolsRow(controller: controller)
                      : const SizedBox(),
                );
              }),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelEditorBottomSheet extends StatefulWidget {
  final CameraEditScreenController controller;

  const _ReelEditorBottomSheet({required this.controller});

  @override
  State<_ReelEditorBottomSheet> createState() => _ReelEditorBottomSheetState();
}

class _ReelEditorBottomSheetState extends State<_ReelEditorBottomSheet> {
  final DraggableScrollableController _sheet = DraggableScrollableController();
  Worker? _modeWorker;
  double? _lastTarget;

  void _animateTo(double size) {
    try {
      _sheet.animateTo(
        size.clamp(0.12, 0.80),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();

    // Initialize the sheet size once (avoid animating inside build which causes jank).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.controller.isEditorMode.value ? 0.56 : 0.18;
      _lastTarget = target;
      _animateTo(target);
    });

    _modeWorker = ever<bool>(widget.controller.isEditorMode, (inEditor) {
      final target = inEditor ? 0.56 : 0.18;
      if (_lastTarget == target) return;
      _lastTarget = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _animateTo(target);
      });
    });
  }

  @override
  void dispose() {
    _modeWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final inEditor = widget.controller.isEditorMode.value;
      final target = inEditor ? 0.56 : 0.18;
      return DraggableScrollableSheet(
        controller: _sheet,
        initialChildSize: target,
        minChildSize: 0.18,
        maxChildSize: 0.80,
        snap: true,
        snapSizes: const [0.18, 0.56, 0.80],
        builder: (context, scrollController) {
          final bottomPad = MediaQuery.of(context).padding.bottom;
          return LayoutBuilder(builder: (context, c) {
            final compact = c.maxHeight < 140;
            return Container(
              decoration: BoxDecoration(
                color: blackPure(context).withAlpha(220),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border.all(color: whitePure(context).withAlpha(26)),
              ),
              child: ListView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  bottom: bottomPad > 0 ? bottomPad : 0,
                ),
                children: [
                  SizedBox(height: compact ? 6 : 8),
                  Center(
                    child: Container(
                      height: 4,
                      width: 36,
                      decoration: BoxDecoration(
                        color: whitePure(context).withAlpha(90),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  if (inEditor) ...[
                    _ReelEditorTimeline(controller: widget.controller),
                    const SizedBox(height: 10),
                    Obx(() {
                      if (!widget.controller.clipToolsVisible.value) {
                        return const SizedBox(height: 1);
                      }
                      return _VideoEditToolsRow(controller: widget.controller);
                    }),
                    const SizedBox(height: 10),
                  ] else
                    _ReelEditorToolbar(
                      controller: widget.controller,
                      onEnterEditor: () {
                        widget.controller.enterEditorMode();
                        _animateTo(0.56);
                      },
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          });
        },
      );
    });
  }
}

class _ReelEditorToolbar extends StatelessWidget {
  final CameraEditScreenController controller;
  final VoidCallback onEnterEditor;

  const _ReelEditorToolbar(
      {required this.controller, required this.onEnterEditor});

  Widget _btn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: whitePure(context).withAlpha(14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: whitePure(context).withAlpha(26)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: whitePure(context), size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(context).withAlpha(220),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Obx(() {
              final inEditor = controller.isEditorMode.value;
              return _btn(
                context,
                icon: Icons.content_cut_rounded,
                label: 'Edit',
                onTap: () {
                  if (!inEditor) {
                    onEnterEditor();
                    return;
                  }
                  Get.bottomSheet(
                    _AdvancedEditSheet(controller: controller),
                    isScrollControlled: true,
                    ignoreSafeArea: false,
                    enableDrag: true,
                  );
                },
              );
            }),
            _btn(
              context,
              icon: Icons.add_box_outlined,
              label: 'Add clips',
              onTap: controller.addSegmentFromGallery,
            ),
            _btn(
              context,
              icon: Icons.picture_in_picture_alt_rounded,
              label: 'Overlay',
              onTap: controller.pickPipVideoFromGallery,
            ),
            _btn(
              context,
              icon: Icons.library_music_outlined,
              label: 'Audio',
              onTap: controller.handleMusicSelection,
            ),
            _btn(
              context,
              icon: Icons.title_rounded,
              label: 'Text',
              onTap: () => controller.onNewTexFieldAdd?.call(),
            ),
            _btn(
              context,
              icon: Icons.emoji_emotions_outlined,
              label: 'Stickers',
              onTap: () {
                StoryTextViewController? text;
                try {
                  text = Get.find<StoryTextViewController>();
                } catch (_) {
                  text = null;
                }
                if (text == null) {
                  controller.showSnackBar('Stickers not available');
                  return;
                }
                Get.bottomSheet(
                  _StickerSheet(textController: text, controller: controller),
                  isScrollControlled: true,
                  ignoreSafeArea: false,
                  enableDrag: true,
                );
              },
            ),
            _btn(
              context,
              icon: Icons.closed_caption_outlined,
              label: 'Captions',
              onTap: () {
                StoryTextViewController? text;
                try {
                  text = Get.find<StoryTextViewController>();
                } catch (_) {
                  text = null;
                }
                if (text == null) {
                  controller.showSnackBar('Captions not available');
                  return;
                }
                final d = TextWidgetData(text: 'Caption');
                text.textWidgets.add(d);
                controller.registerTextClipForWidget(d);
              },
            ),
            _btn(
              context,
              icon: Icons.mic_none_rounded,
              label: 'Voice',
              onTap: () {
                Get.bottomSheet(
                  _VoiceoverSheet(controller: controller),
                  isScrollControlled: true,
                  ignoreSafeArea: false,
                  enableDrag: true,
                );
              },
            ),
            _btn(
              context,
              icon: Icons.color_lens_outlined,
              label: 'LUT',
              onTap: () {
                Get.bottomSheet(
                  _LutSheet(controller: controller),
                  isScrollControlled: true,
                  ignoreSafeArea: false,
                  enableDrag: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelEditorTimeline extends StatefulWidget {
  final CameraEditScreenController controller;

  const _ReelEditorTimeline({required this.controller});

  @override
  State<_ReelEditorTimeline> createState() => _ReelEditorTimelineState();
}

class _ReelEditorTimelineState extends State<_ReelEditorTimeline> {
  final ScrollController _h = ScrollController();
  VideoPlayerController? _attached;
  double _viewportW = 0.0;
  Timer? _debounce;
  bool _userScrolling = false;
  Worker? _vpWorker;
  bool _programmaticScroll = false;
  Timer? _seekDebounce;
  double _scaleStartPxPerSec = 80.0;
  double _scaleStartFocusMs = 0.0;
  bool _wasPlayingBeforeScrub = false;
  final Set<int> _pointers = {};

  double _pxPerSec = 80.0;

  double get _pxPerMs => _pxPerSec / 1000.0;
  double get _msPerPx => 1000.0 / _pxPerSec;
  double get _edgePad => _viewportW <= 0 ? 0.0 : (_viewportW / 2);

  @override
  void initState() {
    super.initState();
    _attach(widget.controller.videoPlayerController.value);
    _vpWorker = ever<VideoPlayerController?>(
      widget.controller.videoPlayerController,
      (c) => _attach(c),
    );
    _h.addListener(_onTimelineScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = widget.controller.videoPlayerController.value;
      final ms = (c?.value.isInitialized == true)
          ? c!.value.position.inMilliseconds
          : 0;
      _scrollToMs(ms, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant _ReelEditorTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.controller.videoPlayerController.value;
    if (!identical(next, _attached)) {
      _attach(next);
    }
  }

  void _attach(VideoPlayerController? c) {
    try {
      _attached?.removeListener(_onVideoTick);
    } catch (_) {}
    _attached = c;
    try {
      _attached?.addListener(_onVideoTick);
    } catch (_) {}
  }

  int _lastScrollTime = 0;

  void _onVideoTick() {
    final c = _attached;
    if (c == null || !c.value.isInitialized) return;
    if (!c.value.isPlaying) return;
    if (!_h.hasClients) return;
    if (_viewportW <= 0) return;
    if (_userScrolling) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrollTime < 32) return; // Throttle to ~30fps
    _lastScrollTime = now;

    if (!mounted) return;
    final posMs = c.value.position.inMilliseconds;
    final contentX = _edgePad + (posMs * _pxPerMs);
    final target = (contentX - (_viewportW / 2)).clamp(
      0.0,
      _h.position.maxScrollExtent,
    );

    // Avoid micro-jumps that cause layout thrashing
    if ((target - _h.offset).abs() < 2.0) return;

    try {
      _programmaticScroll = true;
      _h.jumpTo(target);
    } catch (_) {}
    _programmaticScroll = false;
  }

  Future<void> _seekToMs(int ms) async {
    final c = widget.controller.videoPlayerController.value;
    if (c == null || !c.value.isInitialized) return;
    final totalMs = widget.controller.timelineTotalMs;
    final clamped = ms.clamp(0, totalMs);

    try {
      await c.seekTo(Duration(milliseconds: clamped));
    } catch (_) {}

    final sound = widget.controller.content.value.sound;
    if (sound != null) {
      final start = sound.audioStartMS ?? 0;
      try {
        widget.controller.audioPlayer.seekTo(start + clamped);
      } catch (_) {}
    }
  }

  void _scrollToMs(int ms, {bool animate = true}) {
    if (!_h.hasClients || _viewportW <= 0) return;
    final totalMs = widget.controller.timelineTotalMs;
    final clamped = ms.clamp(0, totalMs);
    final x = (_edgePad + (clamped * _pxPerMs)) - (_viewportW / 2);
    final target = x.clamp(0.0, _h.position.maxScrollExtent);
    try {
      _programmaticScroll = true;
      if (animate) {
        _h.animateTo(
          target,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      } else {
        _h.jumpTo(target);
      }
    } catch (_) {}
    _programmaticScroll = false;
  }

  void _onTimelineScroll() {
    if (!_h.hasClients) return;
    if (_viewportW <= 0) return;
    if (_programmaticScroll) return;
    if (!_userScrolling) return;

    final offset = _h.offset;
    final centerX = offset + (_viewportW / 2);
    final ms = ((centerX - _edgePad) / _pxPerMs).round();
    final totalMs = widget.controller.timelineTotalMs;
    final clamped = ms.clamp(0, totalMs);

    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 90), () async {
      await _seekToMs(clamped);
    });
  }

  void _beginUserScrub() {
    _userScrolling = true;
    _debounce?.cancel();
    _seekDebounce?.cancel();

    final c = widget.controller.videoPlayerController.value;
    _wasPlayingBeforeScrub = c?.value.isPlaying ?? false;
    try {
      c?.pause();
    } catch (_) {}
    if (widget.controller.content.value.sound != null) {
      try {
        widget.controller.audioPlayer.pausePlayer();
      } catch (_) {}
    }
  }

  void _endUserScrub() {
    Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _userScrolling = false;
      if (_wasPlayingBeforeScrub) {
        try {
          widget.controller.videoPlayerController.value?.play();
        } catch (_) {}
        if (widget.controller.content.value.sound != null) {
          try {
            widget.controller.audioPlayer.startPlayer(forceRefresh: false);
          } catch (_) {}
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _seekDebounce?.cancel();
    _vpWorker?.dispose();
    try {
      _attached?.removeListener(_onVideoTick);
    } catch (_) {}
    try {
      _h.removeListener(_onTimelineScroll);
    } catch (_) {}
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return LayoutBuilder(builder: (context, c) {
      _viewportW = c.maxWidth;
      final totalMs = controller.timelineTotalMs;
      final totalW =
          math.max((totalMs * _pxPerMs) + 140.0, c.maxWidth).toDouble();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          color: blackPure(context).withAlpha(190),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: whitePure(context).withAlpha(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final vp = controller.videoPlayerController.value;
              if (vp == null) return const SizedBox(height: 34);

              return ValueListenableBuilder(
                valueListenable: vp,
                builder: (context, val, child) {
                  final pos = val.position;
                  final dur = val.duration;
                  return Row(
                    children: [
                      InkWell(
                        onTap: controller.onPlayPauseToggle,
                        child: Container(
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: whitePure(context).withAlpha(14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: whitePure(context).withAlpha(26)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            val.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: whitePure(context),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_fmtTime(pos)} / ${_fmtTime(dur)}',
                        style: TextStyleCustom.outFitRegular400(
                          color: whitePure(context).withAlpha(220),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: controller.splitAtCurrentPosition,
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: themeAccentSolid(context).withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    themeAccentSolid(context).withAlpha(120)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.content_cut_rounded,
                              color: whitePure(context), size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          final centerMs = (_h.hasClients && _viewportW > 0)
                              ? ((_h.offset + (_viewportW / 2) - _edgePad) /
                                  _pxPerMs)
                              : 0.0;
                          setState(() {
                            _pxPerSec = (_pxPerSec / 1.8).clamp(8.0, 1200.0);
                          });
                          _scrollToMs(centerMs.round(), animate: false);
                        },
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: whitePure(context).withAlpha(12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: whitePure(context).withAlpha(22)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.remove_rounded,
                              color: whitePure(context).withAlpha(220),
                              size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          final centerMs = (_h.hasClients && _viewportW > 0)
                              ? ((_h.offset + (_viewportW / 2) - _edgePad) /
                                  _pxPerMs)
                              : 0.0;
                          setState(() {
                            _pxPerSec = (_pxPerSec * 1.8).clamp(8.0, 1200.0);
                          });
                          _scrollToMs(centerMs.round(), animate: false);
                        },
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: whitePure(context).withAlpha(12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: whitePure(context).withAlpha(22)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.add_rounded,
                              color: whitePure(context).withAlpha(220),
                              size: 18),
                        ),
                      ),
                    ],
                  );
                },
              );
            }),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (_programmaticScroll) return false;
                  if (n is ScrollStartNotification) {
                    _beginUserScrub();
                  } else if (n is ScrollEndNotification) {
                    _endUserScrub();
                  }
                  return false;
                },
                child: Listener(
                  onPointerDown: (e) =>
                      setState(() => _pointers.add(e.pointer)),
                  onPointerUp: (e) =>
                      setState(() => _pointers.remove(e.pointer)),
                  onPointerCancel: (e) =>
                      setState(() => _pointers.remove(e.pointer)),
                  child: Stack(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {},
                        onScaleStart: (d) {
                          _scaleStartPxPerSec = _pxPerSec;
                          if (_h.hasClients && _viewportW > 0) {
                            final focalX = _h.offset + d.localFocalPoint.dx;
                            _scaleStartFocusMs = (focalX - _edgePad) / _pxPerMs;
                          } else {
                            _scaleStartFocusMs = 0.0;
                          }
                        },
                        onScaleUpdate: (d) {
                          if (d.scale == 1.0) return;
                          final next = (_scaleStartPxPerSec * d.scale)
                              .clamp(8.0, 1200.0)
                              .toDouble();
                          setState(() {
                            _pxPerSec = next;
                          });
                          if (_h.hasClients && _viewportW > 0) {
                            final newPxPerMs = _pxPerSec / 1000.0;
                            final contentX =
                                _edgePad + (_scaleStartFocusMs * newPxPerMs);
                            final newOffset = contentX - d.localFocalPoint.dx;
                            _programmaticScroll = true;
                            _h.jumpTo(newOffset.clamp(
                                0.0, _h.position.maxScrollExtent));
                            _programmaticScroll = false;
                          }
                        },
                        child: SingleChildScrollView(
                          controller: _h,
                          scrollDirection: Axis.horizontal,
                          physics: _pointers.length >= 2
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: totalW + (_edgePad * 2),
                            child: Column(
                              children: [
                                const SizedBox(height: 0),
                                SizedBox(
                                  height: 24,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: _edgePad),
                                    child: Builder(builder: (context) {
                                      final durationSec =
                                          (totalMs / 1000.0).ceil();
                                      int step = 1;
                                      if (_pxPerSec < 15) {
                                        step = 10;
                                      } else if (_pxPerSec < 30) {
                                        step = 5;
                                      } else if (_pxPerSec < 60) {
                                        step = 2;
                                      }
                                      return Stack(
                                        children: List.generate(
                                          (durationSec / step).ceil() + 1,
                                          (index) {
                                            final i = index * step;
                                            return Positioned(
                                              left: i * _pxPerSec,
                                              top: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding: const EdgeInsets.only(
                                                    left: 2),
                                                alignment: Alignment.bottomLeft,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _fmtDuration(i),
                                                      style: TextStyleCustom
                                                          .outFitRegular400(
                                                        color:
                                                            whitePure(context)
                                                                .withAlpha(120),
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 2),
                                                      width: 1,
                                                      height: 6,
                                                      color: whitePure(context)
                                                          .withAlpha(60),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 54,
                                  child: Obx(() {
                                    final segs = controller.segments;
                                    final selectedIndex =
                                        controller.activeSegmentIndex.value;
                                    double cursor = 0;
                                    final children = <Widget>[];
                                    for (var i = 0; i < segs.length; i++) {
                                      final seg = segs[i];
                                      final w = (seg.durationSec * _pxPerSec)
                                          .toDouble();

                                      double overlap = 0;
                                      if (i > 0 &&
                                          seg.edits.transition !=
                                              VideoTransitionType.none) {
                                        overlap = 0.5 * _pxPerSec;
                                      }

                                      final left = _edgePad + cursor - overlap;
                                      final startMs =
                                          ((left - _edgePad) / _pxPerSec * 1000)
                                              .round();
                                      cursor = cursor - overlap + w;

                                      final isSelected = selectedIndex == i;
                                      children.add(
                                        Positioned(
                                          left: left,
                                          top: 0,
                                          bottom: 0,
                                          width: w,
                                          child: _DraggableClip(
                                            startMs: startMs,
                                            durationMs: (seg.durationSec * 1000)
                                                .round(),
                                            msPerPx: _msPerPx,
                                            label:
                                                '${seg.durationSec.toStringAsFixed(1)}s',
                                            isSelected: isSelected,
                                            color: blackPure(context)
                                                .withAlpha(150),
                                            borderColor: whitePure(context)
                                                .withAlpha(40),
                                            onTap: () =>
                                                controller.userSelectSegment(i),
                                            onDragStart: (newStart, end) {},
                                            onResizeDuration: (newDur, end) {
                                              if (end) {
                                                final delta = (newDur -
                                                        (seg.durationSec *
                                                            1000)) /
                                                    1000.0;
                                                controller.trimActiveSegment(
                                                    0, delta);
                                              }
                                            },
                                            onResizeLeft:
                                                (newStart, newDur, end) {
                                              if (end) {
                                                final delta =
                                                    ((seg.durationSec * 1000) -
                                                            newDur) /
                                                        1000.0;
                                                controller.trimActiveSegment(
                                                    delta, 0);
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                      if (i < segs.length - 1) {
                                        children.add(
                                          Positioned(
                                            left: left + w - 10,
                                            top: 18,
                                            width: 20,
                                            height: 20,
                                            child: InkWell(
                                              onTap: () {
                                                Get.bottomSheet(
                                                  _InsertBetweenSheet(
                                                    controller: controller,
                                                    insertAfterIndex: i,
                                                  ),
                                                  isScrollControlled: true,
                                                  ignoreSafeArea: false,
                                                  enableDrag: true,
                                                );
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: blackPure(context)
                                                      .withAlpha(200),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: whitePure(context)
                                                        .withAlpha(90),
                                                  ),
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.add_rounded,
                                                  size: 16,
                                                  color: whitePure(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    children.add(
                                      Positioned(
                                        left: _edgePad + cursor + 6,
                                        top: 0,
                                        bottom: 0,
                                        width: 42,
                                        child: InkWell(
                                          onTap:
                                              controller.addSegmentFromGallery,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: whitePure(context)
                                                  .withAlpha(10),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: whitePure(context)
                                                    .withAlpha(40),
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: whitePure(context),
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                    return Stack(children: children);
                                  }),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 34,
                                  child: Obx(() {
                                    final hasMusic =
                                        controller.content.value.sound != null;
                                    final musicStartMs = controller.content
                                            .value.sound?.audioStartMS ??
                                        0;
                                    final musicDurMs = (controller.content.value
                                                    .sound?.duration ??
                                                (totalMs / 1000))
                                            .toInt() *
                                        1000;
                                    final effectiveDurMs =
                                        musicDurMs > 0 ? musicDurMs : totalMs;
                                    return Stack(
                                      children: [
                                        Positioned(
                                          left: _edgePad,
                                          top: 0,
                                          bottom: 0,
                                          right: 0,
                                          child: InkWell(
                                            onTap:
                                                controller.handleMusicSelection,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: whitePure(context)
                                                    .withAlpha(8),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: whitePure(context)
                                                      .withAlpha(18),
                                                ),
                                              ),
                                              alignment: Alignment.centerLeft,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              child: Text(
                                                hasMusic ? '' : '+  Add audio',
                                                style: TextStyleCustom
                                                    .outFitRegular400(
                                                  color: whitePure(context)
                                                      .withAlpha(160),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (hasMusic)
                                          Positioned(
                                            left: _edgePad +
                                                (musicStartMs * _pxPerMs),
                                            top: 3,
                                            bottom: 3,
                                            child: _DraggableClip(
                                              startMs: musicStartMs,
                                              durationMs: effectiveDurMs,
                                              msPerPx: 1.0 / _pxPerMs,
                                              label: 'Audio',
                                              isSelected: false,
                                              color: Colors.blueAccent
                                                  .withValues(alpha: 0.5),
                                              borderColor: Colors.blueAccent,
                                              onDragStart: (newStart, end) {
                                                final next =
                                                    newStart.clamp(0, totalMs);
                                                if (end) {
                                                  controller
                                                      .setMusicStartMs(next);
                                                }
                                              },
                                              onResizeDuration: (newDur, end) {
                                                if (end) {
                                                  controller
                                                      .setMusicDuration(newDur);
                                                }
                                              },
                                              onResizeLeft:
                                                  (newStart, newDur, end) {
                                                if (end) {
                                                  controller.setMusicStartMs(
                                                      newStart);
                                                  controller
                                                      .setMusicDuration(newDur);
                                                }
                                              },
                                              onTap: controller
                                                  .handleMusicSelection,
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 34,
                                  child: Obx(() {
                                    final textClips = controller.textClips;
                                    final hasText = textClips.isNotEmpty;
                                    return Stack(
                                      children: [
                                        Positioned(
                                          left: _edgePad,
                                          top: 0,
                                          bottom: 0,
                                          right: 0,
                                          child: InkWell(
                                            onTap: () => controller
                                                .onNewTexFieldAdd
                                                ?.call(),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: whitePure(context)
                                                    .withAlpha(8),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: whitePure(context)
                                                      .withAlpha(18),
                                                ),
                                              ),
                                              alignment: Alignment.centerLeft,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              child: hasText
                                                  ? null
                                                  : Text(
                                                      '+  Add text',
                                                      style: TextStyleCustom
                                                          .outFitRegular400(
                                                        color:
                                                            whitePure(context)
                                                                .withAlpha(160),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        ...textClips.map((clip) {
                                          final textData = Get.find<
                                                  StoryTextViewController>()
                                              .textWidgets
                                              .firstWhereOrNull(
                                                  (t) => t.id == clip.id);
                                          final label =
                                              textData?.text ?? 'Text';
                                          final isSelected = controller
                                                  .selectedTextClipId.value ==
                                              clip.id;
                                          return Positioned(
                                            left: _edgePad +
                                                (clip.startMs * _pxPerMs),
                                            top: 3,
                                            bottom: 3,
                                            child: _DraggableClip(
                                              startMs: clip.startMs,
                                              durationMs: clip.durationMs,
                                              msPerPx: 1.0 / _pxPerMs,
                                              label: label,
                                              isSelected: isSelected,
                                              color: Colors.purple
                                                  .withValues(alpha: 0.6),
                                              borderColor: Colors.purpleAccent,
                                              onDragStart: (newStart, end) {
                                                if (!isSelected) {
                                                  controller
                                                      .selectTextClip(clip.id);
                                                }
                                                if (end) {
                                                  controller
                                                      .updateTextClipWithUndo(
                                                    clip.id,
                                                    startMs: newStart,
                                                  );
                                                  controller
                                                      .videoPlayerController
                                                      .value
                                                      ?.seekTo(Duration(
                                                          milliseconds:
                                                              newStart));
                                                } else {
                                                  controller.updateTextClip(
                                                    clip.id,
                                                    startMs: newStart,
                                                  );
                                                }
                                              },
                                              onResizeDuration: (newDur, end) {
                                                if (!isSelected) {
                                                  controller
                                                      .selectTextClip(clip.id);
                                                }
                                                if (end) {
                                                  controller
                                                      .updateTextClipWithUndo(
                                                    clip.id,
                                                    durationMs: newDur,
                                                  );
                                                } else {
                                                  controller.updateTextClip(
                                                    clip.id,
                                                    durationMs: newDur,
                                                  );
                                                }
                                              },
                                              onResizeLeft:
                                                  (newStart, newDur, end) {
                                                if (!isSelected) {
                                                  controller
                                                      .selectTextClip(clip.id);
                                                }
                                                if (end) {
                                                  controller
                                                      .updateTextClipWithUndo(
                                                    clip.id,
                                                    startMs: newStart,
                                                    durationMs: newDur,
                                                  );
                                                  controller
                                                      .videoPlayerController
                                                      .value
                                                      ?.seekTo(Duration(
                                                          milliseconds:
                                                              newStart));
                                                } else {
                                                  controller.updateTextClip(
                                                    clip.id,
                                                    startMs: newStart,
                                                    durationMs: newDur,
                                                  );
                                                }
                                              },
                                              onTap: () => controller
                                                  .selectTextClip(clip.id),
                                            ),
                                          );
                                        }),
                                      ],
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 2,
                            height: double.infinity,
                            margin: const EdgeInsets.only(top: 18),
                            decoration: BoxDecoration(
                              color: whitePure(context).withAlpha(235),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _fmtDuration(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtTime(Duration d) {
    final totalMs = d.inMilliseconds;
    if (totalMs <= 0) return '0:00';
    final totalSec = (totalMs / 1000.0);
    final m = totalSec ~/ 60;
    final s = (totalSec - (m * 60)).floor();
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }
}

class _InsertBetweenSheet extends StatelessWidget {
  final CameraEditScreenController controller;
  final int insertAfterIndex;

  const _InsertBetweenSheet(
      {required this.controller, required this.insertAfterIndex});

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: whitePure(context).withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: whitePure(context).withAlpha(20)),
        ),
        child: Row(
          children: [
            Icon(icon, color: whitePure(context), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context).withAlpha(230),
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: whitePure(context).withAlpha(160)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Insert',
                style: TextStyleCustom.unboundedMedium500(
                  color: whitePure(context),
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: () => Get.back(),
                child: Icon(Icons.close_rounded, color: whitePure(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _item(
            context,
            icon: Icons.add_to_photos_outlined,
            title: 'Add clip',
            onTap: () async {
              final before = controller.segments.length;
              await controller.addSegmentFromGallery();
              final after = controller.segments.length;
              if (after <= before) return;
              final newIndex = after - 1;
              final target = (insertAfterIndex + 1).clamp(0, after - 1);
              if (newIndex != target) {
                await controller.reorderSegments(newIndex, target);
              }
              if (Get.isBottomSheetOpen == true) {
                Get.back();
              }
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Transition (to next clip)',
            style: TextStyleCustom.unboundedMedium500(
              color: whitePure(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: VideoTransitionType.values.map((t) {
                final targetIndex = insertAfterIndex + 1;
                final isSelected = targetIndex < controller.segments.length &&
                    controller.segments[targetIndex].edits.transition == t;

                String label = t.name;
                if (label == 'none') {
                  label = 'None';
                } else if (label == 'slideLeft') {
                  label = 'Slide Left';
                } else if (label == 'slideRight') {
                  label = 'Slide Right';
                } else if (label == 'wipeLeft') {
                  label = 'Wipe Left';
                } else if (label == 'wipeRight') {
                  label = 'Wipe Right';
                } else {
                  label = label[0].toUpperCase() + label.substring(1);
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      controller.setSegmentTransition(targetIndex, t);
                      Get.back();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? whitePure(context).withAlpha(60)
                            : whitePure(context).withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? whitePure(context)
                              : whitePure(context).withAlpha(20),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyleCustom.outFitRegular400(
                          color: whitePure(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          _item(
            context,
            icon: Icons.gif_box_outlined,
            title: 'GIF',
            onTap: () async {
              if (!Get.isRegistered<GifSheetController>()) {
                Get.put(GifSheetController());
              }
              await Get.bottomSheet<String?>(
                const GifSheet(),
                isScrollControlled: true,
                ignoreSafeArea: false,
                enableDrag: true,
              );
            },
          ),
          const SizedBox(height: 10),
          _item(
            context,
            icon: Icons.emoji_emotions_outlined,
            title: 'Stickers',
            onTap: () {
              StoryTextViewController? text;
              try {
                text = Get.find<StoryTextViewController>();
              } catch (_) {
                text = null;
              }
              if (text == null) {
                controller.showSnackBar('Stickers not available');
                return;
              }
              Get.bottomSheet(
                _StickerSheet(textController: text, controller: controller),
                isScrollControlled: true,
                ignoreSafeArea: false,
                enableDrag: true,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _LutSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _LutSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final luts = controller.availableLuts;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LUT',
                style: TextStyleCustom.unboundedMedium500(
                  color: whitePure(context),
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: () => Get.back(),
                child: Icon(Icons.close_rounded, color: whitePure(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (luts.isEmpty)
            Text(
              'No LUTs available',
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(context).withAlpha(200),
                fontSize: 13,
              ),
            )
          else
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: luts.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return InkWell(
                      onTap: () async {
                        await controller.setSelectedLut(null);
                        Get.back();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: whitePure(context).withAlpha(15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: whitePure(context).withAlpha(90)),
                        ),
                        child: Text(
                          'None',
                          style: TextStyleCustom.unboundedMedium500(
                              color: whitePure(context)),
                        ),
                      ),
                    );
                  }
                  final lut = luts[index - 1];
                  final title = (lut.title ?? 'LUT').toString();
                  return InkWell(
                    onTap: () async {
                      await controller.setSelectedLut(lut);
                      // Keep sheet open so user can adjust strength like Instagram.
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: whitePure(context).withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: whitePure(context).withAlpha(90)),
                      ),
                      child: Text(
                        title,
                        style: TextStyleCustom.unboundedMedium500(
                            color: whitePure(context)),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Obx(() {
            final hasLut = controller.selectedLut.value != null;
            final strength = controller.lutStrength.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Strength',
                      style: TextStyleCustom.outFitRegular400(
                        color: whitePure(context).withAlpha(200),
                        fontSize: 13,
                      ),
                    ),
                    if (controller.isRenderingLutPreview.value)
                      SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: whitePure(context).withAlpha(220),
                        ),
                      )
                    else
                      Text(
                        '${(strength * 100).round()}%',
                        style: TextStyleCustom.outFitRegular400(
                          color: whitePure(context).withAlpha(200),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Slider(
                  value: strength,
                  min: 0.0,
                  max: 1.0,
                  onChanged: hasLut ? controller.setLutStrength : null,
                  activeColor: whitePure(context),
                  inactiveColor: whitePure(context).withAlpha(60),
                ),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DraggableTimelineBlock extends StatefulWidget {
  final Color color;
  final Color borderColor;
  final String label;
  final double msPerPx;
  final void Function(int deltaMs, bool end) onDragMs;

  const _DraggableTimelineBlock({
    required this.color,
    required this.borderColor,
    required this.label,
    required this.msPerPx,
    required this.onDragMs,
  });

  @override
  State<_DraggableTimelineBlock> createState() =>
      _DraggableTimelineBlockState();
}

class _DraggableTimelineBlockState extends State<_DraggableTimelineBlock> {
  double _dx = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {
        setState(() {
          _dx = 0.0;
        });
      },
      onPanUpdate: (d) {
        setState(() {
          _dx += d.delta.dx;
        });
        final deltaMs = (_dx * widget.msPerPx).round();
        widget.onDragMs(deltaMs, false);
      },
      onPanEnd: (_) {
        final deltaMs = (_dx * widget.msPerPx).round();
        widget.onDragMs(deltaMs, true);
        setState(() {
          _dx = 0.0;
        });
      },
      child: Transform.translate(
        offset: Offset(_dx, 0),
        child: Container(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.borderColor),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            widget.label,
            style: TextStyleCustom.outFitRegular400(
              color: whitePure(context).withAlpha(230),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _DraggableClip extends StatefulWidget {
  final int startMs;
  final int durationMs;
  final double msPerPx;
  final String label;
  final bool isSelected;
  final Color color;
  final Color borderColor;
  final Function(int newStartMs, bool end) onDragStart;
  final Function(int newDurationMs, bool end) onResizeDuration;
  final Function(int newStartMs, int newDurationMs, bool end)? onResizeLeft;
  final VoidCallback onTap;

  const _DraggableClip({
    required this.startMs,
    required this.durationMs,
    required this.msPerPx,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.borderColor,
    required this.onDragStart,
    required this.onResizeDuration,
    this.onResizeLeft,
    required this.onTap,
  });

  @override
  State<_DraggableClip> createState() => _DraggableClipState();
}

class _DraggableClipState extends State<_DraggableClip> {
  double _dragDx = 0.0;
  double _resizeDx = 0.0;
  double _resizeLeftDx = 0.0;

  @override
  Widget build(BuildContext context) {
    final width = widget.durationMs / widget.msPerPx;

    return Stack(
      children: [
        // Main Body (Drag Move)
        GestureDetector(
          onTap: widget.onTap,
          onHorizontalDragStart: (_) {
            setState(() {
              _dragDx = 0.0;
            });
          },
          onHorizontalDragUpdate: (d) {
            setState(() {
              _dragDx += d.delta.dx;
            });
            final deltaMs = (_dragDx * widget.msPerPx).round();
            widget.onDragStart(widget.startMs + deltaMs, false);
          },
          onHorizontalDragEnd: (_) {
            final deltaMs = (_dragDx * widget.msPerPx).round();
            widget.onDragStart(widget.startMs + deltaMs, true);
            setState(() {
              _dragDx = 0.0;
            });
          },
          child: Transform.translate(
            offset: Offset(_dragDx, 0),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isSelected
                      ? themeAccentSolid(context)
                      : widget.borderColor,
                  width: widget.isSelected ? 2 : 1,
                ),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                widget.label,
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context).withAlpha(230),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),

        // Left Resize Handle
        if (widget.isSelected)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                setState(() {
                  _resizeLeftDx = 0.0;
                });
              },
              onHorizontalDragUpdate: (d) {
                setState(() {
                  _resizeLeftDx += d.delta.dx;
                });
                final deltaMs = (_resizeLeftDx * widget.msPerPx).round();
                final newStart = widget.startMs + deltaMs;
                final newDur = widget.durationMs - deltaMs;
                if (newDur >= 500 && newStart >= 0) {
                  widget.onResizeLeft?.call(newStart, newDur, false);
                }
              },
              onHorizontalDragEnd: (_) {
                final deltaMs = (_resizeLeftDx * widget.msPerPx).round();
                final newStart = widget.startMs + deltaMs;
                final newDur = widget.durationMs - deltaMs;
                if (newDur >= 500 && newStart >= 0) {
                  widget.onResizeLeft?.call(newStart, newDur, true);
                }
                setState(() {
                  _resizeLeftDx = 0.0;
                });
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 12,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: whitePure(context),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.drag_handle_rounded,
                      color: blackPure(context), size: 10),
                ),
              ),
            ),
          ),

        // Right Resize Handle
        if (widget.isSelected)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                setState(() {
                  _resizeDx = 0.0;
                });
              },
              onHorizontalDragUpdate: (d) {
                setState(() {
                  _resizeDx += d.delta.dx;
                });
                final deltaMs = (_resizeDx * widget.msPerPx).round();
                widget.onResizeDuration(widget.durationMs + deltaMs, false);
              },
              onHorizontalDragEnd: (_) {
                final deltaMs = (_resizeDx * widget.msPerPx).round();
                widget.onResizeDuration(widget.durationMs + deltaMs, true);
                setState(() {
                  _resizeDx = 0.0;
                });
              },
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 12,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: whitePure(context),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.drag_handle_rounded,
                      color: blackPure(context), size: 10),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class GenerateContentView extends StatelessWidget {
  final CameraEditScreenController controller;

  const GenerateContentView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return switch (controller.content.value.type) {
      PostStoryContentType.storyText ||
      PostStoryContentType.storyImage =>
        CameraEditImageView(cameraEditController: controller),
      PostStoryContentType.reel ||
      PostStoryContentType.storyVideo =>
        CameraEditVideoView(content: controller.content),
    };
  }
}

class CameraEditRightSidebar extends StatelessWidget {
  final CameraEditScreenController controller;

  const CameraEditRightSidebar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    PostStoryContent content = controller.content.value;
    PostStoryContentType type = content.type;
    final isVideoType = [
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          // Audio
          _buildToolItem(
            context,
            icon: AssetRes.icMusic,
            label: 'Audio',
            onTap: controller.handleMusicSelection,
          ),

          // Text
          if ([
            PostStoryContentType.storyImage,
            PostStoryContentType.storyText,
            PostStoryContentType.reel,
            PostStoryContentType.storyVideo,
          ].contains(type))
            _buildToolItem(
              context,
              icon: AssetRes.icText1,
              label: 'Text',
              onTap: () => controller.onNewTexFieldAdd?.call(),
            ),

          // Stickers
          _buildToolItem(
            context,
            icon: AssetRes.icSticker,
            label: 'Stickers',
            onTap: () {
              StoryTextViewController? text;
              try {
                text = Get.find<StoryTextViewController>();
              } catch (_) {
                text = null;
              }
              if (text == null) {
                controller.showSnackBar('Stickers not available');
                return;
              }
              Get.bottomSheet(
                _StickerSheet(textController: text, controller: controller),
                isScrollControlled: true,
                ignoreSafeArea: false,
                enableDrag: true,
              );
            },
          ),

          // Filters
          if (![PostStoryContentType.storyText].contains(content.type))
            _buildToolItem(
              context,
              icon: AssetRes.icFilter,
              label: 'Filters',
              onTap: controller.onFilterToggle,
            ),

          // Voiceover (if video)
          if (isVideoType)
            _buildToolItem(
              context,
              icon:
                  AssetRes.icVoice, // Ensure this icon exists or use Icons.mic
              label: 'Voice',
              onTap: () {
                Get.bottomSheet(
                  _VoiceoverSheet(controller: controller),
                  isScrollControlled: true,
                  ignoreSafeArea: false,
                  enableDrag: true,
                );
              },
            ),

          // Volume (if video)
          if (isVideoType)
            Obx(() {
              final vp = controller.videoPlayerController.value;
              final isMuted = (vp?.value.volume ?? 1.0) == 0.0;
              return _buildToolItem(
                context,
                icon: isMuted ? AssetRes.icSpeakerMute : AssetRes.icSpeaker,
                label: 'Volume',
                onTap: controller.toggleVideoVolume,
              );
            }),

          // Background (if story)
          if ([PostStoryContentType.storyText, PostStoryContentType.storyImage]
              .contains(type))
            Obx(() {
              bool isTextStory = PostStoryContentType.storyText == type;
              int selectedGradientIndex = controller.selectedBgIndex.value;
              var gradient = isTextStory
                  ? controller.storyGradientColor[selectedGradientIndex]
                  : controller.content.value.bgGradient;

              return GestureDetector(
                onTap: () => controller.changeBg(isTextStory),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isTextStory
                            ? gradient
                            : controller.content.value.bgGradient,
                        border: Border.all(color: whitePure(context), width: 2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bg',
                      style: TextStyleCustom.outFitRegular400(
                        fontSize: 10,
                        color: whitePure(context),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildToolItem(
    BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            width: 28,
            height: 28,
            color: whitePure(context),
            errorBuilder: (_, __, ___) =>
                Icon(Icons.star, color: whitePure(context), size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyleCustom.outFitRegular400(
              fontSize: 10,
              color: whitePure(context),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraEditTopViewTools extends StatelessWidget {
  final CameraEditScreenController controller;

  const CameraEditTopViewTools({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    PostStoryContent content = controller.content.value;
    PostStoryContentType type = content.type;
    final isVideoType = [
      PostStoryContentType.reel,
      PostStoryContentType.storyVideo,
    ].contains(type);
    final isStoryType = [
      PostStoryContentType.storyImage,
      PostStoryContentType.storyText,
    ].contains(type);
    return Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 10,
            children: [
              if (isVideoType)
                Obx(() {
                  final vp = controller.videoPlayerController.value;
                  final isMuted = (vp?.value.volume ?? 1.0) == 0.0;
                  return CustomBorderRoundIcon(
                    image:
                        isMuted ? AssetRes.icSpeakerMute : AssetRes.icSpeaker,
                    onTap: controller.toggleVideoVolume,
                  );
                }),
              if (isVideoType)
                CustomBorderRoundIcon(
                  onTap: () {
                    Get.bottomSheet(
                      _VideoSpeedSheet(controller: controller),
                      isScrollControlled: true,
                      ignoreSafeArea: false,
                      enableDrag: true,
                    );
                  },
                  widget: Center(
                    child: Obx(
                      () => Text(
                        '${controller.playbackSpeed.value.toStringAsFixed(controller.playbackSpeed.value.truncateToDouble() == controller.playbackSpeed.value ? 0 : 1)}x',
                        style: TextStyleCustom.unboundedMedium500(
                            color: whitePure(context)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              if (isVideoType)
                CustomBorderRoundIcon(
                  image: AssetRes.icImage1,
                  onTap: () {
                    Get.bottomSheet(
                      _VideoCoverSheet(controller: controller),
                      isScrollControlled: true,
                      ignoreSafeArea: false,
                      enableDrag: true,
                    );
                  },
                ),
              if ([
                PostStoryContentType.storyImage,
                PostStoryContentType.storyText,
              ].contains(type))
                Obx(
                  () => CustomBorderRoundIcon(
                    onTap: controller.changeStoryTime,
                    widget: Center(
                      child: Text(
                          '${AppRes.storyDurations[controller.currentStoryDurationIndex.value]}s',
                          style: TextStyleCustom.unboundedMedium500(
                              color: whitePure(context)),
                          textAlign: TextAlign.center),
                    ),
                  ),
                )
              else if ([
                PostStoryContentType.reel,
                PostStoryContentType.storyVideo,
              ].contains(type))
                CustomBorderRoundIcon(
                  onTap: () {
                    Get.bottomSheet(
                      _VideoTrimSheet(controller: controller),
                      isScrollControlled: true,
                      ignoreSafeArea: false,
                      enableDrag: true,
                    );
                  },
                  widget: Center(
                    child: Text(
                      '${content.duration ?? 0}s',
                      style: TextStyleCustom.unboundedMedium500(
                          color: whitePure(context)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (!isStoryType &&
                  [
                    PostStoryContentType.storyImage,
                    PostStoryContentType.storyText,
                    PostStoryContentType.reel,
                    PostStoryContentType.storyVideo,
                  ].contains(type))
                CustomBorderRoundIcon(
                  onTap: () => controller.onNewTexFieldAdd?.call(),
                  image: AssetRes.icText1,
                ),
              if (!isStoryType &&
                  ![PostStoryContentType.storyText].contains(content.type))
                CustomBorderRoundIcon(
                    image: AssetRes.icFilter, onTap: controller.onFilterToggle),
              if (!isStoryType &&
                  [
                    PostStoryContentType.storyText,
                    PostStoryContentType.storyImage
                  ].contains(type))
                Obx(() {
                  bool isTextStory = PostStoryContentType.storyText == type;
                  int selectedGradientIndex = controller.selectedBgIndex.value;

                  var gradient = isTextStory
                      ? controller.storyGradientColor[selectedGradientIndex]
                      : controller.content.value.bgGradient;
                  return CustomBorderRoundIcon(
                    onTap: () => controller.changeBg(isTextStory),
                    widget: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isTextStory
                              ? gradient
                              : controller.content.value.bgGradient,
                          border:
                              Border.all(color: whitePure(context), width: 2)),
                    ),
                  );
                }),
              if (!isStoryType)
                CustomBorderRoundIcon(
                    image: AssetRes.icMusic,
                    onTap: controller.handleMusicSelection),
            ],
          ),
        ));
  }
}

class _VideoSpeedSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VideoSpeedSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Obx(() {
          final selected = controller.playbackSpeed.value;
          final speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Speed',
                    style: TextStyleCustom.unboundedMedium500(
                      color: whitePure(context),
                      fontSize: 16,
                    ),
                  ),
                  InkWell(
                    onTap: Get.back,
                    child: Icon(Icons.close_rounded, color: whitePure(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: speeds
                    .map(
                      (s) => InkWell(
                        onTap: () async {
                          await controller.setPlaybackSpeed(s);
                          Get.back();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: (selected == s)
                                ? whitePure(context).withAlpha(30)
                                : whitePure(context).withAlpha(15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (selected == s)
                                  ? whitePure(context)
                                  : whitePure(context).withAlpha(90),
                            ),
                          ),
                          child: Text(
                            '${s.toStringAsFixed(s.truncateToDouble() == s ? 0 : 2)}x',
                            style: TextStyleCustom.unboundedMedium500(
                                color: whitePure(context)),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
            ],
          );
        }),
      ),
    );
  }
}

class _VideoAudioFxSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VideoAudioFxSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Obx(() {
          final selected =
              controller.activeSegment?.edits.audioFx ?? VideoAudioFx.none;
          const fxs = VideoAudioFx.values;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audio FX',
                    style: TextStyleCustom.unboundedMedium500(
                      color: whitePure(context),
                      fontSize: 16,
                    ),
                  ),
                  InkWell(
                    onTap: Get.back,
                    child: Icon(Icons.close_rounded, color: whitePure(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: fxs
                    .map((fx) => InkWell(
                          onTap: () async {
                            await controller.setAudioFx(fx);
                            Get.back();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: (selected == fx)
                                  ? whitePure(context).withAlpha(30)
                                  : whitePure(context).withAlpha(15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (selected == fx)
                                    ? whitePure(context)
                                    : whitePure(context).withAlpha(90),
                              ),
                            ),
                            child: Text(
                              fx.name.toUpperCase(),
                              style: TextStyleCustom.unboundedMedium500(
                                  color: whitePure(context)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
            ],
          );
        }),
      ),
    );
  }
}

class _VideoCoverSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VideoCoverSheet({required this.controller});

  String _fmt(double seconds) {
    final s = seconds.isNaN ? 0 : seconds;
    final whole = s.round();
    final m = whole ~/ 60;
    final sec = whole % 60;
    if (m <= 0) return '${sec}s';
    return '${m}m ${sec.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Obx(() {
        final vp = controller.videoPlayerController.value;
        final maxSec = vp?.value.isInitialized == true
            ? (vp!.value.duration.inMilliseconds / 1000.0)
            : (controller.content.value.duration?.toDouble() ?? 0.0);
        final pos = controller.coverPositionSec.value.clamp(0.0, maxSec);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cover',
                  style: TextStyleCustom.unboundedMedium500(
                    color: whitePure(context),
                    fontSize: 16,
                  ),
                ),
                InkWell(
                  onTap: Get.back,
                  child: Icon(Icons.close_rounded, color: whitePure(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Position: ${_fmt(pos)}',
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(context).withAlpha(200),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: pos,
              min: 0.0,
              max: maxSec <= 0 ? 1.0 : maxSec,
              onChanged: controller.isGeneratingCover.value
                  ? null
                  : (v) {
                      controller.coverPositionSec.value = v;
                      controller.seekToCoverPosition();
                    },
              activeColor: whitePure(context),
              inactiveColor: whitePure(context).withAlpha(80),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButtonCustom(
                    title: controller.isGeneratingCover.value ? '' : 'Apply',
                    onTap: controller.isGeneratingCover.value
                        ? null
                        : () async {
                            final ok = await controller.generateCoverAt(pos);
                            if (ok) Get.back();
                          },
                    child: controller.isGeneratingCover.value
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: textDarkGrey(context),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class FilterAndMusicView extends StatelessWidget {
  final CameraEditScreenController controller;

  const FilterAndMusicView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      bool isFilterShow = controller.isFilterShow.value;
      PostStoryContent content = controller.content.value;
      SelectedMusic? music = content.sound;
      return Container(
        margin: const EdgeInsets.only(bottom: 15),
        child: Column(
          children: [
            if (isFilterShow &&
                ![PostStoryContentType.storyText].contains(content.type))
              ColorFiltersView(
                image: content.type == PostStoryContentType.storyImage
                    ? content.content
                    : null,
                onPageChanged: controller.changedFilter,
              ),
            if (music != null)
              SelectedMusicView(
                  selectedMusic: music.obs,
                  isReelType: false,
                  onDeleteMusic: controller.onMusicDelete,
                  onMusicTap: (music) {
                    controller.handleMusicSelection(initialMusic: music);
                  })
          ],
        ),
      );
    });
  }
}

class CameraEditVideoView extends StatelessWidget {
  final Rx<PostStoryContent> content;

  const CameraEditVideoView({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CameraEditScreenController>();
    final textController = Get.find<StoryTextViewController>();
    return Obx(() {
      final mirror = content.value.isFrontCamera;
      return GestureDetector(
        onHorizontalDragEnd: (details) {
          final dx = details.velocity.pixelsPerSecond.dx;
          if (dx.abs() < 120) return;
          if (dx < 0) {
            controller.nextFilter();
          } else {
            controller.prevFilter();
          }
        },
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(controller.selectedFilter.value),
          child: Container(
            decoration: ShapeDecoration(
                shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                        cornerRadius: 15, cornerSmoothing: 1))),
            child: Stack(
              children: [
                Obx(() => CustomVideoPlayer(
                    videoPlayerController:
                        controller.videoPlayerController.value,
                    onPlayPause: controller.onPlayPauseToggle,
                    mirror: mirror)),
                Positioned.fill(
                  child: RepaintBoundary(
                    key: controller.overlayContainerKey,
                    child: Obx(() {
                      final videoCtrl = controller.videoPlayerController.value;
                      if (videoCtrl == null || !videoCtrl.value.isInitialized) {
                        return const SizedBox();
                      }
                      return ValueListenableBuilder(
                        valueListenable: videoCtrl,
                        builder: (context, value, child) {
                          final currentMs = value.position.inMilliseconds;
                          final items = <Widget>[];

                          // Filter text widgets based on timeline clips
                          final visibleTextWidgets = textController.textWidgets
                              .asMap()
                              .entries
                              .where((e) {
                            final clip = controller.textClips
                                .firstWhereOrNull((c) => c.id == e.value.id);
                            // Only show if a corresponding clip exists and we are in its time range
                            if (clip == null) return false;
                            return currentMs >= clip.startMs &&
                                currentMs < (clip.startMs + clip.durationMs);
                          });

                          items.addAll(
                            visibleTextWidgets.map(
                              (e) => DraggableTextWidget(
                                data: e.value,
                                onUpdate: (updatedData) => textController
                                    .updateTextWidget(e.key, updatedData),
                                onDelete: () =>
                                    textController.deleteTextWidget(e.key),
                              ),
                            ),
                          );

                          items.addAll(
                            textController.imageStickers
                                .asMap()
                                .entries
                                .where((e) {
                              if (!controller.isCapturingOverlay.value) {
                                return true;
                              }
                              return !controller.isGifUrl(e.value.url);
                            }).map(
                              (e) => DraggableImageStickerWidget(
                                data: e.value,
                                onUpdate: (updated) => textController
                                    .updateImageSticker(e.key, updated),
                                onDelete: () =>
                                    textController.deleteImageSticker(e.key),
                              ),
                            ),
                          );
                          return Stack(children: items);
                        },
                      );
                    }),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Obx(() {
                      final name = controller.filterNameOverlay.value;
                      if (name.isEmpty) return const SizedBox();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          name,
                          style: TextStyleCustom.outFitSemiBold600(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        ),
                      );
                    }),
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

class _VideoTrimSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VideoTrimSheet({required this.controller});

  String _fmt(double seconds) {
    final s = seconds.isNaN ? 0 : seconds;
    final whole = s.round();
    final m = whole ~/ 60;
    final sec = whole % 60;
    if (m <= 0) return '${sec}s';
    return '${m}m ${sec.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Obx(() {
        final vp = controller.videoPlayerController.value;
        final maxSec = vp?.value.isInitialized == true
            ? (vp!.value.duration.inMilliseconds / 1000.0)
            : (controller.content.value.duration?.toDouble() ?? 0.0);

        final start = controller.trimStartSec.value.clamp(0.0, maxSec);
        final end = controller.trimEndSec.value.clamp(0.0, maxSec);
        final range = RangeValues(start, end < start ? start : end);
        final selectedDur = (range.end - range.start).clamp(0.0, maxSec);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trim',
                  style: TextStyleCustom.unboundedMedium500(
                    color: whitePure(context),
                    fontSize: 16,
                  ),
                ),
                InkWell(
                  onTap: Get.back,
                  child: Icon(Icons.close_rounded, color: whitePure(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Start: ${_fmt(range.start)}    End: ${_fmt(range.end)}    Duration: ${_fmt(selectedDur)}',
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(context).withAlpha(200),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            RangeSlider(
              values: range,
              min: 0.0,
              max: maxSec <= 0 ? 1.0 : maxSec,
              onChanged: controller.isTrimmingVideo.value
                  ? null
                  : (v) {
                      controller.setTrimRange(
                        startSec: v.start,
                        endSec: v.end,
                      );
                      controller.seekToTrimStart();
                    },
              activeColor: whitePure(context),
              inactiveColor: whitePure(context).withAlpha(80),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButtonCustom(
                    title: controller.isTrimmingVideo.value ? '' : 'Apply',
                    onTap: controller.isTrimmingVideo.value
                        ? null
                        : () async {
                            final ok = await controller.applyTrim();
                            if (ok) Get.back();
                          },
                    child: controller.isTrimmingVideo.value
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: textDarkGrey(context),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class CustomVideoPlayer extends StatelessWidget {
  final VideoPlayerController? videoPlayerController;
  final VoidCallback onPlayPause;
  final bool mirror;

  const CustomVideoPlayer(
      {super.key,
      required this.videoPlayerController,
      required this.onPlayPause,
      this.mirror = false});

  @override
  Widget build(BuildContext context) {
    if (videoPlayerController != null &&
        videoPlayerController!.value.isInitialized) {
      final v = videoPlayerController!.value;
      final videoSize = v.size;

      final rcDeg = v.rotationCorrection;
      final quarterTurns = rcDeg ~/ 90;
      final isQuarterTurn = rcDeg % 90 == 0;

      debugPrint(
          '[VideoPreview] size=$videoSize rotationCorrection=$rcDeg quarterTurns=$quarterTurns mirror=$mirror');

      final fitType =
          videoSize.width < videoSize.height ? BoxFit.cover : BoxFit.fitWidth;

      final core = SizedBox(
        width: videoSize.width,
        height: videoSize.height,
        child: VideoPlayer(videoPlayerController!),
      );

      final rotatedCore = isQuarterTurn
          ? RotatedBox(quarterTurns: quarterTurns, child: core)
          : Transform.rotate(
              angle: (rcDeg.toDouble() * math.pi) / 180.0,
              child: core,
            );

      final player = ClipSmoothRect(
        radius: SmoothBorderRadius(cornerRadius: 15, cornerSmoothing: 1),
        child: Container(
          color: blackPure(context),
          child: SizedBox.expand(
            child: FittedBox(
              fit: fitType,
              child: rotatedCore,
            ),
          ),
        ),
      );

      final mirrored = mirror
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: player,
            )
          : player;

      return InkWell(
        onTap: onPlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            mirrored,
            ValueListenableBuilder(
              valueListenable: videoPlayerController!,
              builder: (context, value, child) {
                // Show Play icon when PAUSED.
                // Hide Play icon (opacity 0) when PLAYING.
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: value.isPlaying ? 0 : 1,
                  child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                          color: blackPure(context).withValues(alpha: 0.5),
                          shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Image.asset(
                          AssetRes
                              .icPlay, // Use Play icon to indicate "Tap to Play"
                          width: 35,
                          height: 35,
                          color: whitePure(context))),
                );
              },
            )
          ],
        ),
      );
    } else {
      return const LoaderWidget();
    }
  }
}

class CameraEditActionButtons extends StatelessWidget {
  final CameraEditScreenController controller;

  const CameraEditActionButtons({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final type = controller.content.value.type;
    final isReelType = type == PostStoryContentType.reel;

    if (isReelType) return const SizedBox();

    final user = SessionManager.instance.getUser();

    Widget circleButton({
      required String label,
      required VoidCallback onTap,
      required Widget icon,
    }) {
      return InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: whitePure(context),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Your Story
          circleButton(
            label: 'Your Story',
            onTap: () {
               controller.setStoryAudience(StoryAudience.public);
               controller.handleContentUpload();
            },
            icon: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgGrey(context),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CustomImage(
                      image: user?.profilePhoto?.addBaseURL(),
                      size: const Size(48, 48),
                      fit: BoxFit.cover,
                      isShowPlaceHolder: true,
                      placeHolderImage: AssetRes.icUserPlaceholder,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: whitePure(context),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_circle, color: Colors.blue, size: 16),
                  ),
                ),
              ],
            ),
          ),
          
          // Close Friends
          circleButton(
            label: 'Close Friends',
            onTap: () {
               controller.setStoryAudience(StoryAudience.closeFriends);
               controller.handleContentUpload();
            },
            icon: Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.star, color: Colors.white, size: 24),
            ),
          ),

          // Next / Arrow
          InkWell(
            onTap: controller.handleContentUpload,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: whitePure(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Text(
                    'Next',
                    style: TextStyleCustom.outFitSemiBold600(
                      color: whitePure(context),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(Icons.arrow_forward_ios_rounded, color: whitePure(context), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceoverSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VoiceoverSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Voiceover',
                style: TextStyleCustom.unboundedMedium500(
                  color: whitePure(context),
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: () => Get.back(),
                child: Icon(Icons.close_rounded, color: whitePure(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final recording = controller.isVoiceoverRecording.value;
            final hasFile =
                (controller.voiceoverFilePath.value ?? '').isNotEmpty;
            return Row(
              children: [
                Expanded(
                  child: TextButtonCustom(
                    onTap: () async {
                      if (recording) {
                        await controller.stopVoiceoverRecording();
                      } else {
                        await controller.startVoiceoverRecording();
                      }
                    },
                    title: recording ? 'Stop' : 'Record',
                    btnHeight: 42,
                    backgroundColor: themeAccentSolid(context),
                    titleColor: whitePure(context),
                    horizontalMargin: 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButtonCustom(
                    onTap: hasFile ? controller.clearVoiceover : null,
                    title: 'Clear',
                    btnHeight: 42,
                    backgroundColor: bgMediumGrey(context),
                    titleColor: whitePure(context),
                    horizontalMargin: 0,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Volume',
            style: TextStyleCustom.outFitRegular400(
              color: whitePure(context).withAlpha(220),
              fontSize: 13,
            ),
          ),
          Obx(() {
            return Slider(
              value: controller.voiceoverVolume.value,
              onChanged: (v) => controller.voiceoverVolume.value = v,
              min: 0.0,
              max: 1.0,
              activeColor: whitePure(context),
              inactiveColor: whitePure(context).withAlpha(60),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StickerSheet extends StatelessWidget {
  final StoryTextViewController textController;
  final CameraEditScreenController controller;

  const _StickerSheet({required this.textController, required this.controller});

  void _addStickerText(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    textController.textWidgets.add(
      TextWidgetData(
        text: t,
        top: 220,
        left: 40,
        fontScale: 1.0,
        fontAngle: 0.0,
        fontSize: 32,
        opacity: 1.0,
        googleFontFamily: null,
        fontAlign: FontAlign.center,
        fontColor: Colors.white,
      ),
    );
  }

  void _addLocationSticker(String title) {
    final t = title.trim();
    if (t.isEmpty) return;
    _addStickerText('__loc__:$t');
  }

  void _openLocationStickerPicker() {
    final search = TextEditingController();
    Timer? debounce;
    final RxList<Places> results = <Places>[].obs;
    final RxBool loading = true.obs;
    final RxBool searching = false.obs;

    Future<void> loadNearby() async {
      loading.value = true;
      try {
        final pos = await LocationService.instance
            .getCurrentLocation(isPermissionDialogShow: true);
        final items = await CommonService.instance
            .searchNearBy(lat: pos.latitude, lon: pos.longitude);
        results.assignAll(items);
      } catch (_) {
        results.clear();
      } finally {
        loading.value = false;
      }
    }

    Future<void> doSearch(String q) async {
      final query = q.trim();
      if (query.isEmpty) {
        searching.value = false;
        await loadNearby();
        return;
      }
      searching.value = true;
      loading.value = true;
      try {
        final items = await CommonService.instance.searchPlace(title: query);
        results.assignAll(items);
      } catch (_) {
        results.clear();
      } finally {
        loading.value = false;
      }
    }

    Get.bottomSheet(
      Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(Get.context!).size.height * 0.75,
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.of(Get.context!).viewInsets.bottom,
        ),
        decoration: ShapeDecoration(
          color: blackPure(Get.context!),
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: 18,
              cornerSmoothing: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Locations',
                  style: TextStyleCustom.unboundedMedium500(
                    color: whitePure(Get.context!),
                    fontSize: 16,
                  ),
                ),
                InkWell(
                  onTap: () => Get.back(),
                  child:
                      Icon(Icons.close_rounded, color: whitePure(Get.context!)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 350), () {
                  doSearch(v);
                });
              },
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(Get.context!),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded,
                    color: whitePure(Get.context!).withAlpha(180)),
                hintText: 'Search for a location...',
                hintStyle: TextStyleCustom.outFitRegular400(
                  color: whitePure(Get.context!).withAlpha(150),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: whitePure(Get.context!).withAlpha(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: whitePure(Get.context!).withAlpha(30)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: whitePure(Get.context!).withAlpha(30)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                if (loading.value) {
                  return const Center(child: LoaderWidget());
                }
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      searching.value ? 'No results' : 'No nearby places',
                      style: TextStyleCustom.outFitRegular400(
                        color: whitePure(Get.context!).withAlpha(160),
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => Divider(
                      color: whitePure(Get.context!).withAlpha(18), height: 1),
                  itemBuilder: (context, i) {
                    final p = results[i];
                    final title = (p.title).trim();
                    final sub = (p.description).trim();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.place_rounded,
                          color: themeAccentSolid(context)),
                      title: Text(
                        title.isEmpty ? 'Place' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyleCustom.outFitSemiBold600(
                          color: whitePure(context),
                          fontSize: 14,
                        ),
                      ),
                      subtitle: sub.isEmpty
                          ? null
                          : Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyleCustom.outFitRegular400(
                                color: whitePure(context).withAlpha(160),
                                fontSize: 12,
                              ),
                            ),
                      onTap: () {
                        _addLocationSticker(title);
                        Get.back();
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      enableDrag: true,
    ).whenComplete(() {
      debounce?.cancel();
      search.dispose();
    });

    loadNearby();
  }

  void _openLocationSticker() {
    final c = TextEditingController();
    Get.bottomSheet(
      SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.of(Get.context!).viewInsets.bottom,
        ),
        child: Container(
          width: double.infinity,
          decoration: ShapeDecoration(
            color: blackPure(Get.context!),
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: 18,
                cornerSmoothing: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Location',
                    style: TextStyleCustom.unboundedMedium500(
                      color: whitePure(Get.context!),
                      fontSize: 16,
                    ),
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    child: Icon(Icons.close_rounded,
                        color: whitePure(Get.context!)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(Get.context!),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter location',
                  hintStyle: TextStyleCustom.outFitRegular400(
                    color: whitePure(Get.context!).withAlpha(140),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: whitePure(Get.context!).withAlpha(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: whitePure(Get.context!).withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: whitePure(Get.context!).withAlpha(30)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButtonCustom(
                onTap: () {
                  final v = c.text.trim();
                  if (v.isEmpty) return;
                  _addStickerText('📍 $v');
                  Get.back();
                },
                title: 'Add',
                btnHeight: 42,
                backgroundColor: themeAccentSolid(Get.context!),
                titleColor: whitePure(Get.context!),
                horizontalMargin: 0,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      enableDrag: true,
    );
  }

  void _openQuizSticker() {
    final q = TextEditingController();
    Get.bottomSheet(
      SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.of(Get.context!).viewInsets.bottom,
        ),
        child: Container(
          width: double.infinity,
          decoration: ShapeDecoration(
            color: blackPure(Get.context!),
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: 18,
                cornerSmoothing: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quiz',
                    style: TextStyleCustom.unboundedMedium500(
                      color: whitePure(Get.context!),
                      fontSize: 16,
                    ),
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    child: Icon(Icons.close_rounded,
                        color: whitePure(Get.context!)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: q,
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(Get.context!),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your question',
                  hintStyle: TextStyleCustom.outFitRegular400(
                    color: whitePure(Get.context!).withAlpha(140),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: whitePure(Get.context!).withAlpha(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: whitePure(Get.context!).withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: whitePure(Get.context!).withAlpha(30)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButtonCustom(
                onTap: () {
                  final v = q.text.trim();
                  if (v.isEmpty) return;
                  _addStickerText('❓ $v');
                  Get.back();
                },
                title: 'Add',
                btnHeight: 42,
                backgroundColor: themeAccentSolid(Get.context!),
                titleColor: whitePure(Get.context!),
                horizontalMargin: 0,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      enableDrag: true,
    );
  }

  void _openQuestionsSticker() {
    final q = TextEditingController();
    Get.bottomSheet(
      SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.of(Get.context!).viewInsets.bottom,
        ),
        child: Container(
          width: double.infinity,
          decoration: ShapeDecoration(
            color: blackPure(Get.context!),
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: 18,
                cornerSmoothing: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Questions',
                    style: TextStyleCustom.unboundedMedium500(
                      color: whitePure(Get.context!),
                      fontSize: 16,
                    ),
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    child: Icon(Icons.close_rounded,
                        color: whitePure(Get.context!)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: q,
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(Get.context!),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask me a question...',
                  hintStyle: TextStyleCustom.outFitRegular400(
                    color: whitePure(Get.context!).withAlpha(140),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: whitePure(Get.context!).withAlpha(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: whitePure(Get.context!).withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: whitePure(Get.context!).withAlpha(30)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButtonCustom(
                onTap: () {
                  final v = q.text.trim();
                  if (v.isEmpty) return;
                  _addStickerText('__qst__:$v');
                  Get.back();
                },
                title: 'Add',
                btnHeight: 42,
                backgroundColor: themeAccentSolid(Get.context!),
                titleColor: whitePure(Get.context!),
                horizontalMargin: 0,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      enableDrag: true,
    );
  }

  void _openGifs() {
    try {
      if (!Get.isRegistered<GifSheetController>()) {
        Get.put(GifSheetController());
      }
      Get.bottomSheet<String?>(
        const GifSheet(),
        isScrollControlled: true,
        ignoreSafeArea: false,
        enableDrag: true,
      ).then((res) {
        final url = (res ?? '').trim();
        if (url.isEmpty) return;
        textController.addImageSticker(url);
      });
    } catch (_) {
      controller.showSnackBar('GIF not available');
    }
  }

  Future<void> _openStickers() async {
    try {
      if (!Get.isRegistered<StickerSheetController>()) {
        Get.put(StickerSheetController());
      }
      final res = await Get.bottomSheet<String?>(
        const StickerSheet(),
        isScrollControlled: true,
        ignoreSafeArea: false,
        enableDrag: true,
      );
      final url = (res ?? '').trim();
      if (url.isNotEmpty) {
        textController.addImageSticker(url);
      }
    } catch (_) {
      controller.showSnackBar('Stickers not available');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stickers',
                style: TextStyleCustom.unboundedMedium500(
                  color: whitePure(context),
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: () => Get.back(),
                child: Icon(Icons.close_rounded, color: whitePure(context)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            enabled: false,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded,
                  color: whitePure(context).withAlpha(180)),
              hintText: 'Search',
              hintStyle: TextStyleCustom.outFitRegular400(
                color: whitePure(context).withAlpha(150),
                fontSize: 14,
              ),
              filled: true,
              fillColor: whitePure(context).withAlpha(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: whitePure(context).withAlpha(30)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: whitePure(context).withAlpha(30)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: whitePure(context).withAlpha(30)),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _stickerActionChip(
                context,
                label: 'GIF',
                onTap: _openGifs,
              ),
              _stickerActionChip(
                context,
                label: 'STICKERS',
                onTap: () async {
                  Get.back();
                  await _openStickers();
                },
              ),
              _stickerActionChip(
                context,
                label: 'LOCATION',
                onTap: () {
                  Get.back();
                  _openLocationStickerPicker();
                },
              ),
              _stickerActionChip(
                context,
                label: 'CAPTIONS',
                onTap: () {
                  textController.openTextEditor();
                  Get.back();
                },
              ),
              _stickerActionChip(
                context,
                label: 'QUESTIONS',
                onTap: () {
                  Get.back();
                  _openQuestionsSticker();
                },
              ),
              _stickerActionChip(
                context,
                label: 'QUIZ',
                onTap: () {
                  Get.back();
                  _openQuizSticker();
                },
              ),
              _stickerActionChip(
                context,
                label: 'PHOTO',
                onTap: () async {
                  Get.back();
                  await _openStickers();
                },
              ),
              _stickerActionChip(
                context,
                label: 'AVATAR',
                onTap: () {
                  Get.back();
                  textController.addEmojiSticker('🙂');
                },
              ),
              _stickerActionChip(
                context,
                label: 'CUTOUTS',
                onTap: () => controller.showSnackBar('Coming soon'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Widget _stickerActionChip(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyleCustom.unboundedMedium500(
          color: Colors.black,
          fontSize: 14,
        ),
      ),
    ),
  );
}

class _AdvancedEditSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _AdvancedEditSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit',
                style: TextStyleCustom.unboundedMedium500(
                  color: whitePure(context),
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: Get.back,
                child: Icon(Icons.close_rounded, color: whitePure(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _VideoEditToolsRow(controller: controller),
        ],
      ),
    );
  }
}

class _VideoEditToolsRow extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VideoEditToolsRow({required this.controller});

  Widget _tool(
    BuildContext context, {
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          width: 50,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: whitePure(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyleCustom.outFitRegular400(
                  fontSize: 9, // Reduced font size to prevent overflow
                  color: whitePure(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _tool(
      context,
      icon: Icon(icon, color: whitePure(context), size: 18),
      label: label,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delete
          _tool(
            context,
            icon: Icon(Icons.delete_outline_rounded,
                color: whitePure(context), size: 18),
            label: 'Delete',
            onTap: () {
              if (controller.activeSegment == null) {
                controller.showSnackBar('Select a clip first');
                return;
              }
              controller.removeActiveSegment();
            },
          ),
          // Split
          _tool(
            context,
            icon: Icon(Icons.call_split_rounded,
                color: whitePure(context), size: 18),
            label: 'Split',
            onTap: controller.splitAtCurrentPosition,
          ),
          // Trim
          _tool(
            context,
            icon: Icon(Icons.content_cut_rounded,
                color: whitePure(context), size: 18),
            label: 'Trim',
            onTap: () {
              Get.bottomSheet(
                _VideoTrimSheet(controller: controller),
                isScrollControlled: true,
                ignoreSafeArea: false,
                enableDrag: true,
              );
            },
          ),
          // Speed
          _tool(
            context,
            icon:
                Icon(Icons.speed_rounded, color: whitePure(context), size: 18),
            label: 'Speed',
            onTap: () {
              Get.bottomSheet(
                _VideoSpeedSheet(controller: controller),
                isScrollControlled: true,
                ignoreSafeArea: false,
                enableDrag: true,
              );
            },
          ),
          // Volume
          _tool(
            context,
            icon: Icon(Icons.volume_up_rounded,
                color: whitePure(context), size: 18),
            label: 'Volume',
            onTap: () {
              // Toggle mute or show slider? For quick edit, toggle mute
              // But standard editor shows slider.
              // Let's use slider sheet for better control
              Get.bottomSheet(
                _VideoVolumeSheet(controller: controller),
                isScrollControlled: true,
                enableDrag: true,
              );
            },
          ),
          // Crop
          _tool(
            context,
            icon: Icon(Icons.crop_rounded, color: whitePure(context), size: 18),
            label: 'Crop',
            onTap: () {
              Get.bottomSheet(
                _VideoCropSheet(controller: controller),
                isScrollControlled: true,
                enableDrag: true,
              );
            },
          ),
          // Replace
          _tool(
            context,
            icon: Icon(Icons.swap_horiz_rounded,
                color: whitePure(context), size: 18),
            label: 'Replace',
            onTap: controller.replaceActiveSegmentFromGallery,
          ),
          // Audio FX
          _tool(
            context,
            icon: Icon(Icons.graphic_eq_rounded,
                color: whitePure(context), size: 18),
            label: 'Audio FX',
            onTap: () {
              Get.bottomSheet(
                _VideoAudioFxSheet(controller: controller),
                isScrollControlled: true,
                enableDrag: true,
              );
            },
          ),
          Container(
            width: 1,
            height: 30,
            color: whitePure(context).withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          // AI Cut
          _tool(
            context,
            icon: Obx(() {
              final loading = controller.isCuttingSilences.value;
              return loading
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: whitePure(context),
                      ),
                    )
                  : Icon(Icons.auto_fix_high_rounded,
                      color: whitePure(context), size: 18);
            }),
            label: 'AI Cut',
            disabled: controller.isCuttingSilences.value ||
                controller.isTimelineExporting.value,
            onTap: () async {
              Get.bottomSheet(
                _CutSilencesProgressSheet(controller: controller),
                isScrollControlled: true,
                isDismissible: false,
                enableDrag: false,
              );
              await controller.cutSilences();
              if (Get.isBottomSheetOpen == true) {
                Get.back();
              }
            },
          ),
          _btn(
            context,
            icon: Icons.add_box_outlined,
            label: 'Add clips',
            onTap: controller.addSegmentFromGallery,
          ),
          _btn(
            context,
            icon: Icons.picture_in_picture_alt_rounded,
            label: 'Overlay',
            onTap: controller.pickPipVideoFromGallery,
          ),
          _btn(
            context,
            icon: Icons.library_music_outlined,
            label: 'Audio',
            onTap: controller.handleMusicSelection,
          ),
        ],
      ),
    );
  }
}

class _CutSilencesProgressSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _CutSilencesProgressSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Obx(() {
        final p = controller.cutSilencesProgress.value.clamp(0.0, 1.0);
        final stage = controller.cutSilencesStage.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cut Silences',
                  style: TextStyleCustom.unboundedMedium500(
                    color: whitePure(context),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              stage.isEmpty ? 'Working…' : stage,
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(context).withAlpha(220),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: p,
              minHeight: 6,
              backgroundColor: whitePure(context).withAlpha(40),
              valueColor: AlwaysStoppedAnimation(whitePure(context)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(p * 100).round()}%',
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context).withAlpha(200),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }),
    );
  }
}

class _VideoCropSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VideoCropSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final options = <MapEntry<String, VideoCropPreset>>[
      const MapEntry('Original', VideoCropPreset.original),
      const MapEntry('1:1', VideoCropPreset.square1x1),
      const MapEntry('4:5', VideoCropPreset.portrait4x5),
      const MapEntry('16:9', VideoCropPreset.landscape16x9),
      const MapEntry('9:16', VideoCropPreset.portrait9x16),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Obx(() {
        final seg = controller.activeSegment;
        final selected = seg?.edits.crop ?? VideoCropPreset.original;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Crop',
                  style: TextStyleCustom.unboundedMedium500(
                    color: whitePure(context),
                    fontSize: 16,
                  ),
                ),
                InkWell(
                  onTap: Get.back,
                  child: Icon(Icons.close_rounded, color: whitePure(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((e) {
                final isSelected = e.value == selected;
                return InkWell(
                  onTap: () {
                    controller.setActiveSegmentCrop(e.value);
                    Get.back();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? whitePure(context).withAlpha(30)
                          : whitePure(context).withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? whitePure(context)
                            : whitePure(context).withAlpha(90),
                      ),
                    ),
                    child: Text(
                      e.key,
                      style: TextStyleCustom.unboundedMedium500(
                          color: whitePure(context)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        );
      }),
    );
  }
}

class _VideoVolumeSheet extends StatelessWidget {
  final CameraEditScreenController controller;

  const _VideoVolumeSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: ShapeDecoration(
        color: blackPure(context),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 18,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Obx(() {
        final vol = controller.videoVolume.value.clamp(0.0, 1.0);
        final hasMusic = controller.content.value.sound?.downloadedURL != null;
        final musicVol = controller.musicVolume.value.clamp(0.0, 1.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Volume',
                  style: TextStyleCustom.unboundedMedium500(
                    color: whitePure(context),
                    fontSize: 16,
                  ),
                ),
                InkWell(
                  onTap: Get.back,
                  child: Icon(Icons.close_rounded, color: whitePure(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasMusic) ...[
              Text(
                'Original',
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context).withAlpha(220),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Slider(
              value: vol,
              min: 0.0,
              max: 1.0,
              onChanged: (v) {
                controller.setVideoVolume(v);
              },
              activeColor: whitePure(context),
              inactiveColor: whitePure(context).withAlpha(80),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0',
                  style: TextStyleCustom.outFitRegular400(
                    color: whitePure(context).withAlpha(200),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${(vol * 100).round()}',
                  style: TextStyleCustom.outFitRegular400(
                    color: whitePure(context).withAlpha(200),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (hasMusic) ...[
              const SizedBox(height: 14),
              Text(
                'Music',
                style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context).withAlpha(220),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Slider(
                value: musicVol,
                min: 0.0,
                max: 1.0,
                onChanged: (v) {
                  controller.setMusicVolume(v);
                },
                activeColor: whitePure(context),
                inactiveColor: whitePure(context).withAlpha(80),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0',
                    style: TextStyleCustom.outFitRegular400(
                      color: whitePure(context).withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(musicVol * 100).round()}',
                    style: TextStyleCustom.outFitRegular400(
                      color: whitePure(context).withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButtonCustom(
                    title: 'Done',
                    onTap: Get.back,
                  ),
                ),
              ],
            )
          ],
        );
      }),
    );
  }
}
