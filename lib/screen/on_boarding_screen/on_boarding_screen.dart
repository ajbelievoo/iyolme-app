import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/on_boarding_screen/on_boarding_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';

class OnBoardingScreen extends StatelessWidget {
  const OnBoardingScreen({super.key});

  static const Color _bg = Color(0xFF0B0B12);
  static const Color _card = Color(0xFF17171F);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnBoardingScreenController());
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false,
      body: Obx(() {
        final count = controller.onBoardingData.length;
        if (count == 0) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: ColorRes.whitePure),
            ),
          );
        }
        return Stack(
          children: [
            // Full-bleed pages
            PageView.builder(
              controller: controller.pageController,
              itemCount: count,
              onPageChanged: controller.onPageChanged,
              itemBuilder: (context, index) {
                final data = controller.onBoardingData[index];
                return _OnBoardingPage(data: data, dpr: dpr);
              },
            ),
            // Top bar: brand + Skip
            SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: Text(
                        'IyolMe',
                        style: TextStyleCustom.unboundedSemiBold600(
                            fontSize: 14, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Obx(() => AnimatedOpacity(
                          opacity: controller.selectedPage.value == count - 1
                              ? 0.0
                              : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: TextButton(
                            onPressed: controller.onSkipTap,
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.35),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.14)),
                              ),
                            ),
                            child: Text(
                              LKey.skip.tr,
                              style: TextStyleCustom.outFitMedium500(
                                  fontSize: 14, color: Colors.white),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final count = controller.onBoardingData.length;
        if (count == 0) return const SizedBox.shrink();
        final isLast = controller.selectedPage.value == count - 1;
        return Container(
          color: _card,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // progress dots
                Row(
                  children: List.generate(count, (i) {
                    final selected = controller.selectedPage.value == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      height: 8,
                      width: selected ? 28 : 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: selected ? StyleRes.themeGradient : null,
                        color: selected
                            ? null
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                // Next / Get Started
                GestureDetector(
                  onTap: controller.onNextTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      gradient: StyleRes.themeGradient,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ColorRes.themeAccentSolid.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? LKey.getStarted.tr : LKey.next.tr,
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
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _OnBoardingPage extends StatelessWidget {
  final OnBoarding data;
  final double dpr;

  const _OnBoardingPage({required this.data, required this.dpr});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final imageUrl = (data.image ?? '').addBaseURL();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image — from disk cache (precached) or network; never a blank gap.
        if (imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            memCacheWidth: (size.width * dpr).round(),
            fadeInDuration: Duration.zero,
            placeholder: (_, __) => const _FallbackArt(),
            errorWidget: (_, __, ___) => const _FallbackArt(),
          )
        else
          const _FallbackArt(),
        // Bottom scrim so the text card stays readable on any artwork.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0x59000000),
                Color(0xF20B0B12),
              ],
              stops: [0.35, 0.65, 1.0],
            ),
          ),
        ),
        // Copy
        Positioned(
          left: 28,
          right: 28,
          bottom: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (data.title ?? '').tr,
                style: TextStyleCustom.unboundedBlack900(
                        fontSize: 30, color: Colors.white)
                    .copyWith(height: 1.15),
                maxLines: AppRes.titleMaxLine,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text(
                (data.description ?? '').tr,
                style: TextStyleCustom.outFitLight300(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.85))
                    .copyWith(height: 1.45),
                maxLines: AppRes.descriptionMaxLine,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown while the artwork streams in (or if it fails) — a branded gradient
/// instead of a blank/black screen.
class _FallbackArt extends StatelessWidget {
  const _FallbackArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241A2E), Color(0xFF12101C), Color(0xFF0B0B12)],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note_rounded,
            size: 96, color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }
}
