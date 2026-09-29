import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/model/sticker/stickers_model.dart';
import 'package:shortzz/screen/sticker_sheet/sticker_sheet_controller.dart';
import 'package:shortzz/utilities/theme_res.dart';

class StickerSheet extends StatelessWidget {
  const StickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StickerSheetController>();

    return Container(
      margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
      decoration: ShapeDecoration(
          color: whitePure(context),
          shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                  top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)))),
      child: Column(
        children: [
          const BottomSheetTopView(title: 'Stickers'),
          Expanded(
            child: Obx(() {
              final isLoading =
                  controller.isLoadingStickers.value && controller.stickers.isEmpty;
              final List<StickerItem> items = controller.stickers;

              return isLoading
                  ? const LoaderWidget()
                  : NoDataView(
                      showShow: items.isEmpty,
                      child: GridView.builder(
                        itemCount: items.length,
                        padding: const EdgeInsets.only(
                            left: 10, right: 10, top: 10, bottom: 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final url = (item.imageUrl ?? '')
                              .trim()
                              .isNotEmpty
                              ? item.imageUrl
                              : item.image?.addBaseURL();

                          return CustomImage(
                            size: const Size(80, 80),
                            fit: BoxFit.contain,
                            radius: 12,
                            isShowPlaceHolder: true,
                            image: url,
                            onTap: () {
                              if (url == null || url.trim().isEmpty) return;
                              Get.back(result: url);
                            },
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
Q