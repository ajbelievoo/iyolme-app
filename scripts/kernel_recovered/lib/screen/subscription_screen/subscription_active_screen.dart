import 'package:flutter/material.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class SubscriptionActiveScreen extends StatelessWidget {
  final bool isExpired;
  final VoidCallback onRenew;
  final VoidCallback onUpgrade;

  const SubscriptionActiveScreen({
    super.key,
    required this.isExpired,
    required this.onRenew,
    required this.onUpgrade,
  });

  List<String> _benefitsFromSession() {
    final features = SessionManager.instance.getPlusFeatures;
    final out = <String>[];

    if (features != null) {
      features.forEach((k, v) {
        final key = k.toString().trim();
        if (key.isEmpty) return;
        final enabled = v == true || v == 1 || v == '1' || v == 'true';
        if (!enabled) return;
        out.add(key.replaceAll('_', ' '));
      });
    }

    final seen = <String>{};
    return out.where((e) => seen.add(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = SessionManager.instance.getPlusExpiresAt;
    final benefits = _benefitsFromSession();
    final bool isVerified = SessionManager.instance.isVerify.value == 1;
    final features = SessionManager.instance.getPlusFeatures;
    final bool requiresVerification = features != null && (features['verified_badge'] == true || features['verified_badge'] == 1 || features['verified_badge'] == '1');

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: StyleRes.themeGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isVerified
                          ? Image.asset(
                              AssetRes.icBlueTick,
                              height: 22,
                              width: 22,
                              color: whitePure(context),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpired
                              ? 'Plus is Expired'
                              : (requiresVerification && !isVerified
                                  ? 'Verification Required'
                                  : 'Plus is Active'),
                          style: TextStyleCustom.unboundedMedium500(
                            fontSize: 18,
                            color: textDarkGrey(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpired
                              ? (expiresAt == null || expiresAt.isEmpty
                                  ? 'Your plan has expired.'
                                  : 'Expired: $expiresAt')
                              : (requiresVerification && !isVerified
                                  ? 'Submit verification to unlock benefits'
                                  : (expiresAt == null || expiresAt.isEmpty
                                      ? 'Enjoy your benefits'
                                      : 'Expires: $expiresAt')),
                          style: TextStyleCustom.outFitRegular400(
                            fontSize: 13,
                            color: textLightGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!isExpired && requiresVerification && !isVerified)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgLightGrey(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: textLightGrey(context).withValues(alpha: .15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete verification',
                        style: TextStyleCustom.unboundedMedium500(
                          fontSize: 15,
                          color: textDarkGrey(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Until your verification is approved, premium features will remain locked.',
                        style: TextStyleCustom.outFitRegular400(color: textLightGrey(context)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: onUpgrade,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Submit verification',
                            style: TextStyleCustom.outFitSemiBold600(
                              fontSize: 15,
                              color: whitePure(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgLightGrey(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: textLightGrey(context).withValues(alpha: .15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your benefits',
                        style: TextStyleCustom.unboundedMedium500(
                          fontSize: 15,
                          color: textDarkGrey(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (benefits.isEmpty)
                        Text(
                          'Your subscription is active.',
                          style: TextStyleCustom.outFitRegular400(color: textLightGrey(context)),
                        )
                      else
                        ...benefits.map(
                          (b) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle, size: 18, color: Colors.black),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    b,
                                    style: TextStyleCustom.outFitRegular400(
                                      fontSize: 14,
                                      color: textDarkGrey(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const Spacer(),
              if (isExpired) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onRenew,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Renew',
                      style: TextStyleCustom.outFitSemiBold600(
                        fontSize: 15,
                        color: whitePure(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onUpgrade,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Upgrade',
                    style: TextStyleCustom.outFitSemiBold600(
                      fontSize: 15,
                      color: whitePure(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
