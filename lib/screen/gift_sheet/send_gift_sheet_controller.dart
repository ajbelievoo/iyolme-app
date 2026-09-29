import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/economy_state.dart';
import 'package:shortzz/common/service/api/gift_wallet_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_dialog.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';

class SendGiftSheetController extends BaseController {
  Rx<Setting?> settings = Rx<Setting?>(null);
  Rx<User?> myUser = Rx<User?>(null);
  int? userId;
  List<AppUser> liveUsers;
  GiftType? giftType;
  late LivestreamScreenController livestreamController;
  final RxSet<int> selectedGiftUserIds = <int>{}.obs;
  final RxBool _isSendingGift = false.obs;

  SendGiftSheetController(this.giftType, this.userId, this.liveUsers);

  @override
  void onInit() {
    super.onInit();
    _initData();

    if (liveUsers.isNotEmpty &&
        (giftType == GiftType.livestream || giftType == GiftType.battle)) {
      if (!Get.isRegistered<LivestreamScreenController>()) {
        Loggers.error(
            '[GIFT] LivestreamScreenController not registered. Gift user-pick disabled for this context.');
        return;
      }
      livestreamController = Get.find<LivestreamScreenController>();
      if (livestreamController.selectedGiftUser.value == null) {
        livestreamController.selectedGiftUser = liveUsers.first.obs;
      } else {
        DebounceAction.shared.call(() {
          livestreamController.selectedGiftUser.value = liveUsers.firstWhere(
              (element) =>
                  element.userId ==
                  livestreamController.selectedGiftUser.value?.userId,
              orElse: () => liveUsers.first);
        });
      }

      final initialId = livestreamController.selectedGiftUser.value?.userId;
      if (initialId != null) {
        selectedGiftUserIds.assignAll({initialId});
      }
    }
  }

  void toggleGiftReceiver(AppUser user) {
    final id = user.userId;
    if (id == null) return;
    if (selectedGiftUserIds.contains(id)) {
      selectedGiftUserIds.remove(id);
      if (selectedGiftUserIds.isEmpty && liveUsers.isNotEmpty) {
        final fallback = liveUsers.first.userId;
        if (fallback != null) {
          selectedGiftUserIds.assignAll({fallback});
        }
      }
    } else {
      selectedGiftUserIds.add(id);
    }

    final firstId =
        selectedGiftUserIds.isEmpty ? null : selectedGiftUserIds.first;
    if (firstId != null) {
      final matches = liveUsers.where((e) => e.userId == firstId);
      if (matches.isNotEmpty) {
        livestreamController.selectedGiftUser.value = matches.first;
      }
    }
  }

  void selectAllGiftReceivers() {
    final ids = liveUsers.map((e) => e.userId).whereType<int>().toSet();
    if (ids.isEmpty) return;
    selectedGiftUserIds.assignAll(ids);

    final matches = liveUsers.where((e) => e.userId == ids.first);
    if (matches.isNotEmpty) {
      livestreamController.selectedGiftUser.value = matches.first;
    }
  }

  List<AppUser> get selectedGiftUsers {
    if (selectedGiftUserIds.isEmpty) return const [];
    final list = <AppUser>[];
    for (final u in liveUsers) {
      final id = u.userId;
      if (id != null && selectedGiftUserIds.contains(id)) {
        list.add(u);
      }
    }
    return list;
  }

  _initData() {
    settings.value = SessionManager.instance.getSettings();
    myUser.value = SessionManager.instance.getUser();
  }

  void onGiftTap(Gift gift, BuildContext context) {
    if (_isSendingGift.value) return;
    if (gift.id == null) {
      return showSnackBar('Gift Not Found');
    }

    final coinPrice = gift.coinPrice ?? 0;
    final receivers = (giftType == GiftType.livestream || giftType == GiftType.battle)
        ? selectedGiftUserIds.toSet().length
        : 1;
    final totalCost = coinPrice * (receivers <= 0 ? 1 : receivers);
    if (totalCost > (myUser.value?.coinWallet ?? 0)) {
      return showSnackBar('Insufficient fund');
    }

    sendGift(gift, context);
  }

