import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/custom_popup_menu_button.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/screen/scratch_collect/asset_vault_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ReelsTopBar extends StatelessWidget {
  final ReelsScreenController controller;
  final Widget? widget;

  const ReelsTopBar({super.key, required this.controller, this.widget});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Visibility(
                  visible: !controller.isHomePage,
                  replacement: const SizedBox(width: 30),
                  child: CustomBackButton(
                      color: whitePure(context),
                      height: 30,
                      width: 30,
                      padding: EdgeInsets.zero,
                      image: AssetRes.icBackArrow_1),
                ),
                if (widget != null) Flexible(child: widget!),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => AssetVaultScreen.open(),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.workspace_premium,
                          color: whitePure(context),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Obx(() {
                  if (controller.reels.isEmpty) {
                    return const SizedBox(width: 30, height: 30);
                  }

                  final post = controller.reels[controller.position.value];
                  final isMyPost =
                      post.userId?.toInt() == SessionManager.instance.getUserID();

                  if (!isMyPost) {
                    return InkWell(
                      onTap: controller.onReportTap,
                      child: Image.asset(
                        AssetRes.icAlert,
                        width: 30,
                        height: 30,
                        color: whitePure(context),
                      ),
                    );
                  }

                  final items = <MenuItem>[
                    MenuItem(LKey.edit.tr, () {
                      BaseController.share.showSnackBar('Edit not available');
                    }),
                    MenuItem(LKey.delete.tr, () {
                      if (Get.isRegistered<ReelController>(tag: '${post.id}')) {
                        Get.find<ReelController>(tag: '${post.id}')
                            .handleDelete(isModerator: false);
                      }
                    }),
                  ];

                  return CustomPopupMenuButton(
                    items: items,
                    child: Image.asset(
                      AssetRes.icMore1,
                      width: 30,
                      height: 30,
                      color: whitePure(context),
                    ),
                  );
                }),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
