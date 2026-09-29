import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:retrytech_plugin/retrytech_plugin.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/enum/chat_enum.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/screenshot_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/chat/message_data.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
import 'package:shortzz/screen/share_sheet_widget/share_sheet_widget.dart';
import 'package:shortzz/screen/share_sheet_widget/widget/more_user_sheet.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';

class ShareSheetWidgetController extends BaseController {
  FirebaseFirestore db = FirebaseFirestore.instance;
  User? myUser = SessionManager.instance.getUser();
  RxList<ChatThread> chatsUsers = <ChatThread>[].obs;
  RxList<ChatThread> filterChatsUsers = <ChatThread>[].obs;
  RxList<ChatThread> selectedConversation = <ChatThread>[].obs;
  RxList<User> followers = <User>[].obs;
  RxList<int> followingIds = <int>[].obs;
  RxBool isFollowersLoading = false.obs;
  Post? post;

  StreamSubscription<QuerySnapshot<ChatThread>>? usersListen;
  Function()? onCallBack;
  final RetrytechPlugin _retrytechPlugin = RetrytechPlugin();

  Setting? get setting => SessionManager.instance.getSettings();

  final Map<String, dynamic>? extraData;

  ShareSheetWidgetController(this.post, this.onCallBack, {this.extraData});

  Rx<String> waterMarkPath = ''.obs;
  GlobalKey screenShotKey = GlobalKey();

  @override
  void onInit() {
    super.onInit();
    if (myUser?.followingIds != null) {
      followingIds.assignAll(myUser!.followingIds!);
    }
    _fetchUsers();
    _fetchFollowers();
  }

  Future<void> _fetchFollowers() async {
    final myId = SessionManager.instance.getUserID();
    if (myId <= 0) return;
    isFollowersLoading.value = true;
    try {
      final list = await UserService.instance
          .fetchMyFollowers(lastItemId: -1, userId: myId);
      final users = <User>[];
      for (final f in list) {
        final u = f.fromUser;
        if (u != null && (u.id ?? -1) > 0) users.add(u);
      }
      followers.assignAll(users);
    } catch (_) {
      followers.clear();
    } finally {
      isFollowersLoading.value = false;
    }
  }

  @override
  void onReady() {
    DefaultCacheManager()
        .getSingleFile(setting?.watermarkImage?.addBaseURL() ?? '')
        .then((value) {
      waterMarkPath.value = value.path;
      Future.delayed(const Duration(milliseconds: 250), () {
        ScreenshotManager.captureScreenshot(screenShotKey).then((value) {
          waterMarkPath.value = value?.path ?? '';
        });
      });
    });
    super.onReady();
  }

  @override
  void onClose() {
    usersListen?.cancel();
    super.onClose();
  }

  void _fetchUsers() {
    usersListen = db
        .collection(FirebaseConst.users)
        .doc(myUser?.id.toString())
        .collection(FirebaseConst.usersList)
        .withConverter(
            fromFirestore: (snapshot, options) =>
                ChatThread.fromJson(snapshot.data()!),
            toFirestore: (ChatThread value, options) => value.toJson())
        .where(FirebaseConst.isDeleted, isEqualTo: false)
        .orderBy(FirebaseConst.id, descending: true)
        .snapshots()
        .listen((event) {
      for (var change in event.docChanges) {
        final ChatThread? user = change.doc.data();
        if (user == null) continue;
        switch (change.type) {
          case DocumentChangeType.added:
            if (user.chatType == ChatType.approved) {
              chatsUsers.add(user);
              filterChatsUsers.add(user);
            }
            break;
          case DocumentChangeType.modified:
          case DocumentChangeType.removed:
        }
      }
    }, onError: (error) {
      if (error is FirebaseException && error.code == 'permission-denied') {
        Loggers.error('Firestore permission denied (share users): $error');
        usersListen?.cancel();
        return;
      }
      Loggers.error('Firestore share users listener error: $error');
    });
  }

