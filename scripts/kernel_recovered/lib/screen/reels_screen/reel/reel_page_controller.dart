import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/economy_state.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/share_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/moderator_service.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/post_story/music/music_model.dart';
import 'package:shortzz/model/post_story/post_by_id.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/audio_details_screen/audio_sheet.dart';
import 'package:shortzz/screen/comment_sheet/comment_sheet.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet_controller.dart';
import 'package:shortzz/screen/post_screen/post_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/saved_post_screen/saved_post_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/common/controller/professional_controller.dart';
import 'package:shortzz/screen/ads_manager/screen/create_campaign/create_campaign_screen.dart';

class ReelController extends BaseController {
  final PageController pageController = PageController();
  Rx<Post> reelData = Post(id: -1).obs;
  // Fix: Initialize RxSet properly to avoid setState during build
  final RxSet<int> giftedReelIds = RxSet<int>();
  RxList<Post> reels = <Post>[].obs;
  RxBool isReelLoading = false.obs;
  bool isLikeLoading = false;
  bool isSavedLoading = false;

  final RxBool isLikeEnabled = false.obs;  // FIXED: Start as false - enable after 15 sec
  final RxBool isCommentEnabled = false.obs;  // FIXED: Start as false - enable after 15 sec
  final RxBool isShareEnabled = false.obs;  // FIXED: Start as false - enable after 15 sec

  static const String _likeRewardedIdsKey = 'miner_like_rewarded_post_ids';
  final GetStorage _box = GetStorage('shortzz');

  User? get myUser => SessionManager.instance.getUser();
  Timer? _debounce;

  ReelController(this.reelData) {
    reelData.listen((p0) {
      if (p0.postType == PostType.video &&
          Get.isRegistered<PostScreenController>(tag: '${p0.id}')) {
        final controller = Get.find<PostScreenController>(tag: '${p0.id}');
        controller.updatePost(p0);
      }
    });
    
    // DEBUG: Verify initial values
    Loggers.info('[REEL_CONTROLLER] Created - Initial values: isLikeEnabled=$isLikeEnabled, isCommentEnabled=$isCommentEnabled, isShareEnabled=$isShareEnabled');
  }

  void handleDelete({required bool isModerator}) {
    final Post post = reelData.value;
    if (post.id == null) {
      return Loggers.error('Invalid Post ID : ${post.id}');
    }
    Get.bottomSheet(
      ConfirmationSheet(
        title: LKey.deletePostTitle.tr,
        description: LKey.deletePostMessage.tr,
        onTap: () => _deletePost(post, isModerator: isModerator),
      ),
    );
  }

  void _deletePost(Post post, {required bool isModerator}) async {
    final int postId = post.id?.toInt() ?? -1;
    if (postId <= 0) {
      return showSnackBar('Invalid Post ID');
    }
    showLoader();
    StatusModel model;
    if (isModerator) {
      model =
          await ModeratorService.instance.moderatorDeletePost(postId: postId);
    } else {
      model = await PostService.instance.deletePost(postId: postId);
    }
    stopLoader();
    if (model.status == true) {
      if (Get.isRegistered<ProfileScreenController>(
          tag: ProfileScreenController.tag)) {
        final controller = Get.find<ProfileScreenController>(
            tag: ProfileScreenController.tag);
        controller.reels.removeWhere((element) => element.id == postId);
        controller.reels.refresh();
      }

      if (Get.isRegistered<ReelsScreenController>(tag: ReelsScreenController.tag)) {
        final reelsController =
            Get.find<ReelsScreenController>(tag: ReelsScreenController.tag);
        reelsController.reels.removeWhere((e) => e.id == postId);
        reelsController.reels.refresh();
      }
      reelData.value = Post();
    } else {
      showSnackBar(model.message?.tr.capitalizeFirst);
    }
  }

  void setLikeEnabled(bool enabled) {
    if (isLikeEnabled.value == enabled) return;
    isLikeEnabled.value = enabled;
  }

  void setCommentEnabled(bool enabled) {
    if (isCommentEnabled.value == enabled) return;
    isCommentEnabled.value = enabled;
  }

  void setShareEnabled(bool enabled) {
    if (isShareEnabled.value == enabled) return;
    isShareEnabled.value = enabled;
  }

