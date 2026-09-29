import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';

class PaidCallsSettingsController extends BaseController {
  RxBool eligible = false.obs;
  RxBool enabled = false.obs;
  TextEditingController audioPriceController = TextEditingController();
  TextEditingController videoPriceController = TextEditingController();
  TextEditingController fallbackPriceController = TextEditingController();
  VoidCallback? _cancelPlusActive;
  VoidCallback? _cancelPlusFeatures;

  bool get isEligible => eligible.value;

  @override
  void onInit() {
    super.onInit();
    _refreshEligibility();
    _cancelPlusActive = SessionManager.instance.storage.listenKey(SessionKeys.plusActive, (_) {
      _refreshEligibility();
    });
    _cancelPlusFeatures = SessionManager.instance.storage.listenKey(SessionKeys.plusFeatures, (_) {
      _refreshEligibility();
    });
    final user = SessionManager.instance.getUser();
    final audioPrice = user?.audioCallPrice ?? 0;
    final videoPrice = user?.videoCallPrice ?? 0;
    final fallbackPrice = user?.callPrice ?? 0;
    enabled.value = audioPrice > 0 || videoPrice > 0 || fallbackPrice > 0;
    audioPriceController.text = audioPrice > 0 ? audioPrice.toString() : '';
    videoPriceController.text = videoPrice > 0 ? videoPrice.toString() : '';
    fallbackPriceController.text =
        fallbackPrice > 0 ? fallbackPrice.toString() : '';
  }

  void _refreshEligibility() {
    eligible.value = SessionManager.instance.getPlusActive == 1 &&
        SessionManager.instance.hasPlusFeature('paid_calls_coins');
  }

  Future<void> save() async {
    if (!isEligible) return;

    int parseOrZero(String v) {
      final raw = v.trim();
      return raw.isEmpty ? 0 : (int.tryParse(raw) ?? 0);
    }

    final int nextAudio = enabled.value ? parseOrZero(audioPriceController.text) : 0;
    final int nextVideo = enabled.value ? parseOrZero(videoPriceController.text) : 0;
    final int nextFallback =
        enabled.value ? parseOrZero(fallbackPriceController.text) : 0;

    showLoader(barrierDismissible: false);
    final user = await UserService.instance.updateUserDetails(
      audioCallPrice: nextAudio,
      videoCallPrice: nextVideo,
      callPrice: nextFallback,
    );
    stopLoader();
    if (user == null) return;
    Get.back();
  }

  @override
  void onClose() {
    _cancelPlusActive?.call();
    _cancelPlusFeatures?.call();
    audioPriceController.dispose();
    videoPriceController.dispose();
    fallbackPriceController.dispose();
    super.onClose();
  }
}