  void onUserTap(ChatThread conversation) {
    if (selectedConversation.contains(conversation)) {
      selectedConversation.remove(conversation);
      return;
    } else {
      if (selectedConversation.length >= AppRes.shareChatLimit) {
        return showSnackBar(LKey.shareLimitMessage
            .trParams({'share_chat_limit': AppRes.shareChatLimit.toString()}));
      }
      selectedConversation.add(conversation);
    }
  }

  void onNotifyTap(ChatThread conversation, String link) async {
    if (selectedConversation.contains(conversation)) {
      return; // Already sent/selected
    }

    // Send the message
    final chat = Get.put(ChatScreenController(conversation.obs),
        tag: '${conversation.conversationId}');

    if (extraData != null && extraData!['is_live_stream'] == true) {
      await chat.sendMessageToFireStore(
          type: MessageType.liveStream,
          textMessage: link,
          liveStreamId: extraData!['live_stream_id'],
          liveStreamImage: extraData!['live_stream_image'],
          liveStreamTitle: extraData!['live_stream_title']);
    } else {
      await chat.sendMessageToFireStore(
          type: MessageType.text, textMessage: link);
    }

    await Get.delete<ChatScreenController>(
        tag: '${conversation.conversationId}');

    // Mark as notified/sent in UI
    selectedConversation.add(conversation);
  }

  void onFollowTap(ChatThread conversation) async {
    final userId = conversation.chatUser?.userId;
    if (userId == null) return;

    // Optimistic update
    myUser?.followingIds ??= [];
    if (!followingIds.contains(userId)) {
      followingIds.add(userId);
      myUser!.followingIds!.add(userId);
      update(); // Refresh UI

      // Call API
      await UserService.instance.followUser(userId: userId);
    }
  }

  void onSendLinkChat(String link) async {
    Get.back();
    showSnackBar(LKey.postSentSuccessfully.tr);
    final controller = Get.find<ShareSheetWidgetController>();
    for (var element in controller.selectedConversation) {
      final chat = Get.put(ChatScreenController(element.obs),
          tag: '${element.conversationId}');
      if (extraData != null && extraData!['is_live_stream'] == true) {
        await chat.sendMessageToFireStore(
            type: MessageType.liveStream,
            textMessage: link,
            liveStreamId: extraData!['live_stream_id'],
            liveStreamImage: extraData!['live_stream_image'],
            liveStreamTitle: extraData!['live_stream_title']);
      } else {
        await chat.sendMessageToFireStore(
            type: MessageType.text, textMessage: link);
      }
      await Get.delete<ChatScreenController>(tag: '${element.conversationId}');
    }
  }

  Future<void> sendLinkToFollower(
      {required User user, required String link}) async {
    final myId = SessionManager.instance.getUserID();
    final otherId = user.id ?? -1;
    if (myId <= 0 || otherId <= 0) return;

    final conversationId = [myId, otherId].conversationId;
    final thread = ChatThread(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lastMsg: '',
        msgCount: 0,
        isDeleted: false,
        deletedId: 0,
        iAmBlocked: false,
        iBlocked: user.isBlock ?? false,
        requestType: UserRequestAction.accept.title,
        chatType: ChatType.approved,
        conversationId: conversationId,
        userId: otherId);
    thread.chatUser = user.appUser;

    final controller =
        Get.put(ChatScreenController(thread.obs), tag: conversationId);
    controller.otherUser = user;
    if (extraData != null && extraData!['is_live_stream'] == true) {
      await controller.sendMessageToFireStore(
          type: MessageType.liveStream,
          textMessage: link,
          liveStreamId: extraData!['live_stream_id'],
          liveStreamImage: extraData!['live_stream_image'],
          liveStreamTitle: extraData!['live_stream_title']);
    } else {
      await controller.sendMessageToFireStore(
          type: MessageType.text, textMessage: link);
    }
    await Get.delete<ChatScreenController>(tag: conversationId);
  }

  void onMoreTap() {
    Get.bottomSheet(const MoreUserSheet(), isScrollControlled: true);
  }

  onSearchUser(String value) {
    filterChatsUsers.value =
        chatsUsers.search(value, (p0) => p0.chatUser?.username ?? '');
  }

