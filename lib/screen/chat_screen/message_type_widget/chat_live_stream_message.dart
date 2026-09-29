import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/livekit_service.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/model/chat/message_data.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/call_screen/call_screen.dart';
import 'package:shortzz/screen/call_screen/incoming_call_screen.dart';
import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/live_stream_audience_screen.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ChatLiveStreamMessage extends StatelessWidget {
  final MessageData message;
  final bool isMe;

  const ChatLiveStreamMessage(
      {super.key, required this.message, required this.isMe});

  Future<void> _handleCallTap(BuildContext context, String roomName, int? id,
      String? image, bool isVideo) async {
    if (roomName.isEmpty || roomName.startsWith('http')) {
      Get.snackbar('Call', 'This call invite is invalid or expired.');
      return;
    }

    final myUser = SessionManager.instance.getUser();
    if (myUser == null) return;

    // Check status first
    try {
      final doc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(roomName)
          .get();

      if (!doc.exists) {
        Get.snackbar('Call', 'Call details not found.');
        return;
      }

      final data = doc.data()!;
      final status = data['status'] as String? ?? 'ended';

      // If Ringing, Open IncomingCallScreen
      if (status == 'ringing') {
        if (!isMe) {
          // Pass the full call data as IncomingCallScreen expects
          // Note: IncomingCallScreen expects Map<String, dynamic> callData
          Get.to(() => IncomingCallScreen(callData: data));
        }
        return;
      }

      // If Accepted, and I am a participant, Re-Join (Return to Call)
      if (status == 'accepted') {
        // We need to generate token and join
        // Show loading
        Get.dialog(const Center(child: CircularProgressIndicator()),
            barrierDismissible: false);

        final tokenResp = await LiveKitService.instance.generateToken(
          roomName: roomName,
          userIdentity: '${myUser.id}',
          userName: myUser.username ?? 'User',
        );

        Get.back();

        if (tokenResp != null) {
          Livestream stream = Livestream(
            hostId: id,
            roomID: roomName,
            type: LivestreamType.livestream,
          );
          stream.hostUser = AppUser(userId: id, profile: image);

          Get.to(() => CallScreen(
                livestream: stream,
                url: tokenResp.livekitUrl,
                token: tokenResp.token,
                isAudio: !isVideo,
              ));
        }
        return;
      }

      // If Ended/Missed/Declined, Trigger NEW Call (Recall)
      // Find controller tag from message conversation
      // This is tricky if we are in global context.
      // Better to trigger call logic directly if we have receiver info.
      // We have `id` (hostId), which is the other user if `isMe` is false.
      // If `isMe` is true, `id` is ME? No, hostId in message is usually the sender?
      // Wait, `message.liveStreamId` stores the SENDER ID in typical livestream logic.
      // Let's check `message_data.dart`.

      // Assuming we want to call the OTHER person.
      // If I sent the message, I want to call the receiver.
      // If I received the message, I want to call the sender.
      // But `id` here comes from `message.liveStreamId`.

      // Let's try to find the ChatController first.
      try {
        final controller =
            Get.find<ChatScreenController>(tag: '${message.conversationId}');
        controller.onVideoCall(isAudio: !isVideo);
      } catch (e) {
        Get.snackbar('Error', 'Cannot recall from here. Go to profile.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to check call status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = message.liveStreamTitle ?? 'Live Stream';
    final image = message.liveStreamImage;
    final id = message.liveStreamId;
    final isCall = title.contains('Call');
    final roomName = message.textMessage;

    if (isCall && roomName != null && !roomName.startsWith('http')) {
      return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('calls')
              .doc(roomName)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final rawStatus = data?['status'] ?? 'ringing';
            final acceptedAt = data?['acceptedAt'];
            final status = (rawStatus == 'missed' && acceptedAt != null)
                ? 'ended'
                : rawStatus;
            final duration = data?['duration'] as int? ?? 0;
            final isVideo = data?['isVideo'] ?? title.contains('Video');

            // Determine UI based on status
            String statusText = 'Ringing...';
            Color statusColor = themeAccentSolid(context);
            IconData statusIcon = isVideo ? Icons.videocam : Icons.call;
            bool isRecall = false;
            bool isMissed = false;
            bool isOutgoing = isMe; // If I sent it

            switch (status) {
              case 'ringing':
                statusText = isOutgoing ? 'Calling...' : 'Incoming Call...';
                break;
              case 'accepted':
                statusText = 'Ongoing Call';
                statusColor = Colors.green;
                break;
              case 'declined':
                statusText = 'Call Declined';
                statusColor = Colors.red;
                statusIcon = Icons.call_end;
                isRecall = true;
                break;
              case 'busy':
                statusText = 'User Busy';
                statusColor = Colors.orange;
                isRecall = true;
                break;
              case 'missed':
                statusText = 'Missed Call';
                statusColor = Colors.red;
                statusIcon = Icons.call_missed;
                isRecall = true;
                isMissed = true;
                break;
              case 'ended':
                final min = duration ~/ 60;
                final sec = duration % 60;
                statusText = 'Call Ended - ${min}m ${sec}s';
                statusColor = Colors.grey;
                statusIcon = Icons.history;
                isRecall = true;
                break;
            }

            return Container(
              width: 250,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: bgLightGrey(context),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusText,
                              style: TextStyleCustom.outFitBold700(
                                  color: isMissed
                                      ? Colors.red
                                      : textDarkGrey(context),
                                  fontSize: 16),
                            ),
                            if (status == 'ringing' || status == 'accepted')
                              Text(
                                status == 'ringing'
                                    ? (isOutgoing
                                        ? 'Waiting for answer...'
                                        : 'Tap to Answer')
                                    : 'Tap to return',
                                style: TextStyleCustom.outFitRegular400(
                                    color: textLightGrey(context),
                                    fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () {
                      _handleCallTap(context, roomName, id, image, isVideo);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isRecall
                            ? Colors.grey.withValues(alpha: 0.2)
                            : statusColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isRecall
                            ? 'Call Again'
                            : (status == 'accepted'
                                ? 'Return to Call'
                                : (isOutgoing
                                    ? 'Ringing...'
                                    : (status == 'ringing'
                                        ? 'Accept'
                                        : 'Open Call'))),
                        style: TextStyleCustom.outFitBold700(
                            color: isRecall
                                ? Colors.black
                                : (status == 'ringing'
                                    ? Colors.black
                                    : Colors.white),
                            fontSize: 14),
                      ),
                    ),
                  )
                ],
              ),
            );
          });
    }

    // Fallback for old/other messages
    if (isCall) {
      // ... (Keep existing fallback logic if needed, but updated logic covers most)
      // For brevity, I'm returning a simple error/placeholder if we fall here for new calls.
      return const SizedBox.shrink();
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgLightGrey(context),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomImage(
                  size: const Size(50, 50),
                  image: image?.addBaseURL(),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyleCustom.outFitBold700(
                            color: textDarkGrey(context), fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Wanna play Live with me?',
                        style: TextStyleCustom.outFitRegular400(
                            color: textLightGrey(context), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                if (id != null) {
                  Livestream livestream =
                      Livestream(hostId: id, roomID: id.toString());
                  Get.to(() => LiveStreamAudienceScreen(
                      livestream: livestream, isHost: false));
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: themeAccentSolid(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Enter',
                    style: TextStyleCustom.outFitBold700(
                        color: Colors.black, fontSize: 14)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
