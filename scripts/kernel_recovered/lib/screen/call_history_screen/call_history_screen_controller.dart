import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/screen/chat_screen/chat_screen.dart';
import 'package:shortzz/common/manager/logger.dart';

class CallHistoryScreenController extends BaseController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RxList<DocumentSnapshot> calls = <DocumentSnapshot>[].obs;
  @override
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchCallHistory();
  }

  void _fetchCallHistory() {
    final myId = SessionManager.instance.getUser()?.id;
    if (myId == null) return;

    // Firestore requires composite index for OR queries or multiple queries.
    // Simpler approach: Fetch two streams and merge, or just one if we restructure.
    // For now, let's fetch calls where I am involved.
    // Since 'OR' queries are limited in simple Firestore setup, we might need two listeners.
    // Listener 1: I am caller
    // Listener 2: I am receiver

    // Actually, let's just use a simple list merge for now.

    try {
      _db
          .collection('calls')
          .where('callerId', isEqualTo: myId)
          //.orderBy('createdAt', descending: true) // Temporarily removed to avoid index error
          .limit(20)
          .snapshots()
          .listen((event) {
        _mergeCalls(event.docs);
      });

      _db
          .collection('calls')
          .where('receiverId', isEqualTo: myId)
          //.orderBy('createdAt', descending: true) // Temporarily removed to avoid index error
          .limit(20)
          .snapshots()
          .listen((event) {
        _mergeCalls(event.docs);
      });
    } catch (e) {
      // If index is missing, Firestore might throw.
      // We should probably log it or show empty state.
      // For now, just print.
      Loggers.info("Firestore Error (likely missing index): $e");
      // Fallback: Try without ordering if index fails?
      // Or just let it fail until index is built.
    }
  }

  final RxSet<String> selectedCallIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

  void toggleSelectionMode() {
    isSelectionMode.value = !isSelectionMode.value;
    if (!isSelectionMode.value) {
      selectedCallIds.clear();
    }
  }

  void toggleSelection(String callId) {
    if (selectedCallIds.contains(callId)) {
      selectedCallIds.remove(callId);
    } else {
      selectedCallIds.add(callId);
    }

    // Auto-exit selection mode if empty
    if (selectedCallIds.isEmpty) {
      // Optional: toggleSelectionMode();
    }
  }

  void deleteSelected() async {
    if (selectedCallIds.isEmpty) return;

    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    try {
      final batch = _db.batch();
      for (var id in selectedCallIds) {
        // In a real app, we might just mark as deletedForMe
        // For now, hard delete or update status
        // Since it's a shared doc, we should probably not delete it fully if the other person needs it.
        // But for this task, I will just delete the doc reference locally or hide it?
        // Firestore doesn't support "delete for me" without a subcollection or array field.
        // Let's assume hard delete for now as per user request "delete karni ho".

        // Better approach: Add 'deletedBy' array
        batch.update(_db.collection('calls').doc(id), {
          'deletedBy':
              FieldValue.arrayUnion([SessionManager.instance.getUser()?.id])
        });
      }
      await batch.commit();

      // Update local list (The listener might not trigger for array updates if query doesn't match?
      // Actually it will trigger modification)

      selectedCallIds.clear();
      isSelectionMode.value = false;
      Get.back(); // Close loader
    } catch (e) {
      Get.back();
      Get.snackbar("Error", "Failed to delete calls");
    }
  }

  void _mergeCalls(List<DocumentSnapshot> newDocs) {
    // Simple merge logic
    final currentIds = calls.map((e) => e.id).toSet();
    final myId = SessionManager.instance.getUser()?.id;

    for (var doc in newDocs) {
      final data = doc.data() as Map<String, dynamic>;

      // Filter out deleted calls
      final deletedBy = List<int>.from(data['deletedBy'] ?? []);
      if (deletedBy.contains(myId)) {
        calls.removeWhere((e) => e.id == doc.id);
        continue;
      }

      if (!currentIds.contains(doc.id)) {
        calls.add(doc);
      } else {
        // Update existing
        final index = calls.indexWhere((e) => e.id == doc.id);
        if (index != -1) {
          calls[index] = doc;
        }
      }
    }
    // Sort
    calls.sort((a, b) {
      final t1 = (a.data() is Map<String, dynamic>)
          ? ((a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000))
          : DateTime(2000);
      final t2 = (b.data() is Map<String, dynamic>)
          ? ((b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000))
          : DateTime(2000);
      return t2.compareTo(t1);
    });
    isLoading.value = false;
  }

  Future<void> redialFromCall(DocumentSnapshot doc) async {
    final myId = SessionManager.instance.getUser()?.id;
    if (myId == null) return;
    final data = doc.data() as Map<String, dynamic>;

    final callerId = (data['callerId'] as num?)?.toInt();
    final receiverId = (data['receiverId'] as num?)?.toInt();
    final otherId =
        (callerId != null && callerId == myId) ? receiverId : callerId;
    if (otherId == null) return;

    final ids = [myId, otherId]..sort();
    final conversationId = '${ids[0]}_${ids[1]}';
    final isVideo = data['isVideo'] == true;

    final thread = ChatThread(
      userId: otherId,
      conversationId: conversationId,
      chatType: ChatType.approved,
      msgCount: 0,
      isDeleted: false,
      deletedId: 0,
      iBlocked: false,
      iAmBlocked: false,
    );

    final otherMap = (callerId != null && callerId == myId)
        ? data['receiver']
        : data['caller'];
    if (otherMap is Map) {
      thread.chatUser = AppUser.fromJson(Map<String, dynamic>.from(otherMap));
    }

    await Get.to(() => ChatScreen(
          conversationUser: thread,
          autoCallIsAudio: !isVideo,
        ));
  }

  Future<void> setReminderFromCall(DocumentSnapshot doc) async {
    final myId = SessionManager.instance.getUser()?.id;
    if (myId == null) return;
    final data = doc.data() as Map<String, dynamic>;

    final callerId = (data['callerId'] as num?)?.toInt();
    final receiverId = (data['receiverId'] as num?)?.toInt();
    final otherId =
        (callerId != null && callerId == myId) ? receiverId : callerId;
    if (otherId == null) return;

    final remindAt = DateTime.now().add(const Duration(minutes: 10));
    final reminderId = '${otherId}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _db
          .collection('users')
          .doc(myId.toString())
          .collection('call_reminders')
          .doc(reminderId)
          .set({
        'peerId': otherId,
        'callId': doc.id,
        'isVideo': data['isVideo'] == true,
        'createdAt': FieldValue.serverTimestamp(),
        'remindAt': Timestamp.fromDate(remindAt),
      });
      Get.snackbar('Reminder Set', 'We will remind you in 10 minutes',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to set reminder',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
