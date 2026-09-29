import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/common/widget/theme_blur_bg.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/on_boarding_screen/on_boarding_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class OnBoardingScreen extends StatelessWidget {
  const OnBoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnBoardingScreenController());
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const ThemeBlurBg(),
          // Image View
          Obx(() =>
              OnBoardingTopBGView(index: controller.selectedPage.value, controller: controller)),
          // Text and Description view with button — white bottom card
          Obx(
            () => Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: Get.height / 1.4,
                  child: PageView.builder(
                    controller: controller.pageController,
                    itemCount: controller.onBoardingData.length,
                    onPageChanged: controller.onPageChanged,
                    itemBuilder: (context, index) {
                      OnBoarding data = controller.onBoardingData[index];
                      return OnBoardingView(
                        title: (data.title ?? "").tr,
                        description: (data.description ?? '').tr,
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: whitePure(context),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .15),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // dot indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              controller.onBoardingData.length,
                              (index) {
                                bool isSelected =
                                    controller.selectedPage.value == index;
                                return AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  height: 8,
                                  width: isSelected ? 26 : 8,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    color: isSelected
                                        ? ColorRes.blueFollow
                                        : disableGrey(context),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButtonCustom(
                            onTap: controller.onNextTap,
                            title: LKey.next.tr,
                            titleColor: whitePure(context),
                            backgroundColor: ColorRes.blueFollow,
                            btnHeight: 50,
                            radius: 12,
                            horizontalMargin: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnBoardingTopBGView extends StatelessWidget {
  final int index;
  final OnBoardingScreenController controller;

  const OnBoardingTopBGView({super.key, required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    double imageHeight = 400;
    return SafeArea(
      bottom: false,
      child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: CustomImage(
              key: ValueKey<int>(index),
              size: Size(Get.width, imageHeight),
              image: (controller.onBoardingData[index].image ?? '').addBaseURL(),
              radius: 0,
              isShowPlaceHolder: true,
              fit: BoxFit.fitHeight,
              isImageLoaderVisible: false)),
    );
  }
}

class OnBoardingView extends StatelessWidget {
  final String title;
  final String description;

  const OnBoardingView({super.key, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 54),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyleCustom.unboundedBlack900(fontSize: 22, color: whitePure(context)),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: AppRes.titleMaxLine,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: TextStyleCustom.outFitRegular400(fontSize: 19, color: whitePure(context)),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: AppRes.descriptionMaxLine,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
