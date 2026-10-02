import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_app_bar.dart';
import 'package:shortzz/common/widget/custom_drop_down.dart';
import 'package:shortzz/common/widget/custom_toggle.dart';
import 'package:shortzz/common/controller/smart_assist_controller.dart';
import 'package:shortzz/common/service/hitune_auth_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/blocked_user_screen/blocked_user_screen.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen.dart';
import 'package:shortzz/screen/edit_profile_screen/edit_profile_screen.dart';
import 'package:shortzz/screen/qr_code_screen/qr_code_screen.dart';
import 'package:shortzz/screen/referral_screen/referral_screen.dart';
import 'package:shortzz/screen/saved_post_screen/saved_post_screen.dart';
import 'package:shortzz/screen/select_language_screen/select_language_screen.dart';
import 'package:shortzz/screen/settings_screen/settings_screen_controller.dart';
import 'package:shortzz/screen/settings_screen/widget/notifications_page.dart';
import 'package:shortzz/screen/term_and_privacy_screen/term_and_privacy_screen.dart';
import 'package:shortzz/screen/professional_dashboard_screen/professional_dashboard_screen.dart';
import 'package:shortzz/screen/professional_dashboard_screen/enable_professional_screen.dart';
import 'package:shortzz/screen/professional_dashboard_screen/monetization_page.dart';
import 'package:shortzz/screen/paid_calls_settings_screen/paid_calls_settings_screen.dart';
import 'package:shortzz/common/controller/professional_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class SettingsScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;

  const SettingsScreen({super.key, this.onUpdateUser});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsScreenController());
    final smartCtrl = Get.isRegistered<SmartAssistController>()
        ? Get.find<SmartAssistController>()
        : Get.put(SmartAssistController(), permanent: true);
    final proCtrl = Get.isRegistered<ProfessionalController>()
        ? Get.find<ProfessionalController>()
        : Get.put(ProfessionalController());
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      body: Column(
        children: [
          CustomAppBar(title: LKey.settings.tr),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: AppBar().preferredSize.height),
              child: Column(
                children: [
                  // Personal Section
                  SettingSection(title: LKey.personal.toUpperCase()),
                  SettingItem(
                    icon: AssetRes.icEdit,
                    title: LKey.editProfile,
                    onTap: () {
                      Get.to(() => EditProfileScreen(onUpdateUser: onUpdateUser));
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icPostBookmark,
                    title: LKey.savedPosts,
                    onTap: () {
                      Get.to(() => const SavedPostScreen());
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icLanguage_1,
                    title: LKey.languages,
                    onTap: () {
                      Get.to(() => const SelectLanguageScreen(
                          languageNavigationType:
                              LanguageNavigationType.fromSetting));
                    },
                  ),
                  // Conditional Professional menu
                  Obx(() {
                    final enabled = (proCtrl.stats.value?.professionalEnabled ?? false) ||
                        proCtrl.localProfessionalEnabled.value;
                    return SettingItem(
                      icon: AssetRes.icPro,
                      title: enabled ? 'Professional Dashboard' : 'Enable Professional',
                      onTap: () {
                        if (enabled) {
                          Get.to(() => const ProfessionalDashboardScreen());
                        } else {
                          Get.to(() => EnableProfessionalScreen(controller: proCtrl));
                        }
                      },
                    );
                  }),
                  Obx(() {
                    final enabled = (proCtrl.stats.value?.professionalEnabled ?? false) ||
                        proCtrl.localProfessionalEnabled.value;
                    if (!enabled) return const SizedBox.shrink();
                    return SettingItem(
                      icon: AssetRes.icPro,
                      title: 'Monetization',
                      onTap: () {
                        Get.to(() => const MonetizationPage());
                      },
                    );
                  }),
                  SettingItem(
                    icon: AssetRes.icBlock,
                    title: LKey.blockedUsers,
                    onTap: () {
                      Get.to(() => const BlockedUserScreen());
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icQrCode_1,
                    title: LKey.myQrCode,
                    onTap: () {
                      Get.to(() => const QrCodeScreen());
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icShare,
                    title: LKey.inviteFriends,
                    onTap: () {
                      Get.to(() => const ReferralScreen());
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icWallet,
                    title: LKey.coinWallet,
                    onTap: () {
                      Get.to(() => const CoinWalletScreen());
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icPro,
                    title: LKey.paidCalls,
                    onTap: () {
                      Get.to(() => const PaidCallsSettingsScreen());
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icPro,
                    title: 'Levels',
                    onTap: () {
                      // Get.to(() => LevelScreen(userLevels: SessionManager.instance.user.value?.getLevel));
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Privacy Section
                  SettingSection(title: LKey.privacy.toUpperCase()),
                  Obx(
                    () => SettingItem(
                      icon: AssetRes.icEye_1,
                      title: LKey.whoCanSeePosts,
                      widget: CustomDropDownBtn<WhoCanSeePost>(
                        items: WhoCanSeePost.values,
                        onChanged: controller.isUpdateApiCalled.value
                            ? null
                            : controller.onChangedWhoCanSeePost,
                        selectedValue: controller.selectedWhoCanSeePost.value,
                        style: TextStyleCustom.outFitRegular400(
                            fontSize: 15, color: textLightGrey(context)),
                        getTitle: (value) => value.title,
                      ),
                    ),
                  ),
                  Obx(
                    () {
                      return SettingItem(
                        icon: AssetRes.icEye_1,
                        title: LKey.showMyFollowings,
                        widget: CustomToggle(
                          isOn: (controller.myUser.value?.showMyFollowing == 1).obs,
                          onChanged: (value) {
                            controller.onChangedToggle(
                                value, SettingToggle.showMyFollowings);
                          },
                        ),
                      );
                    },
                  ),
                  Obx(
                    () {
                      return SettingItem(
                        icon: AssetRes.icMessage,
                        title: LKey.showChatBtn,
                        widget: CustomToggle(
                          isOn: (controller.myUser.value?.receiveMessage == 1).obs,
                          onChanged: (value) async {
                            controller.onChangedToggle(
                                value, SettingToggle.receiveMessage);
                          },
                        ),
                      );
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icNotification_1,
                    title: LKey.notifications,
                    onTap: () {
                      Get.to(() => const NotificationsPage());
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // General Section
                  SettingSection(title: LKey.general.toUpperCase()),
                  SettingItem(
                    icon: AssetRes.icStar,
                    title: 'Smart Suggestions',
                    widget: CustomToggle(
                      isOn: smartCtrl.smartSuggestionsEnabled,
                      onChanged: (value) async {
                        await smartCtrl.setSmartSuggestionsEnabled(value);
                      },
                    ),
                  ),
                  Obx(() {
                    final enabled = smartCtrl.smartSuggestionsEnabled.value;
                    return SettingItem(
                      icon: AssetRes.icStar,
                      title: 'Voice Commands',
                      widget: Opacity(
                        opacity: enabled ? 1 : 0.4,
                        child: CustomToggle(
                          isOn: smartCtrl.voiceCommandsEnabled,
                          onChanged: enabled
                              ? (value) async {
                                  await smartCtrl.setVoiceCommandsEnabled(value);
                                }
                              : null,
                        ),
                      ),
                    );
                  }),
                  SettingItem(
                    icon: AssetRes.icReport,
                    title: LKey.termsOfUse,
                    onTap: () {
                      Get.to(() => const TermAndPrivacyScreen(
                          type: TermAndPrivacyType.termAndCondition));
                    },
                  ),
                  SettingItem(
                    icon: AssetRes.icReport,
                    title: LKey.privacyPolicy,
                    onTap: () {
                      Get.to(() => const TermAndPrivacyScreen(
                          type: TermAndPrivacyType.privacyPolicy));
                    },
                  ),

                  // Accounts section — Instagram-style multi-account switcher
                  SettingSection(title: 'ACCOUNTS'),
                  SettingItem(
                    icon: AssetRes.icProfile,
                    title: 'Switch Account',
                    onTap: controller.showAccountSwitcher,
                  ),
                  Obx(() {
                    final u = controller.myUser.value;
                    final linked = (u?.hituneSub ?? '').isNotEmpty;
                    return SettingItem(
                      icon: AssetRes.icMusic,
                      title: linked
                          ? 'HiTune: @${u?.hituneUsername ?? 'linked'}'
                          : 'Link HiTune Account',
                      onTap: linked
                          ? null
                          : () => HituneAuthService.shared.startLink(),
                      widget: linked
                          ? Icon(Icons.check_circle,
                              color: Colors.green.withValues(alpha: 0.9),
                              size: 20)
                          : null,
                    );
                  }),
                  SettingItem(
                    icon: AssetRes.icLogout,
                    title: LKey.logOut,
                    onTap: controller.onLogout,
                    isDestructive: true,
                  ),
                  SettingItem(
                    icon: AssetRes.icDelete2,
                    title: LKey.deleteAccount,
                    onTap: controller.onDeleteAccount,
                    isDestructive: true,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Modern Setting Section
class SettingSection extends StatelessWidget {
  final String title;

  const SettingSection({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        title,
        style: TextStyleCustom.outFitSemiBold600(
          color: textLightGrey(context),
          fontSize: 13,
        ).copyWith(letterSpacing: 1.5),
      ),
    );
  }
}

// Modern Setting Item
class SettingItem extends StatelessWidget {
  final String icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? widget;
  final bool isDestructive;

  const SettingItem({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.widget,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: whitePure(context).withValues(alpha: 0.05),
        border: Border.all(
          color: whitePure(context).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDestructive
                        ? Colors.red.withValues(alpha: 0.1)
                        : themeAccentSolid(context).withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Image.asset(
                      icon,
                      width: 20,
                      height: 20,
                      color: isDestructive
                          ? Colors.red.withValues(alpha: 0.8)
                          : themeAccentSolid(context),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyleCustom.outFitMedium500(
                      color: isDestructive
                          ? Colors.red.withValues(alpha: 0.8)
                          : textDarkGrey(context),
                      fontSize: 16,
                    ),
                  ),
                ),
                if (widget != null)
                  widget!
                else
                  Icon(
                    Icons.chevron_right,
                    color: textLightGrey(context).withValues(alpha: 0.5),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
