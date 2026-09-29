import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/ads_controller.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/smart_assist_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/manager/app_open_promotion_manager.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/smart_assist/smart_behavior_tracker.dart';
import 'package:shortzz/common/service/smart_assist/smart_prediction_engine.dart';
import 'package:shortzz/common/service/smart_assist/voice_ui_action_registry.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/common/service/video_cache_helper/video_cache_helper.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/call_screen/incoming_call_screen.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/chat_theme_sheet/chat_theme_sheet_controller.dart';
import 'package:shortzz/screen/feed_screen/feed_screen_controller.dart';
import 'package:shortzz/screen/gif_sheet/gif_sheet_controller.dart';
import 'package:shortzz/screen/sticker_sheet/sticker_sheet_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DashboardScreenController extends BaseController
    with GetSingleTickerProviderStateMixin {
  List<dynamic> bottomIconList = [
    AssetRes.icReel,
    AssetRes.icPost,
    AssetRes.icLiveStream,
    AssetRes.icSearch,
    AssetRes.icChat,
    AssetRes.icProfile,
  ];
  RxInt selectedPageIndex = 0.obs;
  RxDouble scaleValue = 1.0.obs;
  Function(int index)? onBottomIndexChanged;
  Rx<PostUploadingProgress> postProgress = Rx(PostUploadingProgress());
  Function(PostUploadingProgress progress) onProgress = (_) {};

  final RxInt smartHighlightIndex = (-1).obs;
  final Rx<SmartSuggestion?> smartSuggestion = Rx<SmartSuggestion?>(null);
  DateTime? _lastSmartEvalAt;
  Timer? _smartEvalTimer;
  Timer? _cacheCleanupTimer;
  Worker? _smartToggleWorker;

  late AnimationController animationController;

  FirebaseFirestore db = FirebaseFirestore.instance;
  RxInt unReadCount = 0.obs;

  late StreamSubscription _unReadCountSubscription;
  StreamSubscription<QuerySnapshot>? _callSubscription;
  StreamSubscription<QuerySnapshot>? _groupCallSubscription;
  bool _mergePromptOpen = false;
  late Animation<double> scaleAnimation;
  User? user = SessionManager.instance.getUser();

  @override
  void onInit() {
    super.onInit();
    // Reset call state on fresh init
    isCallActive = false;
    currentCallId = null;

    Get.put(GifSheetController());
    Get.put(StickerSheetController());
    Get.put(ChatThemeSheetController());
    Get.put(FirebaseFirestoreController());
    animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    )..addListener(() {
        scaleValue.value = scaleAnimation.value; // Update reactive scale value
      });
    onProgress = (progress) {
      postProgress.value = progress;
    };
    Get.put(AdsController());
  }

  void onVoiceFeatureCommand(String feature) {
    final idx = _bottomIndexForFeature(feature);
    if (idx == null) return;
    onChanged(idx);
  }

  void onSmartSuggestionDismiss() {
    final s = smartSuggestion.value;
    if (s == null) return;
    SmartPredictionEngine.instance.markSuggestionDismissed(feature: s.feature);
    smartSuggestion.value = null;
    smartHighlightIndex.value = -1;
  }

  void onSmartSuggestionExecuted() {
    final s = smartSuggestion.value;
    if (s == null) return;
    final index = _bottomIndexForFeature(s.feature);
    if (index != null) {
      onChanged(index);
    }
    smartSuggestion.value = null;
    smartHighlightIndex.value = -1;
  }

  int? _bottomIndexForFeature(String feature) {
    switch (feature) {
      case 'reels':
        return 0;
      case 'feed':
        return 1;
      case 'live':
        return 2;
      case 'search':
        return 3;
      case 'chat':
        return 4;
      case 'profile':
        return 5;
      default:
        return null;
    }
  }

  void _maybeEvaluateSmartSuggestion() {
    final smartCtrl = Get.isRegistered<SmartAssistController>()
        ? Get.find<SmartAssistController>()
        : null;
    if (smartCtrl == null || !smartCtrl.isSmartSuggestionsActive) {
      smartSuggestion.value = null;
      smartHighlightIndex.value = -1;
      return;
    }

    final now = DateTime.now();
    if (_lastSmartEvalAt != null &&
        now.difference(_lastSmartEvalAt!) < const Duration(seconds: 8)) {
      return;
    }
    _lastSmartEvalAt = now;

    // Anti-noise: keep silent most of the time.
    if (Random().nextDouble() < 0.70) {
      smartSuggestion.value = null;
      smartHighlightIndex.value = -1;
      return;
    }

    final suggestion = SmartPredictionEngine.instance.predictNext(
      candidateFeatures: const [
        'profile',
        'chat',
        'search',
        'live',
        'feed',
        'reels',
      ],
    );
    if (suggestion == null) {
      smartSuggestion.value = null;
      smartHighlightIndex.value = -1;
      return;
    }

    final idx = _bottomIndexForFeature(suggestion.feature);
    if (idx == null || idx == selectedPageIndex.value) {
      smartSuggestion.value = null;
      smartHighlightIndex.value = -1;
      return;
    }

    SmartPredictionEngine.instance.markSuggestionShown(
      feature: suggestion.feature,
    );
    smartSuggestion.value = suggestion;
    smartHighlightIndex.value = idx;
  }

  @override
  void onReady() async {
    super.onReady();
    SubscriptionManager.shared.subscriptionListener();

    SmartBehaviorTracker.instance.onSessionStart();

    _maybeEvaluateSmartSuggestion();

    final smartCtrl = Get.isRegistered<SmartAssistController>()
        ? Get.find<SmartAssistController>()
        : null;
    _smartToggleWorker?.dispose();
    if (smartCtrl != null) {
      _smartToggleWorker = ever(smartCtrl.smartSuggestionsEnabled, (enabled) {
        if (enabled == true) {
          _startSmartSuggestionLoop();
          _maybeEvaluateSmartSuggestion();
        } else {
          _stopSmartSuggestionLoop();
          smartSuggestion.value = null;
          smartHighlightIndex.value = -1;
        }
      });
    }

    _startSmartSuggestionLoop();

    // Run below in parallel
    _fetchLanguageFromUser();
    _fetchUnReadCount();
    startCacheCleanupScheduler();
    _subscribeFollowUserIds();
    _listenToIncomingCalls();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppOpenPromotionManager.instance.maybeShowAppOpenPromotion();
    });
  }

  void startCacheCleanupScheduler() {
    UserService.instance.updateLastUsedAt();
    VideoCacheHelper.clearExpiredVideos();
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      VideoCacheHelper.clearExpiredVideos();
      UserService.instance.updateLastUsedAt();
    });
  }

  @override
  void onClose() {
    SmartBehaviorTracker.instance.onSessionEnd();
    _smartToggleWorker?.dispose();
    _smartToggleWorker = null;
    _stopSmartSuggestionLoop();
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = null;
    animationController.dispose();
    _unReadCountSubscription.cancel();
    _callSubscription?.cancel();
    _groupCallSubscription?.cancel();
    super.onClose();
  }

  // Track if we are currently in a call to avoid multiple screens
  static bool isCallActive = false;
  static String? currentCallId;

  static void checkIncomingCalls() {
    if (Get.isRegistered<DashboardScreenController>()) {
      Get.find<DashboardScreenController>()._listenToIncomingCalls();
    }
  }

  // Track notified missed calls to avoid spam on app open/updates
  final Set<String> _notifiedMissedCalls = {};

  void _listenToIncomingCalls() {
    // Refresh user from session to ensure we have the latest ID
    user = SessionManager.instance.getUser();
    final myId = user?.id;

    if (myId == null) {
      Loggers.error('[CALL] Cannot listen: User ID is null');
      return;
    }

    Loggers.info('[CALL] Listening for calls for user: $myId');

    // Cancel existing subscription to avoid duplicates
    _callSubscription?.cancel();
    _groupCallSubscription?.cancel();

    _callSubscription = db
        .collection('calls')
        .where('receiverId', isEqualTo: myId)
        //.orderBy('createdAt', descending: true) // Temporarily disabled to avoid index error
        .limit(5) // Limit to 5 to avoid fetching too many, we filter below
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          // Manual filtering since we can't sort by createdAt without index
          final docs = snapshot.docs;
          // Sort manually by creation time (newest first)
          docs.sort((a, b) {
            final t1 = (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime(2000);
            final t2 = (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime(2000);
            return t2.compareTo(t1);
          });

          final data = docs.first.data();
          final status = data['status'];
          final callId = data['callId'];
          final createdAt = data['createdAt'];
          DateTime? callTime;
          if (createdAt is Timestamp) {
            callTime = createdAt.toDate();
          }

          Loggers.info(
            '[CALL] Incoming call detected: $callId, Status: $status',
          );

          // Handle Ringing
          if (status == 'ringing') {
            // Check timestamp
            if (callTime != null) {
              final diff = DateTime.now().difference(callTime);
              if (diff.inSeconds > 60) {
                Loggers.info(
                  '[CALL] Ignoring old ringing call: ${diff.inSeconds}s',
                );
                return; // Ignore old calls
              }
            }

            // If we are already in a call, mark this new one as busy
            if (isCallActive) {
              // Strict check: if it's the SAME call, do nothing (just update)
              if (currentCallId == callId) return;

              // Double Check: Are we actually on the call screen?
              final currentRoute = Get.currentRoute;
              // Also check for "CallScreen" or "IncomingCallScreen" in route name in case of args
              final onCallScreen = currentRoute == '/IncomingCallScreen' ||
                  currentRoute == '/CallScreen';

              if (!onCallScreen) {
                // We are NOT on a call screen, but isCallActive is true.
                // This is a bug state (stuck). Reset it and allow the call.
                Loggers.warning(
                  '[CALL] isCallActive was true but route is $currentRoute. Resetting.',
                );
                isCallActive = false;
                currentCallId = null;
                // Proceed to show call (fall through)
              } else {
                _showMergePrompt(data);
                return;
              }
            }

            // Navigate to Incoming Call
            // Check if we are already navigating or there
            if (Get.currentRoute == '/IncomingCallScreen') {
              return;
            }

            Loggers.info('[CALL] Navigating to IncomingCallScreen');
            Get.to(() => IncomingCallScreen(callData: data));
          }

          // Handle Missed Call Notification
          if (status == 'missed') {
            // 1. Check if we already notified for this ID
            if (_notifiedMissedCalls.contains(callId)) return;

            // 2. Check if the call is recent (e.g., within last 5 minutes)
            // If we restart app, we don't want to notify for calls from yesterday.
            if (callTime != null) {
              final diff = DateTime.now().difference(callTime);
              if (diff.inMinutes > 5) {
                // Add to set so we don't check again
                _notifiedMissedCalls.add(callId);
                return;
              }
            }

            _notifiedMissedCalls.add(callId);

            final callerName = data['caller']['fullname'] ?? 'Unknown';
            // Use a fixed ID for missed calls to stack nicely or just one.
            final notificationId =
                DateTime.now().millisecondsSinceEpoch ~/ 1000;

            // Create a payload that opens the chat or call history
            // We'll use the 'chat' type structure roughly or handle a custom type
            // For simplicity, let's just open the app.
            // Ideally: Navigate to ChatScreen with this user.

            // Construct payload for ChatScreen
            final chatThread = ChatThread(
              userId: AppUser.fromJson(
                      Map<String, dynamic>.from(data['caller'] ?? const {}))
                  .userId,
              // other fields if needed...
            );

            // We need a proper payload structure that handleNotification understands
            // 'type': 'chat', 'notification_data': jsonString
            final payloadMap = {
              'type': 'chat',
              'notification_data': jsonEncode(chatThread.toJson())
            };

            FirebaseNotificationManager.instance.flutterLocalNotificationsPlugin
                .show(
                    notificationId,
                    'Missed Call',
                    'You missed a call from $callerName',
                    const NotificationDetails(
                      android: AndroidNotificationDetails(
                        'missed_calls',
                        'Missed Calls',
                        importance: Importance.high,
                        priority: Priority.high,
                      ),
                      iOS: DarwinNotificationDetails(),
                    ),
                    payload: jsonEncode(payloadMap));
          }
        }
      },
      onError: (e) {
        Loggers.error('[CALL] Listener Error: $e');
      },
    );

    _groupCallSubscription = db
        .collection('calls')
        .where('isGroup', isEqualTo: true)
        .where('participants', arrayContains: myId)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final t1 =
            (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final t2 =
            (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return t2.compareTo(t1);
      });

      for (final doc in docs) {
        final data = doc.data();
        final callId = (data['callId'] ?? doc.id)?.toString();
        if (callId == null) continue;

        final inviteStatus = data['inviteStatus'];
        final myInvite = (inviteStatus is Map) ? inviteStatus['$myId'] : null;
        if (myInvite != 'ringing') {
          continue;
        }

        final invitedAtMap = data['invitedAtMap'];
        final invitedAt =
            (invitedAtMap is Map) ? invitedAtMap['$myId'] : null;
        DateTime? ringTime;
        if (invitedAt is Timestamp) {
          ringTime = invitedAt.toDate();
        } else {
          final createdAt = data['createdAt'];
          if (createdAt is Timestamp) ringTime = createdAt.toDate();
        }
        if (ringTime != null) {
          final diff = DateTime.now().difference(ringTime);
          if (diff.inSeconds > 60) {
            continue;
          }
        }

        if (isCallActive) {
          if (currentCallId == callId) return;
          final currentRoute = Get.currentRoute;
          final onCallScreen =
              currentRoute == '/IncomingCallScreen' || currentRoute == '/CallScreen';
          if (!onCallScreen) {
            isCallActive = false;
            currentCallId = null;
          } else {
            _showMergePrompt(data);
            return;
          }
        }

        if (Get.currentRoute == '/IncomingCallScreen') {
          return;
        }

        Get.to(() => IncomingCallScreen(callData: data));
        return;
      }
    });
  }

  void onAppResumed() {
    _maybeEvaluateSmartSuggestion();
  }

  void _startSmartSuggestionLoop() {
    final smartCtrl = Get.isRegistered<SmartAssistController>()
        ? Get.find<SmartAssistController>()
        : null;
    if (smartCtrl == null || !smartCtrl.isSmartSuggestionsActive) {
      _stopSmartSuggestionLoop();
      return;
    }

    _smartEvalTimer?.cancel();
    _smartEvalTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _maybeEvaluateSmartSuggestion();
    });
  }

  void _showMergePrompt(Map<String, dynamic> incoming) {
    if (_mergePromptOpen) return;
    final currentRoomId = currentCallId;
    final incomingCallId = incoming['callId']?.toString();
    if (currentRoomId == null || incomingCallId == null) return;
    if (incomingCallId == currentRoomId) return;
    final callerIdRaw = incoming['callerId'];
    final callerId = callerIdRaw is num ? callerIdRaw.toInt() : null;
    if (callerId == null) return;

    _mergePromptOpen = true;
    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Incoming call',
                  style: TextStyleCustom.outFitBold700(fontSize: 18)),
              const SizedBox(height: 10),
              Text('Merge this caller into your current call?',
                  style: TextStyleCustom.outFitRegular400(fontSize: 14)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        try {
                          await db
                              .collection('calls')
                              .doc(incomingCallId)
                              .update({
                            'status': 'declined',
                            'endedAt': FieldValue.serverTimestamp(),
                            'endedBy': 'receiver',
                            'declineReason': 'Merged',
                          });
                          await db.collection('calls').doc(currentRoomId).set({
                            'isGroup': true,
                            'participants': FieldValue.arrayUnion([callerId]),
                            'inviteStatus.$callerId': 'ringing',
                            'invitedAtMap.$callerId':
                                FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        } catch (e) {
                          Loggers.error('[CALL] merge failed: $e');
                        }
                      },
                      child: const Text('Merge'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Get.back();
                        try {
                          await db
                              .collection('calls')
                              .doc(incomingCallId)
                              .update({
                            'status': 'declined',
                            'endedAt': FieldValue.serverTimestamp(),
                            'endedBy': 'receiver',
                            'declineReason': 'Declined',
                            'missedReason': 'rejected',
                          });
                        } catch (e) {
                          Loggers.error('[CALL] decline incoming failed: $e');
                        }
                      },
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isDismissible: true,
    ).whenComplete(() => _mergePromptOpen = false);
  }

  void _stopSmartSuggestionLoop() {
    _smartEvalTimer?.cancel();
    _smartEvalTimer = null;
  }

  onChanged(int index) {
    if (index == 1) {
      onFeedPostScrollDown(index);
    }
    if (selectedPageIndex.value == index) return;
    HapticFeedback.lightImpact();
    onBottomIndexChanged?.call(index);
    selectedPageIndex.value = index;

    final screen = _featureForBottomIndex(index);
    if (screen != null) {
      VoiceUiActionRegistry.instance.setCurrentScreen(screen);
    }

    if (screen != null) {
      SmartBehaviorTracker.instance.trackFeatureOpen(feature: screen);
    }

    _maybeEvaluateSmartSuggestion();

    animationController
      ..reset()
      ..forward();
  }

  String? _featureForBottomIndex(int index) {
    switch (index) {
      case 0:
        return 'reels';
      case 1:
        return 'feed';
      case 2:
        return 'live';
      case 3:
        return 'search';
      case 4:
        return 'chat';
      case 5:
        return 'profile';
      default:
        return null;
    }
  }

  onFeedPostScrollDown(int index) {
    if (selectedPageIndex.value != index) return;
    if (Get.isRegistered<FeedScreenController>()) {
      final controller = Get.find<FeedScreenController>();
      if (controller.posts.isNotEmpty && !controller.isLoading.value) {
        controller.postScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.linear,
        );
        controller.refreshKey.currentState?.show();
      }
    }
  }

  void _fetchUnReadCount() {
    _unReadCountSubscription = db
        .collection(FirebaseConst.users)
        .doc(user?.id.toString())
        .collection(FirebaseConst.usersList)
        .where(FirebaseConst.isDeleted, isEqualTo: false)
        .withConverter(
          fromFirestore: (snapshot, options) =>
              ChatThread.fromJson(snapshot.data()!),
          toFirestore: (ChatThread value, options) => value.toJson(),
        )
        .snapshots()
        .listen(
      (event) {
        final count =
            event.docs.where((doc) => (doc.data().msgCount ?? 0) > 0).length;
        unReadCount.value = count;
      },
      onError: (error) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          Loggers.error(
            'Firestore permission denied (unread count): $error',
          );
          unReadCount.value = 0;
          return;
        }
        Loggers.error('Firestore unread count listener error: $error');
      },
    );
  }

  Future<void> _fetchLanguageFromUser() async {
    String savedLanguage = SessionManager.instance.getLang();
    String userLanguage = user?.appLanguage ?? 'en';
    if (userLanguage != savedLanguage) {
      SessionManager.instance.setLang(userLanguage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.updateLocale(Locale(userLanguage));
      });
    }
  }

  void _subscribeFollowUserIds() async {
    Future.wait([addUserInFirebase()]);
    for (int id in (user?.followingIds ?? [])) {
      // Delay slightly to avoid overloading FCM
      await Future.delayed(const Duration(milliseconds: 100));
      Future.wait([
        FirebaseNotificationManager.instance.subscribeToTopic(topic: '$id'),
      ]);
    }
  }

  Future addUserInFirebase() async {
    if (Get.isRegistered<FirebaseFirestoreController>()) {
      Get.find<FirebaseFirestoreController>().addUser(user);
    } else {
      Get.put(FirebaseFirestoreController()).addUser(user);
    }
  }
}

class PostUploadingProgress {
  final CameraScreenType type;
  final UploadType uploadType;
  final double progress;

  PostUploadingProgress({
    this.type = CameraScreenType.post,
    this.progress = 0,
    this.uploadType = UploadType.none,
  });
}

enum UploadType {
  none,
  finish,
  error,
  uploading;

  String title(CameraScreenType type) {
    switch (this) {
      case UploadType.none:
        return '';
      case UploadType.finish:
        return type == CameraScreenType.post
            ? LKey.postUploadSuccessfully.tr
            : LKey.storyUploadSuccess.tr;
      case UploadType.error:
        return LKey.uploadingFailed.tr;
      case UploadType.uploading:
        return type == CameraScreenType.post
            ? LKey.postIsBeginUploading.tr
            : LKey.storyIsBeginUploading.tr;
    }
  }
}
