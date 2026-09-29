import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/share_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/const_res.dart';

class ReferralScreenController extends BaseController {
  final Rxn<User> myUser = Rxn<User>();
  final Rxn<Setting> settings = Rxn<Setting>();

  @override
  void onInit() {
    super.onInit();
    myUser.value = SessionManager.instance.getUser();
    settings.value = SessionManager.instance.getSettings();
    _refreshSettings();
    refreshUser();
  }

  String get referralCode => (myUser.value?.referralCode ?? '').trim();

  String get inviteLink {
    final code = referralCode;
    if (code.isNotEmpty) {
      return '${baseURL}invite/$code';
    }
    final uid = myUser.value?.id ?? 0;
    if (uid <= 0) return '';
    return ShareManager.shared.getLink(key: ShareKeys.user, value: uid);
  }

  String get shareText {
    final code = referralCode;
    final link = inviteLink;
    if (link.isEmpty) return '';
    if (code.isEmpty) {
      return 'Hey! Join me on IyolMe: $link';
    }
    return 'Hey! Join me on IyolMe. Use my code $code to get a bonus! Download here: $link';
  }

  Future<void> _refreshSettings() async {
    await CommonService.instance.fetchGlobalSettings();
    settings.value = SessionManager.instance.getSettings();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshUser(),
      _refreshSettings(),
    ]);
  }

  Future<void> refreshUser() async {
    try {
      final u = await UserService.instance.fetchUserDetails();
      if (u != null) {
        myUser.value = u;
      } else {
        myUser.value = SessionManager.instance.getUser();
      }
    } catch (_) {
      myUser.value = SessionManager.instance.getUser();
    }
  }

  Future<void> copyReferralCode() async {
    final code = referralCode;
    final textToCopy = code.isNotEmpty ? code : inviteLink;
    if (textToCopy.isEmpty) {
      showSnackBar(LKey.referralCodeNotAvailable.tr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: textToCopy));
    showSnackBar(LKey.copiedToClipboard.tr);
  }

  Future<void> shareInvite() async {
    final text = shareText;
    if (text.isEmpty) {
      showSnackBar(LKey.referralCodeNotAvailable.tr);
      return;
    }
    Rect? origin;
    final context = Get.context;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: LKey.inviteFriends.tr,
        sharePositionOrigin: origin,
      ),
    );
  }
}
