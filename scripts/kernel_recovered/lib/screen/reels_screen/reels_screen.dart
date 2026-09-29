import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/my_refresh_indicator.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/post_story/post_by_id.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/comment_sheet/widget/hashtag_and_mention_view.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_ad_page.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_native_ad_widget.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_scratch_card_page.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/widget/reels_text_field.dart';
import 'package:shortzz/screen/reels_screen/widget/reels_top_bar.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:video_player/video_player.dart';

class ReelsScreen extends StatelessWidget {
  final RxList<Post> reels;
  final int position;
  final Widget? widget;
  final Future<void> Function()? onFetchMoreData;
  final Future<void> Function()? onRefresh;
  final RxBool? isLoading;
  final PostByIdData? postByIdData;
  final bool isHomePage;
  final bool isFromChat;
  final String? controllerTag;

  const ReelsScreen(
      {super.key,
        required this.reels,
        required this.position,
        this.onFetchMoreData,
        this.widget,
        this.onRefresh,
        this.isLoading,
        this.postByIdData,
        this.isHomePage = false,
        this.isFromChat = false,
        this.controllerTag});

  @override
  Widget build(BuildContext context) {
    final String tagToUse = isHomePage
        ? ReelsScreenController.tag
        : (controllerTag ?? '${DateTime.now().millisecondsSinceEpoch}');

    final ReelsScreenController controller = Get.isRegistered<ReelsScreenController>(tag: tagToUse)
        ? Get.find<ReelsScreenController>(tag: tagToUse)
        : Get.put(
            ReelsScreenController(
              reels: reels,
              position: position.obs,
              onFetchMoreData: onFetchMoreData,
              onRefresh: onRefresh,
              isHomePage: isHomePage,
            ),
            tag: tagToUse,
          );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.startIfNeeded();
    });

    return Scaffold(
      backgroundColor: blackPure(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: MyRefreshIndicator(
                  onRefresh: onRefresh ?? () async {},
                  shouldRefresh: onRefresh != null,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Obx(() {
                        final reels = controller.reels;
                        final isLoadingValue = controller.isLoading.value ?? false;
                        return isLoadingValue && reels.isEmpty
                            ? const LoaderWidget()
                            : !isLoadingValue && reels.isEmpty
                            ? NoDataWidgetWithScroll(
                            title: LKey.reelsEmptyTitle.tr,
                            description: LKey.reelsEmptyDescription.tr)
                            : PageView.builder(
                          controller: controller.pageController,
                          itemCount: controller.feedItems.length,
                          physics: controller.canScroll
                            ? const CustomPageViewScrollPhysics()
                            : const NeverScrollableScrollPhysics(), // FIXED: Prevent scroll when scratch card open
                          onPageChanged: controller.onPageChanged,
                          scrollDirection: Axis.vertical,
                          itemBuilder: (context, index) {
                            final feedItem = controller.feedItems[index];
                            
                            // Handle Scratch Card (inline like ads)
                            if (feedItem.isScratchCard) {
                              Loggers.info('[REELS_DEBUG] Rendering Scratch Card at index $index');
                              return SizedBox(
                                height: MediaQuery.of(context).size.height,
                                child: ReelScratchCardPage(
                                  onComplete: () {
                                    // Remove scratch card from feed after completion
                                    controller.removeScratchCardFromFeed(index);
                                  },
                                ),
                              );
                            }
                            
                            // Handle AdMob Native Ad
                            if (feedItem.isAdMobNative) {
                              Loggers.info('[REELS_DEBUG] Rendering AdMob Native Ad at index $index');
                              return ReelNativeAdWidget(
                                adIndex: feedItem.adIndex ?? index,
                                height: MediaQuery.of(context).size.height,
                              );
                            }
                            
                            // Handle Backend Ad
                            if (feedItem.isBackendAd) {
                              final adPost = feedItem.data as Post;
                              Loggers.info('[REELS_DEBUG] Rendering Backend Ad (ReelAdPage) at index $index');
                              return ReelAdPage(adPost: adPost);
                            }
                            
                            // Handle Regular Post
                            final reel = feedItem.data as Post;
                            Loggers.info('[REELS_DEBUG] Rendering ReelPage at index $index, id=${reel.id}');
                            return Obx(() {
                              controller.ensureControllerAtIndex(index);
                              VideoPlayerController? videoController =
                              controller.videoControllers[index];
                              return ReelPage(
                                  reelData: reel,
                                  videoPlayerController:
                                  videoController,
                                  likeKey: GlobalKey(),
                                  postByIdData: postByIdData,
                                  isFromChat: isFromChat);
                            });
                          },
                        );
                      }),
                      HashTagAndMentionUserView(
                          helper: controller.commentHelper),
                    ],
                  ),
                ),
              ),
              ReelsTextField(controller: controller),
            ],
          ),
          ReelsTopBar(controller: controller, widget: widget),
        ],
      ),
    );
  }
}

class CustomPageViewScrollPhysics extends ScrollPhysics {
  const CustomPageViewScrollPhysics({super.parent});

  @override
  CustomPageViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomPageViewScrollPhysics(parent: buildParent(ancestor)!);
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 32,
  );

  @override
  double get minFlingVelocity => 50.0;
}
