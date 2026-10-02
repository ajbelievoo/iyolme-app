import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_app_bar.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';
import 'package:shortzz/screen/on_boarding_screen/on_boarding_screen.dart';
import 'package:shortzz/screen/select_language_screen/select_language_screen_controller.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

enum LanguageNavigationType { fromStart, fromSetting }

class SelectLanguageScreen extends StatelessWidget {
  final LanguageNavigationType languageNavigationType;

  const SelectLanguageScreen({super.key, required this.languageNavigationType});

  static const Color _bg = Color(0xFF0B0B12);
  static const Color _card = Color(0xFF17171F);

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(SelectLanguageScreenController(languageNavigationType));
    final fromStart = languageNavigationType == LanguageNavigationType.fromStart;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          if (fromStart) _buildHeader(context) else _buildAppBar(context),
          Expanded(
            child: ListView.builder(
              itemCount: controller.languages.length,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemBuilder: (context, index) {
                final language = controller.languages[index];
                return Obx(() {
                  final isSelected =
                      language == controller.selectedLanguage.value;
                  return _LanguageTile(
                    language: language,
                    selected: isSelected,
                    onTap: () => controller.onLanguageChange(language),
                  );
                });
              },
            ),
          ),
          if (fromStart) _buildFooter(controller),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return CustomAppBar(
      title: LKey.languages.tr,
      titleStyle: TextStyleCustom.unboundedSemiBold600(
          fontSize: 15, color: whitePure(context)),
      bgColor: _bg,
      iconColor: whitePure(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: StyleRes.themeGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: ColorRes.themeAccentSolid.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.language_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 22),
            Text(
              LKey.select.tr,
              style: TextStyleCustom.unboundedBlack900(
                  fontSize: 30, color: whitePure(context)),
            ),
            Text(
              LKey.language.tr,
              style: TextStyleCustom.unboundedBlack900(
                  fontSize: 30, color: whitePure(context), opacity: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the language you feel at home in',
              style: TextStyleCustom.outFitLight300(
                  fontSize: 14,
                  color: whitePure(context).withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(SelectLanguageScreenController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        color: _card,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () {
            SessionManager.instance
                .setBool(SessionKeys.isLanguageScreenSelect, true);
            if ((controller.setting?.onBoarding ?? []).isEmpty) {
              Get.off(() => const LoginScreen());
            } else {
              Get.off(() => const OnBoardingScreen());
            }
          },
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: StyleRes.themeGradient,
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: ColorRes.themeAccentSolid.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  LKey.continueText.tr,
                  style: TextStyleCustom.outFitBold700(
                      fontSize: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final Language language;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? ColorRes.themeAccentSolid.withValues(alpha: 0.14)
                  : SelectLanguageScreen._card,
              border: Border.all(
                width: selected ? 1.4 : 1,
                color: selected
                    ? ColorRes.themeAccentSolid.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.title ?? '',
                        style: TextStyleCustom.outFitMedium500(
                            fontSize: 16, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((language.localizedTitle ?? '').isNotEmpty)
                        Text(
                          language.localizedTitle ?? '',
                          style: TextStyleCustom.outFitLight300(
                              fontSize: 13,
                              color:
                                  Colors.white.withValues(alpha: 0.55)),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? StyleRes.themeGradient : null,
                    border: Border.all(
                      width: 2,
                      color: selected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
