import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/account_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class SettingsScreenController extends BaseController {
  Rx<User?> myUser = Rx<User?>(null);
  Rx<Setting?> settings = Rx<Setting?>(null);
  Rx<WhoCanSeePost> selectedWhoCanSeePost = WhoCanSeePost.values.first.obs;
  RxBool isUpdateApiCalled = false.obs;

  @override
  void onInit() {
    super.onInit();
    initData();
  }

  void initData() {
    myUser.value = SessionManager.instance.getUser();
    settings.value = SessionManager.instance.getSettings();
    if (myUser.value?.whoCanViewPost == 0) {
      selectedWhoCanSeePost.value = WhoCanSeePost.values.first;
    } else {
      selectedWhoCanSeePost.value = WhoCanSeePost.values[1];
    }

    // For refresh user data only
    UserService.instance.fetchUserDetails();
    SubscriptionManager.shared.refreshSubscriptionState().catchError((_) {});
  }

  void onChangedWhoCanSeePost(WhoCanSeePost? value) async {
    isUpdateApiCalled.value = true;

    selectedWhoCanSeePost.value = value ?? WhoCanSeePost.values.first;
    await UserService.instance.updateUserDetails(whoCanSeePost: value?.value);
    isUpdateApiCalled.value = false;
  }

  onChangedToggle(bool value, SettingToggle settingToggle) async {
    isUpdateApiCalled.value = true;
    await UserService.instance.updateUserDetails(
        notifyPostLike:
            settingToggle == SettingToggle.notifyPostLike ? value : null,
        notifyPostComment:
            settingToggle == SettingToggle.notifyPostComment ? value : null,
        notifyFollow:
            settingToggle == SettingToggle.notifyFollow ? value : null,
        notifyMention:
            settingToggle == SettingToggle.notifyMention ? value : null,
        notifyGiftReceived:
            settingToggle == SettingToggle.notifyGiftReceived ? value : null,
        notifyChat: settingToggle == SettingToggle.notifyChat ? value : null,
        receiveMessage:
            settingToggle == SettingToggle.receiveMessage ? value : null,
        showMyFollowing:
            settingToggle == SettingToggle.showMyFollowings ? value : null);
    isUpdateApiCalled.value = false;
    // For update user value
    myUser.value = SessionManager.instance.getUser();
  }

  void onDeleteAccount() {
    Get.bottomSheet(ConfirmationSheet(
        onTap: () async {
          showLoader(barrierDismissible: true);
          StatusModel model = await UserService.instance.deleteMyAccount();
          stopLoader();
          if (model.status == true) {
            FirebaseFirestoreController.instance.deleteUser(myUser.value?.id);
            SessionManager.instance.clear();
            deleteCurrentUser();
            Get.offAll(() => const LoginScreen());
          } else {
            showSnackBar(model.message);
          }
        },
        description: LKey.deleteAccountMessage.tr,
        description2: LKey.proceedConfirmation.tr,
        title: LKey.deleteYourAccount.tr));
  }

  Future<void> deleteCurrentUser() async {
    try {
      auth.User? user = auth.FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.delete(); // Deletes the account
        Loggers.success("User account deleted successfully.");
      } else {
        Loggers.success("No user is signed in.");
      }
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        Loggers.error(
            '⚠️ The user must re-authenticate before deleting their account.');
        reAuthenticateAndDelete(myUser.value?.identity ?? '');
        // Prompt for re-authentication here
      } else {
        Loggers.error('❌ Error: ${e.message}');
      }
    }
  }

  Future<void> reAuthenticateAndDelete(String email) async {
    try {
      auth.User? user = auth.FirebaseAuth.instance.currentUser;

      if (user != null) {
        String? password = SessionManager.instance.getPassword();
        if (password == null) return;
        auth.AuthCredential credential =
            auth.EmailAuthProvider.credential(email: email, password: password);

        await user.reauthenticateWithCredential(credential);
        await user.delete();

        Loggers.info("User re-authenticated and deleted.");
      }
    } catch (e) {
      Loggers.info("Error: $e");
    }
  }

  /// Instagram-style account switcher sheet: lists every remembered login,
  /// lets the user jump between them or add a new one.
  void showAccountSwitcher() {
    final accounts = AccountManager.instance.getSavedAccounts();
    final currentId = SessionManager.instance.getUserID();

    Get.bottomSheet(
      Builder(builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: scaffoldBackgroundColor(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Switch account',
                    style: TextStyleCustom.outFitSemiBold600(
                        color: textDarkGrey(context), fontSize: 17)),
                const SizedBox(height: 12),
                ...accounts.map((a) {
                  final isCurrent = a.userId == currentId;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: bgMediumGrey(context),
                      backgroundImage: a.profilePhoto.isNotEmpty
                          ? CachedNetworkImageProvider(a.profilePhoto.addBaseURL())
                          : null,
                      child: a.profilePhoto.isEmpty
                          ? Icon(Icons.person, color: textLightGrey(context))
                          : null,
                    ),
                    title: Text(
                      a.fullname.isNotEmpty ? a.fullname : a.username,
                      style: TextStyleCustom.outFitMedium500(
                          color: textDarkGrey(context), fontSize: 15),
                    ),
                    subtitle: Text('@${a.username}',
                        style: TextStyleCustom.outFitRegular400(
                            color: textLightGrey(context), fontSize: 13)),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle,
                            color: themeAccentSolid(context))
                        : IconButton(
                            icon: Icon(Icons.close,
                                color: textLightGrey(context), size: 20),
                            onPressed: () {
                              AccountManager.instance.removeAccount(a.userId);
                              Get.back();
                              showAccountSwitcher();
                            },
                          ),
                    onTap: isCurrent
                        ? null
                        : () async {
                            Get.back();
                            await AccountManager.instance.switchTo(a);
                          },
                  );
                }),
                const Divider(height: 24),
                ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: bgMediumGrey(context),
                    child:
                        Icon(Icons.add, color: textDarkGrey(context)),
                  ),
                  title: Text('Add account',
                      style: TextStyleCustom.outFitMedium500(
                          color: textDarkGrey(context), fontSize: 15)),
                  onTap: () async {
                    Get.back();
                    await AccountManager.instance.addAccount();
                  },
                ),
              ],
            ),
          ),
        );
      }),
      isScrollControlled: true,
    );
  }

  void onLogout() {
    Get.bottomSheet(ConfirmationSheet(
      onTap: () async {
        showLoader();
        try {
          StatusModel result = await UserService.instance.logoutUser();
          if (result.status == true) {
            GoogleSignIn.instance.signOut();
            SessionManager.instance.clearSomeKey();
            Get.offAll(() => const LoginScreen());
          } else {
            showSnackBar(result.message);
          }
        } catch (e) {
          showSnackBar('$e');
        } finally {
          stopLoader();
        }
      },
      description: LKey.logoutConfirmation.tr,
      description2: LKey.proceedConfirmation.tr,
      title: LKey.logoutTitle.tr,
    ));
  }
}

enum WhoCanSeePost {
  everyone,
  followersOnly;

  String get title {
    switch (this) {
      case WhoCanSeePost.everyone:
        return LKey.everyone.tr;
      case WhoCanSeePost.followersOnly:
        return LKey.followersOnly.tr;
    }
  }

  String get value {
    switch (this) {
      case WhoCanSeePost.everyone:
        return '0';
      case WhoCanSeePost.followersOnly:
        return '1';
    }
  }
}

enum SettingToggle {
  showMyFollowings,
  receiveMessage,
  notifyPostLike,
  notifyPostComment,
  notifyFollow,
  notifyMention,
  notifyGiftReceived,
  notifyChat;
}