  void onShareSheetBottomBtnTap(ShareOption type, String link,
      {Post? post}) async {
    final postId = post?.id;

    Future<void> handleUrlLaunch(String url, {String? fallbackUrl}) async {
      final result = await url.lunchUrl;
      Loggers.info('Handle Url launch : ${result.message}');

      Get.back();
      if (result.status == true) {
        if (post != null) {
          increaseShareCount(postId);
        }
      } else if (result.message == 'ACTIVITY_NOT_FOUND' &&
          fallbackUrl != null) {
        fallbackUrl.lunchUrl;
      }
    }

    switch (type) {
      case ShareOption.whatsapp:
        await handleUrlLaunch(type.value(link),
            fallbackUrl: AppRes.whatsappPlayStoreLink);
        break;

      case ShareOption.instagram:
        if (Platform.isIOS) {
          final result = await type.value(link).lunchUrl;
          Get.back();
          if (result.status == true) {
            increaseShareCount(postId);
          } else if (result.message == 'ACTIVITY_NOT_FOUND') {
            showSnackBar('instagramNotInstalled');
          }
        } else {
          try {
            final success = await _retrytechPlugin.shareToInstagram(link);
            if (success == true) {
              increaseShareCount(postId);
            }
          } on PlatformException {
            await AppRes.instagramPlayStoreLink.lunchUrl;
          } finally {
            Get.back();
          }
        }
        break;

      case ShareOption.telegram:
        await handleUrlLaunch(
          type.value(link),
          fallbackUrl: AppRes.telegramPlayStoreLink,
        );
        break;

      case ShareOption.download:
        _downloadReel(post);
        break;

      case ShareOption.share:
        // Future implementation
        break;

      case ShareOption.more:
        // Future implementation
        break;

      case ShareOption.copy:
        // Future implementation
        break;
    }
  }

  void _downloadReel(Post? reel) async {
    Get.back();
    final videoUrl = reel?.video?.addBaseURL() ?? '';
    if (videoUrl.isEmpty) {
      return Loggers.error('Video not found');
    }

    try {
      // Download video file
      String videoInputPath =
          (await DefaultCacheManager().getSingleFile(videoUrl)).path;
      final localPath = await PlatformPathExtension.localPath;
      String finalOutput = videoInputPath;
      // Watermarking (if enabled)
      final isWatermarkEnabled = setting?.watermarkStatus == 1;

      if (isWatermarkEnabled) {
        String outputPath = '${localPath}watermark_video.mp4';

        if (waterMarkPath.isEmpty) {
          return showSnackBar(LKey.downloadingFailed.tr);
        }
        bool? result = await _retrytechPlugin.addWaterMarkInVideo(
            inputPath: videoInputPath,
            thumbnailPath: waterMarkPath.value,
            username: '@${reel?.user?.username ?? AppRes.appName}',
            outputPath: outputPath);

        if (result == true) {
          finalOutput = outputPath;
        }
      }

      // Save to gallery
      await Gal.putVideo(finalOutput);
      stopSnackBar();
      showSnackBar(LKey.downloadCompletedSuccessfully.tr);
      Loggers.info(LKey.downloadCompletedSuccessfully.tr);
    } on GalException catch (_) {
      stopSnackBar();
      showSnackBar(LKey.downloadCompletedSuccessfully.tr);
      Loggers.info(LKey.downloadCompletedSuccessfully.tr);
    } catch (e) {
      Loggers.error('Download error: $e');
    }
  }

  void onSendChat(Post? post) async {
    Get.back();
    showSnackBar(LKey.postSentSuccessfully.tr);
    final controller = Get.find<ShareSheetWidgetController>();
    for (var element in controller.selectedConversation) {
      final controller = Get.put(ChatScreenController(element.obs),
          tag: '${element.conversationId}');
      await controller.sendMessageToFireStore(
          type: MessageType.post,
          postMessage: jsonEncode(post?.toJsonForChat()));

      await Get.delete<ChatScreenController>(tag: '${element.conversationId}');
      increaseShareCount(post?.id);
    }
  }

  void increaseShareCount(int? postId) async {
    StatusModel response =
        await PostService.instance.increaseShareCount(postId: postId);
    if (response.status == true) {
      onCallBack?.call();
    }
  }
}
