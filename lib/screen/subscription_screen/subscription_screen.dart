import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/gradient_text.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/subscription_screen/subscription_screen_controller.dart';
import 'package:shortzz/screen/subscription_screen/subscription_active_screen.dart';
import 'package:shortzz/screen/verification_screen/verification_details_form_screen.dart';
import 'package:shortzz/screen/verification_screen/verification_in_review_screen.dart';
import 'package:shortzz/screen/verification_screen/verification_congrats_screen.dart';
import 'package:shortzz/screen/verification_screen/verification_rejected_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class SubscriptionScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;
  final bool forceShowPlans;

  const SubscriptionScreen(
      {super.key, this.onUpdateUser, this.forceShowPlans = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SubscriptionScreenController(onUpdateUser));

    return Obx(() {
      final bool hasPlus = SessionManager.instance.isPlusActive.value == 1;
      final bool isExpired = SessionManager.instance.isPlusExpired;
      final bool effectiveActive = SessionManager.instance.isPlusEffectiveActive;

      if (hasPlus && !forceShowPlans) {
        final features = SessionManager.instance.getPlusFeatures;
        final bool requiresVerification = features != null &&
            (features['verified_badge'] == true ||
                features['verified_badge'] == 1 ||
                features['verified_badge'] == '1');
        final bool isVerified = SessionManager.instance.isVerify.value == 1;

        if (!isExpired && requiresVerification && !isVerified) {
          final status = SessionManager.instance.verificationStatus.value;
          final reqId = SessionManager.instance.verificationRequestId.value;

          if (status == 1) {
            return const VerificationCongratsScreen();
          }
          if (status == 0) {
            return VerificationInReviewScreen(
                requestId: reqId > 0 ? reqId : null);
          }
          if (status == 2) {
            return const VerificationRejectedScreen();
          }
          // unknown (-1) -> show form again
          return const VerificationDetailsFormScreen(
            planName: 'Plus',
            subscriptionId: null,
            paymentId: null,
          );
        }
        return SubscriptionActiveScreen(
          isExpired: !effectiveActive,
          onRenew: () {
            Get.off(() => SubscriptionScreen(
                onUpdateUser: onUpdateUser, forceShowPlans: true));
          },
          onUpgrade: () {
            Get.off(() => SubscriptionScreen(
                onUpdateUser: onUpdateUser, forceShowPlans: true));
          },
        );
      }

      return Scaffold(
        body: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: CustomBackButton(
                  padding: EdgeInsets.all(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      GradientText(LKey.plus.tr,
                          gradient: StyleRes.themeGradient,
                          style: TextStyleCustom.unboundedExtraBold800(
                              fontSize: 44)),
                      const SizedBox(height: 10),
                      Text(LKey.subscribeToPlus.tr,
                          style: TextStyleCustom.outFitRegular400(
                              fontSize: 18, color: textLightGrey(context)),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BuildIconWithText(
                              icon: AssetRes.icNoAds, title: LKey.noAds.tr),
                          const SizedBox(width: 10),
                          BuildIconWithText(
                              icon: AssetRes.icBlueTick,
                              title: LKey.getVerified.tr),
                        ],
                      ),
                      _buildStatusSection(context, controller),
                      _buildPlansSection(context, controller),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatusSection(
      BuildContext context, SubscriptionScreenController controller) {
    return Obx(() {
      final enabled = SessionManager.instance.getSubscriptionEnabled == 1;
      final hasPlus = SessionManager.instance.isPlusActive.value == 1;
      final effectiveActive = SessionManager.instance.isPlusEffectiveActive;
      final expired = SessionManager.instance.isPlusExpired;
      final expiresAt = SessionManager.instance.getPlusExpiresAt;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
              borderRadius:
                  SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: 1),
              side: BorderSide(
                  color: textLightGrey(context).withValues(alpha: .2)),
            ),
            color: bgLightGrey(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      enabled
                          ? 'Subscription: Enabled'
                          : 'Subscription: Disabled',
                      style: TextStyleCustom.unboundedMedium500(
                        fontSize: 15,
                        color: textDarkGrey(context),
                      ),
                    ),
                  ),
                  Obx(() => controller.isRefreshing.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: controller.refreshStatus,
                          icon: const Icon(Icons.refresh),
                        )),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                !hasPlus
                    ? 'Status: Inactive'
                    : (effectiveActive
                        ? 'Status: Active'
                        : (expired ? 'Status: Expired' : 'Status: Inactive')),
                style: TextStyleCustom.outFitRegular400(
                    color: textLightGrey(context)),
              ),
              if (expiresAt != null && expiresAt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Expires: $expiresAt',
                  style: TextStyleCustom.outFitRegular400(
                      color: textLightGrey(context)),
                ),
              ]
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPlansSection(
      BuildContext context, SubscriptionScreenController controller) {
    return Obx(() {
      if (controller.isLoadingPlans.value && controller.plans.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.plans.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Text(
                'Plans not available right now.',
                style: TextStyleCustom.outFitRegular400(
                  color: textLightGrey(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextButtonCustom(
                onTap: controller.fetchPlans,
                title: 'Retry',
                backgroundColor: themeAccentSolid(context),
                titleColor: whitePure(context),
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            ...controller.plans
                .map((p) => _buildPlanCard(context, controller, p)),
            TextButtonCustom(
              onTap: controller.refreshStatus,
              title: 'Refresh Status',
              backgroundColor: textDarkGrey(context),
              titleColor: whitePure(context),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 40),
              child: Text(
                LKey.subscriptionTerms.tr,
                style: TextStyleCustom.outFitLight300(
                    fontSize: 13, color: textLightGrey(context)),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: AppBar().preferredSize.height / 2.5),
          ],
        ),
      );
    });
  }

  Widget _buildPlanCard(BuildContext context,
      SubscriptionScreenController controller, dynamic p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: 1),
          side: BorderSide(color: textLightGrey(context).withValues(alpha: .2)),
        ),
        color: bgLightGrey(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.title ?? 'Plan',
            style: TextStyleCustom.unboundedMedium500(
              fontSize: 16,
              color: textDarkGrey(context),
            ),
          ),
          if ((p.price ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Text(
              'From ${p.currency ?? ''}${p.price} / ${((p.durationDays ?? 0) >= 28) ? 'month' : 'plan'}',
              style: TextStyleCustom.outFitRegular400(
                fontSize: 13,
                color: textLightGrey(context),
              ),
            ),
          ],
          if ((p.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              p.description ?? '',
              style: TextStyleCustom.outFitRegular400(
                color: textLightGrey(context),
              ),
            ),
          ],
          _buildPlanFeatures(context, p),
          const SizedBox(height: 10),
          TextButtonCustom(
            onTap: () => _showSubscriptionOptions(context, controller, p),
            title: 'Subscribe',
            backgroundColor: themeAccentSolid(context),
            titleColor: whitePure(context),
            horizontalMargin: 0,
            btnHeight: 44,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanFeatures(BuildContext context, dynamic p) {
    if ((p.features ?? const <String>[]).isEmpty &&
        (p.featureFlags ?? const <String, bool>{}).isEmpty) {
      return const SizedBox.shrink();
    }

    final rawFlags = p.featureFlags ?? const <String, bool>{};
    final enabledOnly = p.features ?? const <String>[];

    final keys = <String>{};
    keys.addAll(rawFlags.keys);
    keys.addAll(enabledOnly);

    final ordered = <String>[
      'verified_badge',
      'no_ads',
      'search_optimized',
      'featured_profile',
      'add_link_to_reel',
      'add_image_to_link',
      'exclusive_stickers',
      'custom_chat_theme',
      'impersonation_protection',
      'vids_ai_free',
      'creator_plus_miner',
    ];

    final rest = keys.where((k) => !ordered.contains(k)).toList()..sort();
    final allKeys = [...ordered.where(keys.contains), ...rest];

    final verified = <Widget>[];
    final discovery = <Widget>[];
    final engagement = <Widget>[];
    final protection = <Widget>[];
    final other = <Widget>[];

    final mm = (p.miningMultiplier ?? '').trim();
    if (mm.isNotEmpty && mm != '0' && mm.toLowerCase() != 'null') {
      other.add(_featureRow(context, 'mining_multiplier: $mm', true));
    }

    for (final k in allKeys) {
      final enabled = rawFlags.isNotEmpty ? (rawFlags[k] ?? false) : true;
      final section = _sectionFor(k);
      final row = _featureRow(context, k, enabled);
      if (section == 'Verified badge') {
        verified.add(row);
      } else if (section == 'Maximize discovery') {
        discovery.add(row);
      } else if (section == 'Drive engagement') {
        engagement.add(row);
      } else if (section == 'Protect your brand') {
        protection.add(row);
      } else {
        other.add(row);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _featureSection(context, 'Verified badge', verified),
        _featureSection(context, 'Maximize discovery', discovery),
        _featureSection(context, 'Drive engagement', engagement),
        _featureSection(context, 'Protect your brand', protection),
        _featureSection(context, 'More', other),
      ],
    );
  }

  void _showSubscriptionOptions(BuildContext context,
      SubscriptionScreenController controller, dynamic p) {
    final gateways = controller.settings?.gateways;
    final googleActive = (p.googlePlayProductId ?? '').isNotEmpty;
    final razorpayActive = gateways?.razorpay == true;
    final paypalActive = gateways?.paypal == true;
    final stripeActive = gateways?.stripe == true;
    final cashfreeActive = gateways?.cashfree == true;

    final options = <Map<String, dynamic>>[];
    if (googleActive) {
      options.add({'name': 'Google Play', 'type': 'google'});
    }
    if (razorpayActive) {
      options.add({'name': 'Razorpay', 'type': 'razorpay'});
    }
    if (cashfreeActive) {
      options.add({'name': 'Cashfree', 'type': 'cashfree'});
    }
    if (paypalActive) {
      options.add({'name': 'PayPal', 'type': 'paypal'});
    }
    if (stripeActive) {
      options.add({'name': 'Stripe', 'type': 'stripe'});
    }

    if (options.isEmpty) {
      controller.buyWithGooglePlay(p);
      return;
    }

    if (options.length == 1) {
      final type = options.first['type'];
      if (type == 'google') controller.buyWithGooglePlay(p);
      if (type == 'razorpay') controller.buyWithRazorpay(p);
      if (type == 'cashfree') controller.buyWithCashfree(p);
      if (type == 'paypal') controller.buyWithPaypal(p);
      if (type == 'stripe') controller.buyWithStripe(p);
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: ShapeDecoration(
          color: whitePure(context),
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.only(
              topLeft: SmoothRadius(cornerRadius: 18, cornerSmoothing: 1),
              topRight: SmoothRadius(cornerRadius: 18, cornerSmoothing: 1),
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.title ?? 'Plan',
                style: TextStyleCustom.unboundedMedium500(
                  fontSize: 16,
                  color: textDarkGrey(context),
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextButtonCustom(
                    onTap: () {
                      Get.back();
                      final type = opt['type'];
                      if (type == 'google') {
                        controller.buyWithGooglePlay(p);
                      } else if (type == 'razorpay') {
                        controller.buyWithRazorpay(p);
                      } else if (type == 'cashfree') {
                        controller.buyWithCashfree(p);
                      } else if (type == 'paypal') {
                        controller.buyWithPaypal(p);
                      } else if (type == 'stripe') {
                        controller.buyWithStripe(p);
                      }
                    },
                    title: opt['name'],
                    backgroundColor: opt['type'] == 'google'
                        ? themeAccentSolid(context)
                        : textDarkGrey(context),
                    titleColor: whitePure(context),
                    horizontalMargin: 0,
                    btnHeight: 44,
                  ),
                );
              }),
              const SizedBox(height: 4),
              TextButtonCustom(
                onTap: () => Get.back(),
                title: 'Cancel',
                backgroundColor: bgLightGrey(context),
                titleColor: textDarkGrey(context),
                horizontalMargin: 0,
                btnHeight: 44,
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  String _humanizeFeature(String raw) {
    final key = raw.trim();
    const map = {
      'verified_badge': 'Verified badge',
      'no_ads': 'No ads',
      'search_optimized': 'Search optimization',
      'exclusive_stickers': 'Exclusive stickers',
      'call_recording': 'Call recording',
      'custom_chat_theme': 'Custom chat themes',
      'featured_profile': 'Featured profile',
      'add_image_to_link': 'Add images to your links',
      'add_link_to_reel': 'Add links to Reels',
      'paid_calls_coins': 'Paid Calls / Coins',
      'vids_ai_free': 'AI videos free',
      'creator_plus_miner': 'Creator + Miner',
      'call_scheduling': 'Call scheduling',
      'ai_noise_suppression': 'AI noise suppression',
      'audio_mood_livestream': 'Audio mood livestream',
      'impersonation_protection': 'Impersonation protection',
      'mining_multiplier': 'Mining multiplier',
    };
    if (map.containsKey(key)) return map[key]!;
    return key.replaceAll('_', ' ');
  }

  String? _sectionFor(String raw) {
    final key = raw.trim();
    const verified = {'verified_badge'};
    const discovery = {
      'search_optimized',
      'featured_profile',
      'add_link_to_reel'
    };
    const engagement = {
      'add_image_to_link',
      'exclusive_stickers',
      'custom_chat_theme',
      'vids_ai_free',
      'creator_plus_miner',
      'mining_multiplier',
    };
    const calling = {
      'call_recording',
      'paid_calls_coins',
      'call_scheduling',
      'ai_noise_suppression'
    };
    const protection = {'impersonation_protection'};
    if (verified.contains(key)) return 'Verified badge';
    if (discovery.contains(key)) return 'Maximize discovery';
    if (engagement.contains(key)) return 'Drive engagement';
    if (calling.contains(key)) return 'Calling';
    if (protection.contains(key)) return 'Protect your brand';
    return null;
  }

  Widget _featureRow(BuildContext context, String rawKey, bool enabled) {
    final key = rawKey.trim();
    final parts = key.split(':');
    final label = parts.length >= 2
        ? '${_humanizeFeature(parts.first.trim())}: ${parts.sublist(1).join(':').trim()}'
        : _humanizeFeature(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled ? Icons.check : Icons.close,
            size: 18,
            color: enabled ? Colors.black : textLightGrey(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyleCustom.outFitRegular400(
                fontSize: 14,
                color: enabled ? textDarkGrey(context) : textLightGrey(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureSection(
      BuildContext context, String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyleCustom.unboundedMedium500(
              fontSize: 14,
              color: textDarkGrey(context),
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class BuildIconWithText extends StatelessWidget {
  final String icon;
  final String title;

  const BuildIconWithText({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(cornerRadius: 30),
            side: BorderSide(color: bgGrey(context))),
        color: bgMediumGrey(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            height: 22,
            width: 28,
            alignment: AlignmentDirectional.centerStart,
          ),
          Text(
            title,
            style: TextStyleCustom.outFitRegular400(
                fontSize: 15, color: textDarkGrey(context)),
          )
        ],
      ),
    );
  }
}
