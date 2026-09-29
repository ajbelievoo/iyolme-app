import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class CoinWalletList extends StatelessWidget {
  final CoinWalletScreenController controller;

  const CoinWalletList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Obx(
        () {
          if (controller.coinPlans.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    LKey.noData.tr,
                    style: TextStyleCustom.outFitRegular400(color: textLightGrey(context)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    controller.coinPlansDebug.value,
                    style: TextStyleCustom.outFitRegular400(
                      color: textLightGrey(context),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 20),
            itemCount: controller.coinPlans.length,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) {
              CoinPlan data = controller.coinPlans[index];
              return Container(
                height: 70,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: ShapeDecoration(
                    shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1),
                        side: BorderSide(
                          color: textLightGrey(context).withValues(alpha: .2),
                        )),
                    color: bgLightGrey(context)),
                child: Row(
                  children: [
                    Image.asset(AssetRes.icCoin, width: 34, height: 34),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${data.coin} ${LKey.coins.tr}',
                            style: TextStyleCustom.unboundedMedium500(
                                color: textDarkGrey(context), fontSize: 15)),
                        Text('${data.priceString} ${LKey.only.tr}',
                            style: TextStyleCustom.outFitRegular400(color: textLightGrey(context))),
                      ],
                    )),
                    TextButtonCustom(
                        onTap: () {
                          if (controller.canPurchase(data)) {
                            controller.onPurchase(data);
                          } else {
                            Get.rawSnackbar(
                              message:
                                  'Purchase not available: product not found in Google Play. Please verify Play Console product ID.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 4),
                            );
                          }
                        },
                        title: controller.canPurchase(data) ? LKey.purchase.tr : 'Unavailable',
                        backgroundColor: controller.canPurchase(data)
                            ? themeAccentSolid(context)
                            : textLightGrey(context).withValues(alpha: .35),
                        btnHeight: 40,
                        fontSize: 15,
                        titleColor: whitePure(context),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        horizontalMargin: 0)
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
p