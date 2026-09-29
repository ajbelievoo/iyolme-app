import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/privacy_policy_text.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/auth_screen/auth_screen_controller.dart';
import 'package:shortzz/screen/auth_screen/forget_password_sheet.dart';
import 'package:shortzz/screen/auth_screen/registration_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthScreenController());
    return Scaffold(
      backgroundColor: whitePure(context),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 44),
                // Original logo — as-is, no crop
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.scale(scale: v, child: child),
                  ),
                  child: Image.asset(
                    'assets/icons/app_splash_opt.png',
                    width: 190,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 36),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    LKey.signIn.tr,
                    style: TextStyleCustom.unboundedSemiBold600(
                      fontSize: 22,
                      color: textDarkGrey(context),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    LKey.toContinue.tr,
                    style: TextStyleCustom.outFitRegular400(
                      fontSize: 14,
                      color: textLightGrey(context),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                LoginSheetTextField(
                  hintText: LKey.enterYourEmail.tr,
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                ),
                const SizedBox(height: 12),
                LoginSheetTextField(
                  isPasswordField: true,
                  hintText: LKey.enterPassword.tr,
                  controller: controller.passwordController,
                  prefixIcon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: InkWell(
                    onTap: () {
                      Get.bottomSheet(const ForgetPasswordSheet(),
                              isScrollControlled: true)
                          .then((value) =>
                              controller.forgetEmailController.clear());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(LKey.forgetPassword.tr,
                          style: TextStyleCustom.outFitMedium500(
                              fontSize: 14,
                              color: ColorRes.blueFollow)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButtonCustom(
                  onTap: controller.onLogin,
                  title: LKey.logIn.tr,
                  btnHeight: 50,
                  radius: 12,
                  fontSize: 15,
                  backgroundColor: ColorRes.blueFollow,
                  titleColor: whitePure(context),
                  horizontalMargin: 0,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomDivider(
                        color: bgGrey(context), height: .5, width: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: Text(
                        LKey.continueWith.tr,
                        style: TextStyleCustom.outFitRegular400(
                            fontSize: 13, color: textLightGrey(context)),
                      ),
                    ),
                    CustomDivider(
                        color: bgGrey(context), height: .5, width: 80),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (Platform.isIOS) ...[
                      SocialBtn(
                          onTap: controller.onAppleTap,
                          icon: AssetRes.icApple),
                      const SizedBox(width: 16),
                    ],
                    SocialBtn(
                        onTap: controller.onGoogleTap,
                        icon: AssetRes.icGoogle),
                  ],
                ),
                const SizedBox(height: 28),
                InkWell(
                  onTap: () {
                    controller.fullNameController.clear();
                    controller.emailController.clear();
                    controller.passwordController.clear();
                    controller.confirmPassController.clear();
                    controller.referralCodeController.clear();
                    Get.to(() => const RegistrationScreen());
                  },
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bgGrey(context), width: 1.2),
                    ),
                    child: Text(
                      LKey.createAccountHere.tr,
                      style: TextStyleCustom.outFitSemiBold600(
                          color: textDarkGrey(context), fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                PrivacyPolicyText(
                  boldTextColor: textDarkGrey(context),
                  regularTextColor: textLightGrey(context),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginSheetTextField extends StatefulWidget {
  final bool isPasswordField;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  const LoginSheetTextField(
      {super.key,
      this.isPasswordField = false,
      required this.hintText,
      required this.controller,
      this.keyboardType,
      this.prefixIcon});

  @override
  State<LoginSheetTextField> createState() => _LoginSheetTextFieldState();
}

class _LoginSheetTextFieldState extends State<LoginSheetTextField> {
  bool isHide = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: 1),
        ),
        color: bgMediumGrey(context),
      ),
      child: TextField(
        controller: widget.controller,
        style: TextStyleCustom.outFitRegular400(
            color: textDarkGrey(context), fontSize: 15),
        onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
        obscureText: widget.isPasswordField && isHide,
        keyboardType: widget.keyboardType ?? TextInputType.text,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: TextStyleCustom.outFitRegular400(
              color: textLightGrey(context), fontSize: 15),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIconConstraints: const BoxConstraints(),
          prefixIcon: widget.prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, right: 10),
                  child: Icon(widget.prefixIcon,
                      size: 20, color: textLightGrey(context)),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(),
          suffixIcon: widget.isPasswordField
              ? InkWell(
                  onTap: () {
                    isHide = !isHide;
                    setState(() {});
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Image.asset(
                        isHide ? AssetRes.icEye : AssetRes.icHideEye,
                        height: 22,
                        width: 34,
                        color: textLightGrey(context),
                        key: UniqueKey()),
                  ),
                )
              : null,
        ),
        cursorColor: textDarkGrey(context),
      ),
    );
  }
}

class SocialBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;

  const SocialBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: whitePure(context),
          border: Border.all(color: bgGrey(context), width: 1.2),
        ),
        alignment: Alignment.center,
        child: Image.asset(icon, height: 26, width: 26),
      ),
    );
  }
}