  Future<void> sendGift(Gift gift, BuildContext context) async {
    if (_isSendingGift.value) return;
    _isSendingGift.value = true;
    bool loaderShown = false;
    try {
      final giftId = gift.id?.toInt() ?? -1;
      final coinPrice = gift.coinPrice ?? 0;

      final receiverIds = <int>[];
      if (giftType == GiftType.livestream || giftType == GiftType.battle) {
        receiverIds.addAll(selectedGiftUserIds.toList());
      }
      if (receiverIds.isEmpty) {
        final fallback =
            userId ?? livestreamController.selectedGiftUser.value?.userId;
        if (fallback != null) {
          receiverIds.add(fallback);
        }
      }

      // Dedupe to avoid accidental double sends.
      final uniqueReceiverIds = receiverIds.toSet().toList();
      userId ??= uniqueReceiverIds.isEmpty ? null : uniqueReceiverIds.first;

      if (giftId == -1 || userId == -1) {
        Loggers.error('Invalid Gift: $giftId or User: $userId');
        return;
      }

      if (coinPrice <= 0) {
        Loggers.error('Invalid coin price: $coinPrice, skipping gift sending.');
        return;
      }

      showLoader();
      loaderShown = true;

      String? liveType;
      int? hostId;
      if (giftType == GiftType.livestream || giftType == GiftType.battle) {
        liveType = livestreamController.isAudioRoom ? 'audio' : 'video';
        hostId = livestreamController.liveData.value.hostId;
      }

      int successCount = 0;
      final deliveredUsers = <AppUser>[];
      StatusModel? lastResponse;

      // Credits split (admin-configured expectation): receiver x10, host x2.
      const int receiverCreditMultiplier = 10;
      const int hostCreditMultiplier = 2;

      for (final rid in uniqueReceiverIds) {
        try {
          lastResponse = await GiftWalletService.instance.sendGift(
            giftId: giftId,
            userId: rid,
            liveType: liveType,
            hostId: hostId,
          );
        } catch (e) {
          Loggers.error('Gift send failed: $e');
          showSnackBar('Gift send failed');
          break;
        }
        if (lastResponse.status == true) {
          successCount++;
          final u = liveUsers.firstWhereOrNull((e) => e.userId == rid);
          if (u != null) {
            deliveredUsers.add(u);
          }
          final data = lastResponse.data;
          if (data != null) {
            final normalized = <String, dynamic>{};
            if (data.containsKey('credits')) {
              normalized['points'] = data['credits'];
            } else if (data.containsKey('miner_points')) {
              normalized['points'] = data['miner_points'];
            } else if (data.containsKey('points')) {
              normalized['points'] = data['points'];
            }
            if (data.containsKey('coins')) {
              normalized['coins'] = data['coins'];
            }
            if (normalized.isNotEmpty) {
              EconomyState.instance.ingestApi(normalized);
            }
          }

          // Post a chat/comment entry inside the live so everyone can see
          // who sent which gift to whom.
          try {
            if (giftType == GiftType.livestream || giftType == GiftType.battle) {
              await livestreamController.sendGiftCommentToLive(
                gift: gift,
                receiverId: rid,
              );

              // Update credits deterministically so UI shows exact split.
              final p = gift.coinPrice?.toInt() ?? 0;
              if (p > 0) {
                final receiverCredits = p * receiverCreditMultiplier;
                await livestreamController.updateUserStateToFirestore(
                  rid,
                  credits: receiverCredits,
                );

                final hId = hostId ?? livestreamController.liveData.value.hostId;
                if (hId != null && hId > 0) {
                  // Host bonus should be applied only when gifting others (not when gifting host).
                  if (rid != hId) {
                    final hostCredits = p * hostCreditMultiplier;
                    await livestreamController.updateUserStateToFirestore(
                      hId,
                      credits: hostCredits,
                    );
                  }
                }
              }
            }
          } catch (_) {}
        } else {
          break;
        }
      }

      if (successCount > 0) {
        final totalDeduct = coinPrice * successCount;
        myUser.update((val) {
          val?.removeCoinFromWallet(totalDeduct);
        });
        Loggers.info(myUser.value?.coinWallet);
        SessionManager.instance.setUser(myUser.value);
        final cw = myUser.value?.coinWallet;
        EconomyState.instance.set(coins: cw is num ? cw.toInt() : 0);
        if (giftType == GiftType.none) {
          Get.back(result: GiftManager(gift));
        } else {
          Get.back(
              result: GiftManager(gift,
                  streamUser: livestreamController.selectedGiftUser.value,
                  streamUsers: deliveredUsers));
        }
        return;
      }

      showSnackBar(lastResponse?.message);
    } catch (e) {
      Loggers.error('Gift send failed: $e');
      showSnackBar('Gift send failed');
    } finally {
      if (loaderShown) {
        stopLoader();
      }
      _isSendingGift.value = false;
    }
  }
}

class GiftManager {
  Gift gift;
  AppUser? streamUser;
  List<AppUser>? streamUsers;

  GiftManager(this.gift, {this.streamUser, this.streamUsers});

  static Future<void> openGiftSheet(
      {int? userId,
      Post? post,
      GiftType giftType = GiftType.none,
      BattleView battleViewType = BattleView.red,
      List<AppUser> streamUsers = const [],
      required Function(GiftManager giftManager) onCompletion}) async {
    await Get.bottomSheet<GiftManager>(
      SendGiftSheet(
        userId: userId,
        giftType: giftType,
        battleViewType: battleViewType,
        streamUsers: streamUsers,
      ),
      isScrollControlled: true,
    ).then((gift) {
      if (gift != null) {
        onCompletion(gift);
      }
    });
  }

  static void showAnimationDialog(Gift gift) {
    showGeneralDialog(
      context: Get.context!,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SendGiftDialog(gift: gift);
      },
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation);

        if (slideAnimation.isForwardOrCompleted) {
          HapticManager.shared.light();
        }

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  static void sendNotification(Post? post) {
    final user = post?.user;
    if (user == null || user.id == SessionManager.instance.getUserID()) return;

    if (user.notifyGiftReceived == 1) {
      FirebaseNotificationManager.instance.sendLocalisationNotification(
        LKey.activitySentGift,
        type: NotificationType.post,
        deviceType: user.device,
        deviceToken: user.deviceToken,
        languageCode: user.appLanguage,
        body: NotificationInfo(id: post?.id),
      );
    }
  }
}