  /// Enable all actions (like, comment, share) - called after 15 sec watch or video end
  void enableAllActions() {
    setLikeEnabled(true);
    setCommentEnabled(true);
    setShareEnabled(true);
  }

  /// Disable all actions for task flow - called initially when from task
  void disableAllActionsForTask() {
    setLikeEnabled(false);
    setCommentEnabled(false);
    setShareEnabled(false);
  }

  void showLikeLockedMessage() {
    if (Get.isSnackbarOpen == true) return;
    Get.rawSnackbar(
      messageText: const Text(
        'Please wait...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      snackStyle: SnackStyle.FLOATING,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void onClose() {
    super.onClose();
    reelData.close();
    _debounce?.cancel();
  }

  updateReelData({Post? reel, bool isIncreaseCoin = false}) {
    if (reel != null) {
      if (isIncreaseCoin) {
        reelData.update((val) => val?.increaseViews());
      } else {
        reelData.value = reel;
      }
    }
  }

  void onBoostTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    final postId = reelData.value.id?.toInt() ?? -1;
    if (postId <= 0) return;

    final post = reelData.value;
    final mediaUrl = post.getThumbnail.addBaseURL();
    Get.to(
      () => CreateCampaignScreen(
        isBoostMode: true,
        postId: postId,
        postTitle: 'Boost Reel',
        postCaption: post.description,
        mediaUrl: mediaUrl,
        postType: post.postType,
        openQuickBudgetOnStart: true,
        redirectToAnalyticsOnSubmit: true,
      ),
      preventDuplicates: false,
    );
  }

  void onLikeTap() {
    if (!isLikeEnabled.value) {
      showLikeLockedMessage();
      return;
    }
    if (reelData.value.isLiked == false) {
      HapticManager.shared.light();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    int reelId = reelData.value.id?.toInt() ?? -1;

    if (reelId == -1) {
      return Loggers.error('Invalid Post id : $reelId');
    }

    reelData.update((val) {
      val?.likeToggle(val.isLiked == true ? false : true);
    });

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        await (reelData.value.isLiked == true
            ? _likePostApi(reelId)
            : _disLikePostApi(reelId));
        // if (reelData.value.postType == PostType.video &&
        //     Get.isRegistered<PostScreenController>(tag: '$reelId')) {
        //   final controller = Get.find<PostScreenController>(tag: '$reelId');
        //   controller.updatePost(reelData.value);
        // }
      } catch (e) {
        Loggers.error('ERROR IN LIKE  REEL $e');
      }
    });
  }

  Future<void> _likePostApi(int id) async {
    final alreadyRewarded = _hasLikeRewarded(id);
    final int ecoPointsBefore = EconomyState.instance.points.value;
    final int ecoCoinsBefore = EconomyState.instance.coins.value;
    final double ecoEarningsBefore = EconomyState.instance.earnings.value;

    StatusModel result = await PostService.instance.likePost(postId: id);
    if (result.status == true) {
      if (alreadyRewarded) {
        EconomyState.instance.set(
          points: ecoPointsBefore,
          coins: ecoCoinsBefore,
          earnings: ecoEarningsBefore,
        );

        // Backend may still ingest points asynchronously; restore again after a short delay.
        DebounceAction.shared.call(() {
          EconomyState.instance.set(
            points: ecoPointsBefore,
            coins: ecoCoinsBefore,
            earnings: ecoEarningsBefore,
          );
        }, milliseconds: 500);
      } else {
        _markLikeRewarded(id);
      }

      Post? reel = reelData.value;
      if (reel.user?.notifyPostLike == 1 && myUser?.id != reel.userId) {
        FirebaseNotificationManager.instance.sendLocalisationNotification(
            LKey.activityLikedPost,
            type: NotificationType.post,
            body: NotificationInfo(id: reel.id),
            deviceType: reel.user?.device ?? 0,
            deviceToken: reel.user?.deviceToken ?? '',
            languageCode: reel.user?.appLanguage);
      }
      // Refresh tasks to update progress for "like" tasks
      _refreshTasksIfNeeded();
      
      // Call task callback if coming from task flow
      _notifyTaskLikeAction(id);
    }
  }

  bool _hasLikeRewarded(int postId) {
    final dynamic raw = _box.read(_likeRewardedIdsKey);
    if (raw is List) {
      return raw.any((e) => e.toString() == postId.toString());
    }
    return false;
  }

  void _markLikeRewarded(int postId) {
    final dynamic raw = _box.read(_likeRewardedIdsKey);
    final List<String> ids = (raw is List)
        ? raw.map((e) => e.toString()).toList()
        : <String>[];
    final v = postId.toString();
    if (!ids.contains(v)) {
      ids.add(v);
      _box.write(_likeRewardedIdsKey, ids);
    }
  }

  void _refreshTasksIfNeeded() {
    try {
      if (Get.isRegistered<ProfessionalController>()) {
        Get.find<ProfessionalController>().refreshTasks();
      }
    } catch (_) {}
  }

  void _notifyTaskLikeAction(int postId) {
    try {
      // Find the parent ReelsScreenController and call its onLikeAction
      const parentTag = ReelsScreenController.tag;
      if (Get.isRegistered<ReelsScreenController>(tag: parentTag)) {
        final parent = Get.find<ReelsScreenController>(tag: parentTag);
        parent.onLikeAction?.call(postId);
      }
    } catch (_) {}
  }

  Future<void> _disLikePostApi(int id) async {
    await PostService.instance.disLikePost(postId: id);
  }

  Future<void> onCommentTap(
      {PostByIdData? postByIdData, bool isFromNotification = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Get.bottomSheet(
        CommentSheet(
          replyComment: postByIdData?.reply,
          comment: postByIdData?.comment,
          post: reelData.value,
          isFromNotification: isFromNotification,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent);
  }

  void onSaved() {
    FocusManager.instance.primaryFocus?.unfocus();
    int reelId = reelData.value.id?.toInt() ?? -1;
    if (reelId == -1) {
      return Loggers.error('Invalid Post id : $reelId');
    }

    if (isSavedLoading) {
      return Loggers.error('Is saved loading : $isSavedLoading');
    }
    isSavedLoading = true;
    HapticManager.shared.light();
    reelData.update((val) {
      val?.saveToggle(val.isSaved == true ? false : true);
    });

    DebounceAction.shared.call(() async {
      if (reelData.value.id == null) {
        return Loggers.error('Reel value not found');
      }
      await ((reelData.value.isSaved ?? false)
          ? _savePostApi(reelId)
          : _unSavePostApi(reelId));
      isSavedLoading = false;
    });
  }

  Future<void> _savePostApi(int id) async {
    StatusModel result = await PostService.instance.savePost(postId: id);
    if (result.status == true) {
      if (Get.isRegistered<SavedPostScreenController>()) {
        final controller = Get.find<SavedPostScreenController>();
        controller.unsavedIds.removeWhere((element) => element == id);
      }
    }
  }

  Future<void> _unSavePostApi(int id) async {
    StatusModel result = await PostService.instance.unSavePost(postId: id);
    if (result.status == true) {
      if (Get.isRegistered<SavedPostScreenController>()) {
        final controller = Get.find<SavedPostScreenController>();
        controller.unsavedIds.add(id);
      }
    }
  }

  void onShareTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    ShareManager.shared.showCustomShareSheet(
      post: reelData.value,
      keys: ShareKeys.reel,
      onShareSuccess: () {
        reelData.update((val) => val?.increaseShares(1));
      },
    );
  }

  void onGiftTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    GiftManager.openGiftSheet(
      userId: reelData.value.userId ?? -1,
      onCompletion: (giftManager) {
        GiftManager.showAnimationDialog(giftManager.gift);
        GiftManager.sendNotification(reelData.value);
        final rid = reelData.value.id?.toInt();
        if (rid != null) {
          giftedReelIds.add(rid);
        }
        showSnackBar('Gift sent');
      },
    );
  }

  void onAudioTap(Music? music) async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Get.bottomSheet(AudioSheet(music: music), isScrollControlled: true);
  }

  void onUserTap(User? user) {
    if (reelData.value.id == -1) return;
    NavigationService.shared.openProfileScreen(user);
  }

  void notifyCommentSheet(PostByIdData? data) {
    if (data != null && (data.comment != null || data.reply != null)) {
      DebounceAction.shared.call(() {
        onCommentTap(postByIdData: data, isFromNotification: true);
      }, milliseconds: 1000);
    }
  }
}
