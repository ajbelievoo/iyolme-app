import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart'
    show SessionManager;
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:shortzz/languages/dynamic_translations.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/call_screen/call_screen.dart';
import 'package:shortzz/screen/chat_screen/chat_screen.dart';
import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/call_screen/incoming_call_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/live_stream_audience_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/livestream_host_screen.dart';
import 'package:shortzz/screen/post_screen/single_post_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/screen/scratch_collect/asset_vault_screen.dart';
import 'package:shortzz/screen/scratch_collect/scratch_collect_controller.dart';
import 'package:shortzz/utilities/const_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:shortzz/common/service/api/livekit_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  Loggers.info('NOTIFICATION TAP ON BACKGROUND');
  notificationResponse.data;
  if (notificationResponse.payload != null) {
    FirebaseNotificationManager.instance
        .handleNotification(notificationResponse.payload!);
  }
}

class FirebaseNotificationManager {
  FirebaseNotificationManager._() {
    init();
  }

  static final instance = FirebaseNotificationManager._();

  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  RxString notificationPayload = ''.obs;
  AndroidNotificationChannel channel = const AndroidNotificationChannel(
      'iyol', // id
      'IyolMe', // title
      playSound: true,
      enableLights: true,
      enableVibration: true,
      showBadge: false,
      importance: Importance.max);

  AndroidNotificationChannel callChannel = const AndroidNotificationChannel(
      'call_channel', 'Incoming Calls', // title
      playSound: true,
      sound: RawResourceAndroidNotificationSound('call_ring'),
      enableLights: true,
      enableVibration: true,
      showBadge: false,
      importance: Importance.max);

