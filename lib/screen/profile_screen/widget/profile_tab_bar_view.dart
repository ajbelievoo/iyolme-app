import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ProfileTabs extends StatelessWidget {
  final ProfileScreenController controller;

  const ProfileTabs({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(
          () => Stack(
            children: [
              Container(height: .5, color: textLightGrey(context)),
              AnimatedAlign(
                alignment: controller.selectedTabIndex.value == 0
                    ? AlignmentDirectional.centerStart
                    : controller.selectedTabIndex.value == 1
                        ? const Alignment(-0.33, 0)
                        : controller.selectedTabIndex.value == 2
                            ? const Alignment(0.33, 0)
                            : AlignmentDirectional.centerEnd,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  height: 1.5,
                  width: Get.width / 4 - 45,
                  color: textDarkGrey(context),
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                ),
              ),
            ],
          ),
        ),
        TabBar(
            onTap: (value) {
              controller.userData.value?.checkIsBlocked(() {
                controller.onTabChanged(value);
                controller.pageController.animateToPage(value,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.linear);
              });
            },
            indicatorColor: Colors.transparent,
            tabs: List.generate(4, (index) {
              return Obx(() {
                final selected = controller.selectedTabIndex.value == index;
                final color =
                    selected ? textDarkGrey(context) : disableGrey(context);
                if (index == 0) {
                  return Icon(Icons.grid_on_rounded, color: color, size: 26);
                }
                if (index == 3) {
                  return Icon(Icons.bookmark_border_rounded,
                      color: color, size: 26);
                }
                final icon = index == 1 ? AssetRes.icReel : AssetRes.icGift;
                return Image.asset(icon, height: 44, width: 26, color: color);
              });
            })),
        Container(height: .5, color: textLightGrey(context)),
      ],
    );
  }
}
