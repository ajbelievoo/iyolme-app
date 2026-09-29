import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/model/chat_theme/chat_themes_model.dart';
import 'package:shortzz/screen/chat_theme_sheet/chat_theme_sheet_controller.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ChatThemeSheet extends StatelessWidget {
  const ChatThemeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ChatThemeSheetController>()
        ? Get.find<ChatThemeSheetController>()
        : Get.put(ChatThemeSheetController());

    return Container(
      margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
      decoration: ShapeDecoration(
          color: whitePure(context),
          shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                  top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)))),
      child: Column(
        children: [
          const BottomSheetTopView(title: 'Chat Themes'),
          Expanded(
            child: Obx(() {
              final isLoading = controller.isLoadingThemes.value && controller.themes.isEmpty;
              final List<ChatThemeItem> items = controller.themes;

              return isLoading
                  ? const LoaderWidget()
                  : NoDataView(
                      showShow: items.isEmpty,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final preview = item.backgroundImageUrl;
                          return InkWell(
                            onTap: () async {
                              await controller.selectTheme(item);
                              if (Get.isBottomSheetOpen == true) {
                                Get.back();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: ShapeDecoration(
                                color: bgLightGrey(context),
                                shape: SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius(
                                    cornerRadius: 12,
                                    cornerSmoothing: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CustomImage(
                                    size: const Size(52, 52),
                                    radius: 12,
                                    fit: BoxFit.cover,
                                    isShowPlaceHolder: true,
                                    image: (preview ?? '').trim().isEmpty ? null : preview,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      (item.title ?? 'Theme').toString(),
                                      style: TextStyleCustom.outFitRegular400(
                                        color: textDarkGrey(context),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: textLightGrey(context)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
            }),
          ),
        ],
      ),
    );
  }
}