  String? notificationId;
  String? _pendingDeviceToken;
  final Set<String> _handledCallIds = <String>{};

  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: false);
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await plugin.initialize(initSettings,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground);

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    const callChannel = AndroidNotificationChannel(
      'call_channel',
      'Incoming Calls',
      playSound: true,
      sound: RawResourceAndroidNotificationSound('call_ring'),
      enableLights: true,
      enableVibration: true,
      showBadge: false,
      importance: Importance.max,
    );
    const defaultChannel = AndroidNotificationChannel(
      'iyol',
      'IyolMe',
      playSound: true,
      enableLights: true,
      enableVibration: true,
      showBadge: false,
      importance: Importance.max,
    );
    await android?.createNotificationChannel(defaultChannel);
    await android?.createNotificationChannel(callChannel);

    final type = message.data['type']?.toString();
    final callId = message.data['call_id']?.toString();
    String title =
        message.data['title']?.toString() ?? message.notification?.title ?? '';
    String body =
        message.data['body']?.toString() ?? message.notification?.body ?? '';
    final isCall = type == NotificationType.call.type ||
        (callId != null && callId.isNotEmpty);

    if (isCall && callId != null && callId.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .get();
        final data = snap.data();
        if (data != null) {
          final caller = data['caller'];
          if (caller is Map) {
            final m = Map<String, dynamic>.from(caller);
            final name = (m['fullname'] ?? m['username'] ?? m['identity'] ?? '')
                .toString()
                .trim();
            if (name.isNotEmpty) title = name;
          }
          final isVideo = data['isVideo'] == true;
          body = isVideo ? 'Incoming Video Call' : 'Incoming Audio Call';
        }
      } catch (_) {}
    }

    if (title.trim().isEmpty) {
      title = isCall ? 'Incoming Call' : 'Notification';
    }
    if (body.trim().isEmpty) {
      body = isCall ? 'Incoming Call' : '';
    }

    final details = NotificationDetails(
      iOS: const DarwinNotificationDetails(
          presentSound: true, presentAlert: true, presentBadge: false),
      android: AndroidNotificationDetails(
        isCall ? callChannel.id : defaultChannel.id,
        isCall ? callChannel.name : defaultChannel.name,
        importance: Importance.max,
        priority: isCall ? Priority.max : Priority.high,
        playSound: true,
        sound: isCall
            ? const RawResourceAndroidNotificationSound('call_ring')
            : null,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: isCall,
        category: isCall ? AndroidNotificationCategory.call : null,
        visibility: NotificationVisibility.public,
        timeoutAfter: isCall ? 30000 : null,
        ongoing: isCall,
        autoCancel: !isCall,
        largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      ),
    );

    final id = isCall
        ? 99999
        : DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await plugin.show(id, title, body, details,
        payload: jsonEncode(message.toMap()));
  }

  void init() async {
    try {
      await firebaseMessaging.setAutoInitEnabled(true);
      final enabled = firebaseMessaging.isAutoInitEnabled;
      Loggers.info('[FCM] autoInitEnabled=$enabled');
    } catch (e) {
      Loggers.error('[FCM] autoInit enable failed: $e');
    }

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      // Also request FCM permission on Android 13+
      await firebaseMessaging.requestPermission(
          alert: true, badge: false, sound: true);
    } else {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
      await firebaseMessaging.requestPermission(
          alert: true, badge: false, sound: true);
    }

    try {
      final settings = await firebaseMessaging.getNotificationSettings();
      Loggers.info(
          '[FCM] permissionStatus=${settings.authorizationStatus} alert=${settings.alert} sound=${settings.sound} badge=${settings.badge}');
    } catch (e) {
      Loggers.error('[FCM] getNotificationSettings failed: $e');
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      Loggers.info('DeviceToken $token');
      _pendingDeviceToken = token;
    } catch (e) {
      Loggers.error('DeviceToken Exception $e');
    }

    subscribeToTopic();

    // Ensure we always have latest token after reinstall / token rotation.
    await _syncDeviceTokenToBackend();
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      Loggers.info('DeviceToken refreshed: $token');
      await _syncDeviceTokenToBackend(tokenOverride: token);
    });

    var initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    var initializationSettingsIOS = const DarwinInitializationSettings(
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: false);

    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    // Handling notification taps
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      Loggers.info('onDidReceiveNotificationResponse ${response.payload}');
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        notificationPayload.value = payload;
        handleNotification(payload);
      }
    }, onDidReceiveBackgroundNotificationResponse: notificationTapBackground);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // If Notification has gone twice
      if (notificationId == message.messageId) return;
      notificationId = message.messageId;

      String data = message.data['notification_data'] ?? '';

      final type = message.data['type'];
      final body =
          (message.data['body'] as String?) ?? message.notification?.body ?? '';

      if (type == NotificationType.call.type ||
          body.contains('Incoming Audio Call') ||
          body.contains('Incoming Video Call')) {
        _handleIncomingCallPush(message);
        return;
      }

      if (type == NotificationType.chat.type) {
        ChatThread conversationUser = ChatThread.fromJson(jsonDecode(data));
        if (conversationUser.conversationId == ChatScreenController.chatId) {
          return;
        }
      } else {
        SessionManager.instance.setNotifyCount(1);
      }
      showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Loggers.info('User tapped the notification: ${message.data}');
      Loggers.info('FirebaseMessaging.onMessageOpenedApp');
      if (message.data.isNotEmpty) {
        handleNotification(jsonEncode(message.toMap()));
      }
    });

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);
  }

  Future<void> _syncDeviceTokenToBackend({String? tokenOverride}) async {
    try {
      final token = tokenOverride ??
          _pendingDeviceToken ??
          await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      if (!SessionManager.instance.isLogin()) {
        _pendingDeviceToken = token;
        Loggers.info(
            '[FCM_SYNC] skipped (not logged in yet). pendingTokenLen=${token.length}');
        return;
      }

      // Only update if token changed.
      final current = SessionManager.instance.getUser();
      if (current?.deviceToken == token) return;

      await UserService.instance.updateUserDetails(
        deviceToken: token,
        device: Platform.isAndroid ? 0 : 1,
      );
      Loggers.success('✅ Device token synced to backend');
    } catch (e) {
      Loggers.error('Device token sync failed: $e');
    }
  }

  Future<void> forceSyncTokenAfterLogin() async {
    await _syncDeviceTokenToBackend();
  }

  void unsubscribeToTopic({String? topic}) async {
    Loggers.success(
        '🔔 Topic UnSubscribe : ${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');
    await firebaseMessaging.unsubscribeFromTopic(
        '${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');
  }

  Future<void> subscribeToTopic({String? topic}) async {
    final t = topic ?? notificationTopic;
    final platformSuffix = Platform.isAndroid ? 'android' : 'ios';
    final suffixed = '${t}_$platformSuffix';

    Loggers.success('🔔 Topic Subscribe : $suffixed');
    await firebaseMessaging.subscribeToTopic(suffixed);

    // Fallback: some backends publish to the plain topic without suffix.
    Loggers.success('🔔 Topic Subscribe : $t');
    await firebaseMessaging.subscribeToTopic(t);
  }

  void showNotification(RemoteMessage message) {
    _showNotificationAsync(message);
  }

  Future<void> _showNotificationAsync(RemoteMessage message) async {
    Loggers.info('SHOW MESSAGE : ${message.toMap()}');
    int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final sound = message.notification?.android?.sound;
    String title =
        message.data['title']?.toString() ?? message.notification?.title ?? '';
    String body =
        message.data['body']?.toString() ?? message.notification?.body ?? '';

    final type = message.data['type']?.toString();
    final callId = message.data['call_id']?.toString();
    final isCall = type == NotificationType.call.type ||
        (callId != null && callId.isNotEmpty) ||
        sound == 'call_ring' ||
        body.contains('Call') ||
        title.contains('Call');

    if (isCall && callId != null && callId.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .get();
        final data = snap.data();
        if (data != null) {
          final caller = data['caller'];
          if (caller is Map) {
            final m = Map<String, dynamic>.from(caller);
            final name = (m['fullname'] ?? m['username'] ?? m['identity'] ?? '')
                .toString()
                .trim();
            if (name.isNotEmpty) title = name;
          }
          final isVideo = data['isVideo'] == true;
          body = isVideo ? 'Incoming Video Call' : 'Incoming Audio Call';
        }
      } catch (_) {}
    }

    if (isCall) {
      notificationId = 99999;
    }

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title.isNotEmpty ? title : (isCall ? 'Incoming Call' : 'Notification'),
      body.isNotEmpty ? body : (isCall ? 'Incoming Call' : ''),
      NotificationDetails(
        iOS: const DarwinNotificationDetails(
            presentSound: true, presentAlert: true, presentBadge: false),
        android: AndroidNotificationDetails(
          isCall ? callChannel.id : channel.id,
          isCall ? callChannel.name : channel.name,
          importance: Importance.max,
          priority: isCall ? Priority.max : Priority.high,
          playSound: true,
          sound: isCall
              ? const RawResourceAndroidNotificationSound('call_ring')
              : null,
          enableVibration: true,
          enableLights: true,
          fullScreenIntent: isCall,
          ongoing: isCall,
          autoCancel: !isCall,
          category: isCall ? AndroidNotificationCategory.call : null,
          visibility: NotificationVisibility.public,
          timeoutAfter: isCall ? 30000 : null,
          largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
        ),
      ),
      payload: jsonEncode(message.toMap()),
    );
  }

  Future<void> _handleIncomingCallPush(RemoteMessage message) async {
    final callId = message.data['call_id']?.toString();
    if (callId == null || callId.isEmpty) {
      DashboardScreenController.checkIncomingCalls();
      return;
    }

    if (_handledCallIds.contains(callId)) return;
    _handledCallIds.add(callId);

    await _openCallById(callId);
  }

  Future<void> _openCallById(String callId) async {
    if (DashboardScreenController.isCallActive) {
      final currentRoute = Get.currentRoute;
      final onCallRoute = currentRoute == '/IncomingCallScreen' ||
          currentRoute == '/CallScreen';
      if (!onCallRoute) {
        DashboardScreenController.isCallActive = false;
        DashboardScreenController.currentCallId = null;
      } else {
        try {
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .update({
            'status': 'busy',
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': 'receiver',
            'declineReason': 'Busy',
            'missedReason': 'busy',
          });
        } catch (_) {}
        if (Get.isSnackbarOpen != true) {
          Get.snackbar('Busy', 'You are already on a call',
              snackPosition: SnackPosition.BOTTOM);
        }
        return;
      }
    }
    if (Get.currentRoute == '/IncomingCallScreen') return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .get();
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;
      final status = data['status'];
      if (status == 'ringing') {
        Get.to(() => IncomingCallScreen(callData: data));
        return;
      }
      if (status == 'accepted') {
        final myUser = SessionManager.instance.getUser();
        if (myUser == null) return;
        final tokenResp = await LiveKitService.instance.generateToken(
          roomName: callId,
          userIdentity: '${myUser.id}',
          userName: myUser.username ?? 'User',
        );
        if (tokenResp == null) return;
        final callerMap = data['caller'];
        final callerUser =
            AppUser.fromJson(Map<String, dynamic>.from(callerMap));
        final stream = Livestream(
          hostId: callerUser.userId,
          roomID: callId,
          type: LivestreamType.livestream,
        )..hostUser = callerUser;
        Get.to(() => CallScreen(
              livestream: stream,
              url: tokenResp.livekitUrl,
              token: tokenResp.token,
              isAudio: !(data['isVideo'] == true),
            ));
      }
    } catch (e) {
      Loggers.error('[CALL_PUSH] open incoming failed: $e');
    }
  }

  Future<void> handleNotification(String payload) async {
    final RemoteMessage message = RemoteMessage.fromMap(jsonDecode(payload));
    final dataType = message.data['type'];
    final dataString = message.data['notification_data'];
    final body = message.data['body'] ?? message.notification?.body ?? '';
    final title = message.data['title'] ?? message.notification?.title ?? '';

    Loggers.info('DATA TYPE : $dataType');
    Loggers.info('DATA STRING : $dataString');

    // Admin-granted scratch card push: open the vault directly.
    // Backend sends data: {type:"scratch_pending_card", card_id:"<id>"}
    // with no notification_data payload, so handle before the early return.
    if (dataType == 'scratch_pending_card') {
      // Small delay so the dashboard is up if the app was launched cold.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (Get.isRegistered<ScratchCollectController>()) {
          Get.find<ScratchCollectController>().fetchPendingCards();
        }
        AssetVaultScreen.open();
      });
      return;
    }

    if (dataType == null || dataString == null || dataString.isEmpty) return;

    // Put Dashboard Controller if not present
    final controller = Get.put(DashboardScreenController());

    if (dataType == NotificationType.call.type) {
      try {
        final raw = dataString;
        if (raw == null || raw.isEmpty) return;
        final map = jsonDecode(raw);
        final callId = map['call_id']?.toString();
        if (callId == null || callId.isEmpty) return;
        await _openCallById(callId);
        return;
      } catch (e) {
        Loggers.error('Error handling call notification: $e');
      }
    }

    // Check if it's a Call Invite
    if (dataType == 'chat' &&
        (body.contains('Incoming') ||
            body.contains('Call') ||
            title.contains('Call'))) {
      try {
        // Wait a moment for app to be ready if launched from dead state
        await Future.delayed(const Duration(milliseconds: 500));
        DashboardScreenController.checkIncomingCalls();
        return;
      } catch (e) {
        Loggers.error('Error parsing call notification: $e');
      }
    }

    switch (dataType) {
      case 'chat':
        Future.delayed(const Duration(milliseconds: 500), () async {
          controller.selectedPageIndex.value = 4;
          await _handleChatNotification(dataString);
        });

        break;
      case 'post':
        await _handlePostNotification(dataString, controller);
        break;
      case 'user':
        controller.selectedPageIndex.value = 5;
        await _handleUserNotification(dataString);
        break;
      case 'live_stream':
        controller.selectedPageIndex.value = 2;
        await _handleLivestreamNotification(dataString);
        break;
      default:
        Loggers.warning('Unknown notification type: $dataType');
    }
  }

  Future<void> _handleChatNotification(String data) async {
    try {
      final conversationUser = ChatThread.fromJson(jsonDecode(data));
      Loggers.info('Navigating to chat: ${conversationUser.toJson()}');
      await Get.to(() => ChatScreen(conversationUser: conversationUser));
    } catch (e) {
      Loggers.error('Failed to handle chat notification: $e');
    }
  }

  Future<void> _handlePostNotification(
      String data, DashboardScreenController controller) async {
    try {
      NotificationInfo notificationInfo =
          NotificationInfo.fromJson(jsonDecode(data));
      final int postId = notificationInfo.id ?? -1;
      final int? commentId = notificationInfo.commentId;
      final int? replyId = notificationInfo.replyCommentId;
      final result = await PostService.instance.fetchPostById(
          postId: postId, commentId: commentId, replyId: replyId);

      if (result.status == true && result.data != null) {
        final Post? post = result.data?.post;
        if (post == null) return;

        if (post.postType == PostType.reel) {
          controller.selectedPageIndex.value = 5;
          ReelsScreenController.prewarm(
            reels: [post].obs,
            position: 0,
            isHomePage: false,
          ).then((tag) {
            Get.to(() => ReelsScreen(
                reels: [post].obs,
                position: 0,
                postByIdData: result.data,
                controllerTag: tag));
          });
        } else if ([PostType.text, PostType.image, PostType.video]
            .contains(post.postType)) {
          controller.selectedPageIndex.value = 1;
          await Get.to(() => SinglePostScreen(
              post: post, postByIdData: result.data, isFromNotification: true));
        }
      }
    } catch (e) {
      Loggers.error('Failed to handle post notification: $e');
    }
  }

  Future<void> _handleUserNotification(String data) async {
    try {
      final map = jsonDecode(data);
      final int id = map['id'];
      final user = await UserService.instance.fetchUserDetails(userId: id);

      if (user != null) {
        Loggers.success('Navigating to user: ${user.id}');
        NavigationService.shared.openProfileScreen(user);
      }
    } catch (e) {
      Loggers.error('Failed to handle user notification: $e');
    }
  }

  Future<String?> getNotificationToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      Loggers.info('DeviceToken $token');
      return token;
    } catch (e) {
      Loggers.error('DeviceToken Exception $e');
      return null;
    }
  }

  Future<void> sendLocalisationNotification(
    String key, {
    Map<String, String> keyParams = const {},
    String? deviceToken = '',
    int? deviceType = 0,
    String? languageCode = 'en',
    required NotificationInfo body,
    required NotificationType type,
  }) async {
    final normalizedToken = (deviceToken ?? '').trim();
    final normalizedDeviceType = deviceType ?? 0;

    // Early return if no device token provided
    if (normalizedToken.isEmpty) {
      Loggers.error(
          '[NOTIFY_SKIP] reason=empty_token key=$key deviceType=$normalizedDeviceType');
      return;
    }

    // Get user data once
    final user = SessionManager.instance.getUser();
    final title = user?.fullname ?? '';

    // Get translations efficiently
    final translations = Get.find<DynamicTranslations>();
    final languageData = translations.keys[languageCode] ?? {};

    // Get description with fallback
    var description = languageData[key] ?? key;

    keyParams.forEach((key, value) {
      description = description.replaceAll('@$key', value);
    });

    final tokenPrefix = normalizedToken.length <= 12
        ? normalizedToken
        : normalizedToken.substring(0, 12);

    // Log relevant information
    Loggers.info('''
      [Notification Details]
      Language: $languageCode
      Key: $key
      Description: $description
      Recipient: ${user?.id ?? 'Unknown'}
      Device Type: $normalizedDeviceType
      Device Token: $tokenPrefix...
    ''');

    // Send notification
    await NotificationService.instance.pushNotification(
        title: title,
        body: description,
        data: body.toJson(),
        deviceType: normalizedDeviceType,
        token: normalizedToken,
        type: type);
  }

  Future<void> _handleLivestreamNotification(String dataString) async {
    final incomingStream = Livestream.fromJson(jsonDecode(dataString));

    // If controller not registered, fetch from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection(FirebaseConst.liveStreams)
        .withConverter<Livestream>(
          fromFirestore: (snapshot, _) => Livestream.fromJson(snapshot.data()!),
          toFirestore: (livestream, _) => livestream.toJson(),
        )
        .get();

    final matchedDoc = snapshot.docs
        .firstWhereOrNull((doc) => doc.data().roomID == incomingStream.roomID);

    if (matchedDoc == null) {
      BaseController.share.showSnackBar(LKey.livestreamHasEnded.tr);
      return;
    }

    final stream = matchedDoc.data();
    final myUser = SessionManager.instance.getUser();

    if (stream.hostId == myUser?.id) {
      Get.to(() => LivestreamHostScreen(isHost: true, livestream: stream));
    } else {
      Get.to(() => LiveStreamAudienceScreen(isHost: false, livestream: stream));
    }
  }
}

enum NotificationType {
  chat('chat'),
  call('call'),
  post('post'),
  user('user'),
  liveStream('live_stream'),
  other('other');

  final String type;

  const NotificationType(this.type);
}

class NotificationInfo {
  int? id;
  int? commentId;
  int? replyCommentId;

  NotificationInfo({
    this.id,
    this.commentId,
    this.replyCommentId,
  });

  factory NotificationInfo.fromJson(Map<String, dynamic> json) =>
      NotificationInfo(
        id: json["id"],
        commentId: json["comment_id"],
        replyCommentId: json["reply_comment_id"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "comment_id": commentId,
        "reply_comment_id": replyCommentId,
      };
}
