import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/screen/subscription_screen/subscription_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class VerificationCongratsScreen extends StatefulWidget {
  final String? planName;

  const VerificationCongratsScreen({
    super.key,
    this.planName,
  });

  @override
  State<VerificationCongratsScreen> createState() => _VerificationCongratsScreenState();
}

class _VerificationCongratsScreenState extends State<VerificationCongratsScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsLeft = 10;

  late final AnimationController _tickController;
  late final Animation<double> _tickScale;

  @override
  void initState() {
    super.initState();

    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _tickScale = CurvedAnimation(parent: _tickController, curve: Curves.elasticOut);
    _tickController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        _goBackToPlans();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  void _goBackToPlans() {
    // Clear popup state so it doesn't keep showing.
    SessionManager.instance.setVerificationState(status: -1, requestId: SessionManager.instance.getVerificationRequestId);
    Get.offAll(() => const SubscriptionScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _goBackToPlans,
                  child: Text(
                    'Skip',
                    style: TextStyleCustom.outFitMedium500(color: textLightGrey(context)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: StyleRes.themeGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: _tickScale,
                      child: Image.asset(
                        AssetRes.icBlueTick,
                        height: 58,
                        width: 58,
                        color: whitePure(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Congratulations',
                  style: TextStyleCustom.unboundedExtraBold800(
                    fontSize: 30,
                    color: textDarkGrey(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your account is now verified.',
                  style: TextStyleCustom.outFitRegular400(
                    fontSize: 15,
                    color: textLightGrey(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if ((widget.planName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Plan: ${widget.planName}',
                    style: TextStyleCustom.outFitRegular400(
                      fontSize: 13,
                      color: textLightGrey(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Redirecting to plans in $_secondsLeft sec',
                        style: TextStyleCustom.outFitMedium500(
                          fontSize: 14,
                          color: whitePure(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(whitePure(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
