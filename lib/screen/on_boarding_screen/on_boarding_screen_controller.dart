import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';

class OnBoardingScreenController extends BaseController {
  PageController pageController = PageController();
  RxInt selectedPage = RxInt(0);

  RxList<OnBoarding> onBoardingData = <OnBoarding>[].obs;

  @override
  void onInit() {
    super.onInit();
    _fetchOnBoarding();
  }

  void _fetchOnBoarding() {
    for (var element
        in (SessionManager.instance.getSettings()?.onBoarding ?? [])) {
      onBoardingData.add(element);
    }
    _precacheImages();
  }

  /// Push every onboarding artwork into the shared disk cache so
  /// CachedNetworkImage renders instantly instead of showing a blank gap.
  void _precacheImages() {
    for (final item in onBoardingData) {
      final url = (item.image ?? '').addBaseURL();
      if (url.isEmpty) continue;
      DefaultCacheManager()
          .getSingleFile(url)
          .then((_) {})
          .catchError((_) {});
    }
  }

  void onPageChanged(int value) {
    selectedPage.value = value;
  }

  void onSkipTap() {
    _finish();
  }

  void onNextTap() {
    if (selectedPage.value < onBoardingData.length - 1) {
      selectedPage.value++;
      pageController.animateToPage(
        selectedPage.value,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    SessionManager.instance
        .setBool(SessionKeys.isOnBoardingScreenSelect, true);
    Get.off(() => const LoginScreen());
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
