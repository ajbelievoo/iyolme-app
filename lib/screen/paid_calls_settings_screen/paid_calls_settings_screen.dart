import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_app_bar.dart';
import 'package:shortzz/common/widget/custom_toggle.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/common/widget/text_field_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/paid_calls_settings_screen/paid_calls_settings_controller.dart';
import 'package:shortzz/utilities/theme_res.dart';

class PaidCallsSettingsScreen extends StatelessWidget {
  const PaidCallsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PaidCallsSettingsController());
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      body: Column(
        children: [
          CustomAppBar(title: LKey.paidCalls.tr),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Obx(() {
                if (!controller.isEligible) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      LKey.paidCallsNotAvailable.tr,
                      style: TextStyle(color: textLightGrey(context)),
                    ),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              LKey.enablePaidCalls.tr,
                              style: TextStyle(color: textDarkGrey(context)),
                            ),
                          ),
                          CustomToggle(
                            isOn: controller.enabled,
                            onChanged: (v) {
                              controller.enabled.value = v;
                              if (!v) {
                                controller.audioPriceController.text = '';
                                controller.videoPriceController.text = '';
                                controller.fallbackPriceController.text = '';
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (controller.enabled.value)
                      Column(
                        children: [
                          TextFieldCustom(
                            controller: controller.audioPriceController,
                            title: 'Audio Call Rate (Tokens/min)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          TextFieldCustom(
                            controller: controller.videoPriceController,
                            title: 'Video Call Rate (Tokens/min)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          TextFieldCustom(
                            controller: controller.fallbackPriceController,
                            title: 'Fallback Price (Optional) (Tokens/min)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ],
                      ),
                  ],
                );
              }),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: TextButtonCustom(
              title: LKey.saveChanges.tr,
              backgroundColor: textDarkGrey(context),
              titleColor: whitePure(context),
              onTap: () => controller.isEligible ? controller.save() : null,
            ),
          ),
        ],
      ),
    );
  }
}
