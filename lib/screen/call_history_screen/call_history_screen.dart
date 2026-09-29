import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/screen/call_history_screen/call_history_screen_controller.dart';
import 'package:intl/intl.dart';
import 'package:shortzz/languages/languages_keys.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CallHistoryScreenController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Obx(() => Text(
              controller.isSelectionMode.value
                  ? '${controller.selectedCallIds.length} Selected'
                  : 'Calls',
              style: TextStyleCustom.outFitBold700(
                  fontSize: 22, color: Colors.black),
            )),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() => controller.isSelectionMode.value
              ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: controller.deleteSelected,
                )
              : const SizedBox.shrink())
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.calls.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.calls.isEmpty) {
          return Center(
            child: Text(
              'No recent calls',
              style: TextStyleCustom.outFitRegular400(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: controller.calls.length,
          itemBuilder: (context, index) {
            final doc = controller.calls[index];
            final data = doc.data() as Map<String, dynamic>;
            final myId = SessionManager.instance.getUser()?.id;

            final isCaller = (data['callerId'] as num?)?.toInt() == myId;
            final otherUser = isCaller ? data['receiver'] : data['caller'];

            // Safe parsing
            final name =
                otherUser['fullname'] ?? otherUser['username'] ?? 'Unknown';
            final profile = otherUser['profile'] ?? otherUser['image'];
            final rawStatus = data['status'] ?? 'ended';
            final acceptedAt = data['acceptedAt'];
            final status = (rawStatus == 'missed' && acceptedAt != null)
                ? 'ended'
                : rawStatus;
            final createdAt =
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final isVideo = data['isVideo'] == true;
            final duration = (data['duration'] as num?)?.toInt() ?? 0;
            final declineReason = data['declineReason']?.toString();
            final missedReason = data['missedReason']?.toString();
            final isPaid = data['isPaid'] == true;
            final paidTotal = (data['paidTotalCost'] as num?)?.toInt();

            // Icon Logic
            IconData statusIcon;
            Color statusColor;

            if (status == 'missed') {
              statusIcon =
                  isCaller ? Icons.call_missed_outgoing : Icons.call_missed;
              statusColor = Colors.red;
            } else if (status == 'declined') {
              statusIcon = Icons.call_end;
              statusColor = Colors.grey;
            } else if (status == 'ended') {
              statusIcon = Icons.call;
              statusColor = Colors.green;
            } else {
              statusIcon = isCaller ? Icons.call_made : Icons.call_received;
              statusColor = Colors.green;
            }

            return ListTile(
              onLongPress: () {
                controller.toggleSelectionMode();
                controller.toggleSelection(doc.id);
              },
              leading: Stack(
                children: [
                  CustomImage(
                    size: const Size(50, 50),
                    image: (profile as String?)?.addBaseURL(),
                    radius: 25,
                    fit: BoxFit.cover,
                  ),
                  if (controller.isSelectionMode.value)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                            color: controller.selectedCallIds.contains(doc.id)
                                ? Colors.blue.withValues(alpha: 0.5)
                                : Colors.transparent,
                            shape: BoxShape.circle),
                        child: controller.selectedCallIds.contains(doc.id)
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    )
                ],
              ),
              title: Text(
                name,
                style: TextStyleCustom.outFitBold700(fontSize: 16),
              ),
              subtitle: Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${status == 'ended' ? 'Call Ended' : (status == 'missed' ? 'Missed' : (status == 'declined' ? 'Declined' : status))}'
                      '${status == 'missed' && missedReason != null && missedReason.isNotEmpty ? ' (${missedReason.toUpperCase()})' : ''}'
                      '${status == 'declined' && declineReason != null && declineReason.isNotEmpty ? ' ($declineReason)' : ''}'
                      '${status == 'ended' && duration > 0 ? ' • ${duration ~/ 60}m ${duration % 60}s' : ''}'
                      '${isPaid && paidTotal != null ? ' • ${LKey.paidCallTotal.trParams({
                              'amount': paidTotal.toString()
                            })}' : ''}'
                      ' • ${DateFormat('MMM d, h:mm a').format(createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyleCustom.outFitRegular400(
                          color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
              trailing: controller.isSelectionMode.value
                  ? Checkbox(
                      value: controller.selectedCallIds.contains(doc.id),
                      onChanged: (val) => controller.toggleSelection(doc.id),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.alarm_add, color: Colors.teal),
                          onPressed: () => controller.setReminderFromCall(doc),
                        ),
                        IconButton(
                          icon: Icon(
                            isVideo ? Icons.videocam : Icons.call,
                            color: Colors.teal,
                          ),
                          onPressed: () => controller.redialFromCall(doc),
                        ),
                      ],
                    ),
              onTap: () {
                if (controller.isSelectionMode.value) {
                  controller.toggleSelection(doc.id);
                } else {
                  // Open Profile
                  if (otherUser['userId'] != null || otherUser['id'] != null) {
                    // Navigate to Profile
                    // Get.to(() => ProfileScreen(userId: otherUser['userId'] ?? otherUser['id']));
                    // Since we don't have ProfileScreen import readily available or known path without check
                    // We can just show a snackbar for now or try to use a common route if exists.
                    // Assuming standard route:
                    // Get.toNamed(AppRes.profile, arguments: otherUser['userId']);
                  }
                }
              },
            );
          },
        );
      }),
    );
  }
}
