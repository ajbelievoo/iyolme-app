import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/screen/subscription_screen/subscription_screen.dart';
import 'package:shortzz/screen/verification_screen/verification_details_form_screen.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class VerificationRejectedScreen extends StatelessWidget {
  final String? reason;
  final String? planName;
  final int? subscriptionId;
  final String? paymentId;

  const VerificationRejectedScreen({
    super.key,
    this.reason,
    this.planName,
    this.subscriptionId,
    this.paymentId,
  });

  void _tryAgain() {
    SessionManager.instance.setVerificationState(status: -1, requestId: 0);
    Get.offAll(
      () => VerificationDetailsFormScreen(
        planName: planName,
        subscriptionId: subscriptionId,
        paymentId: paymentId,
      ),
    );
  }

  void _backToPlans() {
    Get.offAll(() => const SubscriptionScreen(forceShowPlans: true));
  }

  @override
  Widget build(BuildContext context) {
    final msg = (reason ?? '').trim().isEmpty ? 'Your verification request was rejected.' : (reason ?? '').trim();

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textDarkGrey(context)),
          onPressed: _backToPlans,
        ),
        title: Text(
          'Verification Rejected',
          style: TextStyleCustom.unboundedMedium500(color: textDarkGrey(context)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We couldn\'t verify your account.',
                style: TextStyleCustom.unboundedMedium500(
                  fontSize: 18,
                  color: textDarkGrey(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                msg,
                style: TextStyleCustom.outFitRegular400(color: textLightGrey(context)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _tryAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeAccentSolid(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyleCustom.outFitMedium500(color: whitePure(context)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _backToPlans,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: textLightGrey(context).withValues(alpha: .4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Back to plans',
                    style: TextStyleCustom.outFitMedium500(color: textDarkGrey(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
