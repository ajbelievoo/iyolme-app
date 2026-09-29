import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/model/gift/received_gifts_model.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ProfileGiftsPage extends StatelessWidget {
  final ProfileScreenController controller;

  const ProfileGiftsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isGiftLoading.value;
      final items = controller.receivedGifts;

      if (isLoading && items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (items.isEmpty) {
        return const NoDataView();
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= (n.metrics.maxScrollExtent - 200)) {
            controller.fetchReceivedGifts();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final ReceivedGiftItem item = items[index];
            return _GiftTile(item: item);
          },
        ),
      );
    });
  }
}

class _GiftTile extends StatelessWidget {
  final ReceivedGiftItem item;

  const _GiftTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final count = item.count ?? 1;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgGrey(context).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bgMediumGrey(context).withValues(alpha: 0.5)),
          ),
          child: Center(
            child: CustomImage(
              size: const Size(72, 72),
              image: (item.giftImage ?? '').isEmpty
                  ? ''
                  : (item.giftImage ?? '').addBaseURL(),
              radius: 12,
              cornerSmoothing: 1,
              isShowPlaceHolder: true,
            ),
          ),
        ),
        if (count > 1)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: blackPure(context).withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'x$count',
                style: TextStyleCustom.outFitMedium500(
                  color: whitePure(context),
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
k