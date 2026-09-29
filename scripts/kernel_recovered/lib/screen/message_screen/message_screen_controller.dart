import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/utilities/firebase_const.dart';

class MessageScreenController extends BaseController {
  List<String> chatCategories = [LKey.chats.tr, LKey.requests.tr];
  RxInt selectedChatCategory = 0.obs;
  FirebaseFirestore db = FirebaseFirestore.instance;
  PageController pageController = PageController();
  User? myUser = SessionManager.instance.getUser();
  RxList<ChatThread> chatsUsers = <ChatThread>[].obs;
  RxList<ChatThread> requestsUsers = <ChatThread>[].obs;
  final dashboardController = Get.find<DashboardScreenController>();

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: selectedChatCategory.value);
    _listenToUserChatsAndRequests();
  }

  void onPageChanged(int index) {
    selectedChatCategory.value = index;
  }

  Future<void> _listenToUserChatsAndRequests() async {
    isLoading.value = true;
    db
        .collection(FirebaseConst.users)
        .doc(myUser?.id.toString())
        .collection(FirebaseConst.usersList)
        .withConverter(
        fromFirestore: (snapshot, options) => ChatThread.fromJson(snapshot.data()!),
        toFirestore: (ChatThread value, options) => value.toJson())
        .where(FirebaseConst.isDeleted, isEqualTo: false)
        .orderBy(FirebaseConst.id, descending: true)
        .snapshots()
        .listen((event) {
      isLoading.value = false;
      for (var change in event.docChanges) {
        final ChatThread? updatedUser = change.doc.data();
        if (updatedUser == null) continue;

        switch (change.type) {
          case DocumentChangeType.added:
            if (updatedUser.chatType == ChatType.approved) {
              chatsUsers.add(updatedUser);
            } else {
              requestsUsers.add(updatedUser);
            }
            break;
          case DocumentChangeType.modified:
          // Remove the user from their current list
            final userId = change.doc.data()?.chatUser?.userId;
            chatsUsers.removeWhere((user) => user.chatUser?.userId == userId);
            requestsUsers.removeWhere((user) => user.chatUser?.userId == userId);

            // Get the updated user data
            final updatedUser = change.doc.data();

            if (updatedUser != null) {
              // Add the updated user to the correct list
              (updatedUser.chatType == ChatType.approved
                  ? chatsUsers
                  : requestsUsers)
                  .add(updatedUser);
            }
          case DocumentChangeType.removed:
          // Remove the user from their current list
            final userId = change.doc.data()?.chatUser?.userId;
            chatsUsers.removeWhere((user) => user.chatUser?.userId == userId);
            requestsUsers.removeWhere((user) => user.chatUser?.userId == userId);
            break;
        }
      }

      chatsUsers.sort(
            (a, b) {
          return (b.id ?? '0').compareTo(a.id ?? '0');
        },
      );
      requestsUsers.sort(
            (a, b) {
          return (b.id ?? '0').compareTo(a.id ?? '0');
        },
      );

      // Loggers.success('CHAT USER: ${chatsUsers.length}');
      // Loggers.success('REQUEST USER: ${requestsUsers.length}');
    });
  }

  void onLongPress(ChatThread chatConversation) {
    Get.bottomSheet(ConfirmationSheet(
      title: LKey.deleteChatUserTitle
          .trParams({'user_name': chatConversation.chatUser?.username ?? ''}),
      description: LKey.deleteChatUserDescription.tr,
      onTap: () async {
        int time = DateTime.now().millisecondsSinceEpoch;
        showLoader();
        await db
            .collection(FirebaseConst.users)
            .doc(myUser?.id.toString())
            .collection(FirebaseConst.usersList)
            .doc(chatConversation.chatUser?.userId.toString())
            .update({
          FirebaseConst.deletedId: time,
          FirebaseConst.isDeleted: true,
        }).catchError((error) {
          Loggers.error('USER NOT DELETE : $error');
        });
        stopLoader();
      },
    ));
  }
}
