import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/livekit_service.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/call_screen/call_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/model/chat/message_data.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:shortzz/languages/languages_keys.dart';

import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;

  const IncomingCallScreen({super.key, required this.callData});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _ringPlayer = AudioPlayer();
  bool _isProcessing = false;
  bool _accepted = false;
  bool _closing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  Timer? _autoDeclineTimer;
  StreamSubscription<DocumentSnapshot>? _callStatusSub;

  @override
  void initState() {
    super.initState();
    // Force active on start
    DashboardScreenController.isCallActive = true;
    DashboardScreenController.currentCallId = widget.callData['callId'];

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _playRingtone();
    _listenToCallStatus();
    _startAutoDeclineTimer();
  }

  void _startAutoDeclineTimer() {
    _autoDeclineTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isProcessing) {
        _declineCall(reason: 'Timeout (No Answer)');
      }
    });
  }

  @override
  void dispose() {
    _autoDeclineTimer?.cancel();
    _callStatusSub?.cancel();

    // Always clear isCallActive when this screen dies, UNLESS we are transitioning to CallScreen.
    // Since Get.off replaces the route, checking Get.currentRoute might be tricky here.
    // But we know if we accepted, _isProcessing is true.

    if (!_accepted) {
      DashboardScreenController.isCallActive = false;
      DashboardScreenController.currentCallId = null;
    }
    // Note: If we accepted (_isProcessing=true), CallScreen will take over and set isCallActive=true again.

    _animationController.dispose();
    _ringPlayer.dispose();
    super.dispose();
  }

  void _listenToCallStatus() {
    final callId = widget.callData['callId']?.toString();
    if (callId == null || callId.isEmpty) return;

    _callStatusSub?.cancel();
    _callStatusSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      final status = data?['status'];
      if (status == null) return;

      final isGroup = data?['isGroup'] == true;
      final myId = SessionManager.instance.getUser()?.id;
      final inviteStatus =
          (isGroup && myId != null) ? (data?['inviteStatus'] as Map?) : null;
      final myInvite = (inviteStatus != null) ? inviteStatus['$myId'] : null;

      if (isGroup && myInvite == 'ringing') {
        return;
      }

      if (status != 'ringing') {
        if (_closing) return;
        _closing = true;
        await _ringPlayer.stop();
        if (!_accepted) {
          DashboardScreenController.isCallActive = false;
          DashboardScreenController.currentCallId = null;
        }
        if (mounted && !_isProcessing) {
          Get.back();
        }
      }
    }, onError: (e) {
      Loggers.error('[IncomingCall] call status listen error: $e');
    });
  }

  void _playRingtone() async {
    try {
      await _ringPlayer.setAsset(AssetRes.receivingRing);
      await _ringPlayer.setLoopMode(LoopMode.one);

      // Configure audio source for Android to ensure proper playback
      if (GetPlatform.isAndroid) {
        // Using just_audio's setVolume(1.0) is usually enough,
        // but ensuring the file is loaded correctly is key.
        // Also, we want it to play on SPEAKER (loud) for ringtone.
        // By default, just_audio plays on music stream.
        // IncomingCallScreen should definitely be on speaker.
        await _ringPlayer.setVolume(1.0);
      }

      _ringPlayer.play();
    } catch (e) {
      Loggers.error('[IncomingCall] Ringtone failed: $e');
    }
  }

  void _acceptCall() async {
    if (_isProcessing) return;
    // Stop ringtone IMMEDIATELY before anything else
    await _ringPlayer.stop();

    _accepted = true;
    setState(() => _isProcessing = true);

    try {
      final callId = widget.callData['callId'];
      // IMPORTANT: Use the exact room name from callData.
      // This MUST match what the caller used.
      final roomName =
          widget.callData['channelId'] ?? widget.callData['callId'];
      final isVideo = widget.callData['isVideo'] ?? false;
      final myUser = SessionManager.instance.getUser();
      final myId = myUser?.id;
      final isGroup = widget.callData['isGroup'] == true;

      // 1. Update status to 'accepted' - THIS TRIGGERS THE CALLER TO JOIN
      final Map<String, dynamic> update = {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      };
      if (isGroup && myId != null) {
        update['inviteStatus.$myId'] = 'accepted';
        update['acceptedAtMap.$myId'] = FieldValue.serverTimestamp();
      }
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .update(update);

      // 2. Generate Token
      final tokenResp = await LiveKitService.instance.generateToken(
        roomName: roomName,
        userIdentity: '${myUser?.id}',
        userName: myUser?.username ?? 'User',
      );

      if (tokenResp != null) {
        // 3. Prepare Livestream object
        final callerMap = widget.callData['caller'];
        final callerUser = AppUser.fromJson(callerMap);

        Livestream stream = Livestream(
          hostId: callerUser.userId,
          roomID: roomName,
          type: LivestreamType.livestream,
        );
        stream.hostUser = callerUser;

        // 4. Navigate to CallScreen (replacing this screen)
        // Pass the token so CallScreen knows to connect immediately
        Get.off(() => CallScreen(
              livestream: stream,
              url: tokenResp.livekitUrl,
              token: tokenResp.token,
              isAudio: !isVideo,
            ));
      } else {
        Get.back();
        Get.snackbar('Error', 'Failed to connect');
      }
    } catch (e) {
      Loggers.error('[IncomingCall] Accept failed: $e');
      if (mounted) Get.back();
    }
  }

  void _showDeclineOptions() {
    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Response',
              style: TextStyleCustom.outFitBold700(fontSize: 18),
            ),
            const SizedBox(height: 15),
            _buildQuickResponseOption("Can't talk now, call me later?"),
            _buildQuickResponseOption("I'm busy right now."),
            _buildQuickResponseOption("I'll call you back."),
            _buildQuickResponseOption("Just Decline", isDestructive: true),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Widget _buildQuickResponseOption(String text, {bool isDestructive = false}) {
    return InkWell(
      onTap: () {
        Get.back(); // Close bottom sheet
        _declineCall(reason: isDestructive ? null : text);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Text(
          text,
          style: TextStyleCustom.outFitRegular400(
            fontSize: 16,
            color: isDestructive ? Colors.red : Colors.black,
          ),
        ),
      ),
    );
  }

  void _declineCall({String? reason}) async {
    if (_isProcessing) return;
    // Don't set _isProcessing = true here immediately if we want to allow other flows,
    // but for decline it's final.
    setState(() => _isProcessing = true);
    _ringPlayer.stop();

    DashboardScreenController.isCallActive = false;
    DashboardScreenController.currentCallId = null;

    try {
      final callId = widget.callData['callId'];
      final isGroup = widget.callData['isGroup'] == true;
      final myId = SessionManager.instance.getUser()?.id;

      // If it's a timeout, we might want to mark it as 'missed' or 'declined'?
      // Usually 'missed' is better for history.
      String status = 'declined';
      if (reason == 'Timeout (No Answer)') {
        status = 'missed';
      }

      if (isGroup && myId != null) {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'inviteStatus.$myId': status,
          'declineReasonMap.$myId': reason,
          'missedReasonMap.$myId':
              status == 'declined' ? 'rejected' : 'offline',
        });
      } else {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'status': status,
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': 'receiver',
          'declineReason': reason,
          'missedReason': status == 'declined' ? 'rejected' : 'offline',
        });
      }

      if (reason != null &&
          reason.isNotEmpty &&
          reason != 'Timeout (No Answer)') {
        await _sendQuickReplyToCaller(reason);
      }
    } catch (e) {
      Loggers.error('[IncomingCall] Decline failed: $e');
    }
    if (mounted) Get.back();
  }

  Future<void> _sendQuickReplyToCaller(String text) async {
    try {
      final myId = SessionManager.instance.getUser()?.id;
      if (myId == null) return;

      final callData = widget.callData;
      final callerId = (callData['callerId'] as num?)?.toInt() ??
          ((callData['caller'] is Map)
              ? AppUser.fromJson(Map<String, dynamic>.from(callData['caller']))
                  .userId
              : null);
      final receiverId = (callData['receiverId'] as num?)?.toInt() ?? myId;
      if (callerId == null) return;

      final ids = [callerId, receiverId]..sort();
      final conversationId = '${ids[0]}_${ids[1]}';

      final time = DateTime.now().millisecondsSinceEpoch;
      final msgId = time.toString();

      final message = MessageData(
        userId: receiverId,
        conversationId: conversationId,
        textMessage: text,
        iAmBlocked: false,
        iBlocked: false,
        messageType: MessageType.text,
        id: time,
        noDeleteIds: [callerId, receiverId],
      );

      final db = FirebaseFirestore.instance;
      final msgRef = db
          .collection(FirebaseConst.chats)
          .doc(conversationId)
          .collection(FirebaseConst.messages)
          .doc(msgId);

      final senderThreadRef = db
          .collection(FirebaseConst.users)
          .doc(receiverId.toString())
          .collection(FirebaseConst.usersList)
          .doc(callerId.toString());

      final receiverThreadRef = db
          .collection(FirebaseConst.users)
          .doc(callerId.toString())
          .collection(FirebaseConst.usersList)
          .doc(receiverId.toString());

      final batch = db.batch();
      batch.set(msgRef, message.toJson());
      batch.set(
        senderThreadRef,
        {
          FirebaseConst.id: msgId,
          'conversation_id': conversationId,
          'user_id': callerId,
          FirebaseConst.lastMsg: text,
          FirebaseConst.lastMsgType: MessageType.text.value,
          FirebaseConst.msgCount: 0,
          FirebaseConst.isDeleted: false,
        },
        SetOptions(merge: true),
      );
      batch.set(
        receiverThreadRef,
        {
          FirebaseConst.id: msgId,
          'conversation_id': conversationId,
          'user_id': receiverId,
          FirebaseConst.lastMsg: text,
          FirebaseConst.lastMsgType: MessageType.text.value,
          FirebaseConst.msgCount: FieldValue.increment(1),
          FirebaseConst.isDeleted: false,
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      Loggers.error('[IncomingCall] quick reply send failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final callerMap = widget.callData['caller'] ?? {};
    final name = callerMap['fullname'] ?? callerMap['username'] ?? 'Unknown';
    final profile = callerMap['profile'];
    final isVideo = widget.callData['isVideo'] ?? false;
    final isPaid = widget.callData['isPaid'] == true;
    final costPerMinute = (widget.callData['costPerMinute'] as num?)?.toInt();
    final netPerMinute = (widget.callData['netPerMinute'] as num?)?.toInt();
    final commissionPercent =
        (widget.callData['commissionPercent'] as num?)?.toDouble();
    final computedNet = (costPerMinute != null && commissionPercent != null)
        ? ((costPerMinute * (100.0 - commissionPercent)) / 100.0).floor()
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with Blur
          if (profile != null)
            CustomImage(
              size: const Size(double.infinity, double.infinity),
              image: (profile as String).addBaseURL(),
              fit: BoxFit.cover,
            ),
          Container(
            color: Colors.black.withValues(alpha: 0.8),
          ),

          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              CustomImage(
                size: const Size(120, 120),
                image: (profile as String?)?.addBaseURL(),
                fit: BoxFit.cover,
                radius: 60,
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: TextStyleCustom.outFitBold700(
                    color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 10),
              Text(
                'Incoming ${isVideo ? 'Video' : 'Audio'} Call...',
                style: TextStyleCustom.outFitRegular400(
                    color: Colors.white70, fontSize: 16),
              ),
              if (isPaid &&
                  (netPerMinute ?? computedNet ?? costPerMinute) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    LKey.paidCallEarningRate.trParams({
                      'rate': (netPerMinute ?? computedNet ?? costPerMinute)
                          .toString()
                    }),
                    style: TextStyleCustom.outFitRegular400(
                        color: Colors.white70, fontSize: 14),
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Button
                  Column(
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: InkWell(
                          onTap: _showDeclineOptions,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end,
                                color: Colors.white, size: 35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Decline',
                          style: TextStyleCustom.outFitRegular400(
                              color: Colors.white, fontSize: 14)),
                    ],
                  ),

                  // Accept Button
                  Column(
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: InkWell(
                          onTap: _acceptCall,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call,
                                color: Colors.white, size: 35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Accept',
                          style: TextStyleCustom.outFitRegular400(
                              color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ],
      ),
    );
  }
}
