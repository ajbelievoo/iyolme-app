import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/economy_state.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/share_manager.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/custom_popup_menu_button.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/edit_profile_screen/edit_profile_screen.dart';
import 'package:shortzz/screen/follow_following_screen/follow_following_screen.dart';
import 'package:shortzz/screen/level_screen/level_screen.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/widget/post_options_sheet.dart';
import 'package:shortzz/screen/profile_screen/widget/profile_preview_interactive_screen.dart';
import 'package:shortzz/screen/profile_screen/widget/user_link_sheet.dart';
import 'package:shortzz/common/service/hitune_auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shortzz/screen/professional_dashboard_screen/monetization_page.dart';
import 'package:shortzz/screen/professional_dashboard_screen/professional_dashboard_screen.dart';
import 'package:shortzz/screen/scratch_collect/asset_vault_screen.dart';
import 'package:shortzz/common/controller/professional_controller.dart';
import 'package:shortzz/screen/settings_screen/settings_screen.dart';
import 'package:shortzz/screen/subscription_screen/subscription_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ProfileUserHeader extends StatelessWidget {
  final ProfileScreenController controller;

  const ProfileUserHeader({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        User? user = controller.userData.value;
        bool isUserNotFound = controller.isUserNotFound.value;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Row 1: avatar + stats (exact IG layout)
              ProfilePhotoAndStatsRow(
                userNotFound: isUserNotFound,
                controller: controller,
                user: user,
                stats: [
                  StatItem(
                      value: user?.totalPostLikesCount ?? 0,
                      label: LKey.likes.tr),
                  StatItem(
                      value: user?.followerCount ?? 0,
                      label: LKey.followers.tr),
                  StatItem(
                      value: user?.followingCount ?? 0,
                      label: LKey.following.tr),
                ],
                onTap: (value) {
                  if (isUserNotFound) return;
                  switch (value) {
                    case 0:
                      break;
                    case 1:
                      user?.checkIsBlocked(() {
                        Get.to(() => FollowFollowingScreen(
                            type: FollowFollowingType.follower, user: user));
                      });
                      break;
                    case 2:
                      user?.checkIsBlocked(() {
                        Get.to(() => FollowFollowingScreen(
                            type: FollowFollowingType.following, user: user));
                      });
                      break;
                  }
                },
              ),
              const SizedBox(height: 12),
              if (!isUserNotFound) ...[
                UserNameView(user: user),
                UserBioView(user: user),
                UserLinkView(user: user),
                _BadgesRow(user: user),
                const SizedBox(height: 6),
                _ProDashboardCard(user: user),
                _HiTuneCard(user: user),
                UserButtonView(user: user, controller: controller),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Grey full-width "Professional dashboard" card like Instagram
class _ProDashboardCard extends StatelessWidget {
  final User? user;

  const _ProDashboardCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isMe = user?.id?.toInt() == SessionManager.instance.getUserID();
    if (!isMe) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: GestureDetector(
        onTap: () => Get.to(() => const ProfessionalDashboardScreen()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgMediumGrey(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Professional dashboard',
                style: TextStyleCustom.outFitSemiBold600(
                  color: textDarkGrey(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track views, earnings and insights',
                style: TextStyleCustom.outFitRegular400(
                  color: textLightGrey(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  final User? user;

  const _BadgesRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final isMe = user?.id?.toInt() == SessionManager.instance.getUserID();
    final hasLevel = user?.getLevel.id != null;
    if (!isMe && !hasLevel) {
      if (!hasLevel) return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (hasLevel)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    Get.to(() => LevelScreen(userLevels: user?.getLevel));
                  },
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: StyleRes.themeGradient,
                    ),
                    child: Center(
                      child: Text(
                        'LVL.${user?.getLevel.level ?? 1}',
                        style: TextStyleCustom.outFitBold700(
                          color: whitePure(context),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            _ProBadges(user: user),
          ],
        ),
      ),
    );
  }
}

class ProfilePhotoAndStatsRow extends StatelessWidget {
  final User? user;
  final List<StatItem> stats;
  final Function(int value) onTap;
  final ProfileScreenController controller;
  final bool userNotFound;

  const ProfilePhotoAndStatsRow({
    super.key,
    required this.user,
    required this.stats,
    required this.onTap,
    required this.controller,
    required this.userNotFound,
  });

  @override
  Widget build(BuildContext context) {
    bool isStoryAvailable = (user?.stories ?? []).isNotEmpty;
    GlobalKey previewKey = GlobalKey();
    bool isWatch = isStoryAvailable &&
        (user?.stories ?? []).every((element) => element.isWatchedByMe());
    RxBool isHeroEnable = false.obs;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile Picture with Instagram-style shadow and border
        if (userNotFound)
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: whitePure(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(AssetRes.icUserPlaceholder, fit: BoxFit.cover),
            ),
          )
        else
          GestureDetector(
            onTap: () => controller.onStoryTap(isStoryAvailable),
            onLongPressStart: (details) {
              isHeroEnable.value = true;
            },
            onLongPressEnd: (details) {
              isHeroEnable.value = false;
            },
            onLongPress: () {
              user?.checkIsBlocked(() {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.transparent,
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) =>
                          ProfilePreviewInteractiveScreen(user: user)),
                );
              });
            },
            child: Stack(
              children: [
                Container(
                  key: previewKey,
                  width: 90,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isStoryAvailable
                        ? (isWatch
                            ? StyleRes.disabledGreyGradient(opacity: .5)
                            : StyleRes.themeGradient)
                        : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: whitePure(context),
                    ),
                    child: Obx(
                      () => HeroMode(
                        enabled: isHeroEnable.value,
                        child: Hero(
                          tag: 'profile-${user?.id}',
                          child: CustomImage(
                            size: const Size(84, 84),
                            image: user?.isBlock == true
                                ? ''
                                : user?.profilePhoto?.addBaseURL(),
                            fullName: user?.fullname,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // IG-style "+" badge on own profile avatar
                if (user?.id?.toInt() == SessionManager.instance.getUserID())
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: GestureDetector(
                      onTap: () => Get.bottomSheet(PostOptionsSheet(controller: controller, showProfilePicOption: true), isScrollControlled: true),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ColorRes.blueFollow,
                          border:
                              Border.all(color: whitePure(context), width: 2.5),
                        ),
                        child: const Icon(Icons.add,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(width: 24),
        // Stats Columns with Instagram-style layout
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  stats.length,
                  (index) => Expanded(
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: StatColumn(
                          value: stats[index].value, label: stats[index].label),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  final User? user;
  final List<StatItem> stats;
  final Function(int value) onTap;
  final ProfileScreenController controller;
  final bool userNotFound;

  const ProfileStatsRow({
    super.key,
    required this.user,
    required this.stats,
    required this.onTap,
    required this.controller,
    required this.userNotFound,
  });

  @override
  Widget build(BuildContext context) {
    bool isStoryAvailable = (user?.stories ?? []).isNotEmpty;
    GlobalKey previewKey = GlobalKey();
    bool isWatch = isStoryAvailable &&
        (user?.stories ?? []).every((element) => element.isWatchedByMe());
    RxBool isHeroEnable = false.obs;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile Picture with Instagram-style shadow and border
        if (userNotFound)
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: whitePure(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(AssetRes.icUserPlaceholder, fit: BoxFit.cover),
            ),
          )
        else
          GestureDetector(
            onTap: () => controller.onStoryTap(isStoryAvailable),
            onLongPressStart: (details) {
              isHeroEnable.value = true;
            },
            onLongPressEnd: (details) {
              isHeroEnable.value = false;
            },
            onLongPress: () {
              user?.checkIsBlocked(() {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.transparent,
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) =>
                          ProfilePreviewInteractiveScreen(user: user)),
                );
              });
            },
            child: Stack(
              children: [
                Container(
                  key: previewKey,
                  width: 90,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isStoryAvailable
                        ? (isWatch
                            ? StyleRes.disabledGreyGradient(opacity: .5)
                            : StyleRes.themeGradient)
                        : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: whitePure(context),
                    ),
                    child: Obx(
                      () => HeroMode(
                        enabled: isHeroEnable.value,
                        child: Hero(
                          tag: 'profile-${user?.id}',
                          child: CustomImage(
                            size: const Size(84, 84),
                            image: user?.isBlock == true
                                ? ''
                                : user?.profilePhoto?.addBaseURL(),
                            fullName: user?.fullname,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // IG-style "+" badge on own profile avatar
                if (user?.id?.toInt() == SessionManager.instance.getUserID())
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: GestureDetector(
                      onTap: () => Get.bottomSheet(PostOptionsSheet(controller: controller, showProfilePicOption: true), isScrollControlled: true),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ColorRes.blueFollow,
                          border:
                              Border.all(color: whitePure(context), width: 2.5),
                        ),
                        child: const Icon(Icons.add,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(width: 24),
        // Stats Columns with Instagram-style layout
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  stats.length,
                  (index) => Expanded(
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: StatColumn(
                          value: stats[index].value, label: stats[index].label),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Individual Stat Column Widget
class StatColumn extends StatelessWidget {
  final num value;
  final String label;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const StatColumn(
      {super.key,
      required this.value,
      required this.label,
      this.labelStyle,
      this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.toInt().numberFormat,
          style: valueStyle ??
              TextStyleCustom.unboundedSemiBold600(
                color: textDarkGrey(context),
                fontSize: 16,
              ),
        ),
        const SizedBox(height: 2),
        Text(label.capitalize ?? '',
            style: labelStyle ??
                TextStyleCustom.outFitMedium500(
                  color: textLightGrey(context),
                  fontSize: 12,
                )),
      ],
    );
  }
}

class UserNameView extends StatelessWidget {
  final User? user;

  const UserNameView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((user?.fullname ?? '').isNotEmpty)
          Text(
            user?.fullname ?? '',
            style: TextStyleCustom.unboundedSemiBold600(
              color: textDarkGrey(context),
              fontSize: 15,
            ),
          ),
        if ((user?.fullname ?? '').isNotEmpty) const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: FullNameWithBlueTick(
                userId: user?.id,
                username: user?.username ?? '',
                isVerify: user?.isVerify,
                fontSize: 14,
                iconSize: 15,
                fontColor: textLightGrey(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class UserLinkView extends StatelessWidget {
  final User? user;

  const UserLinkView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    List<Link> links = user?.links ?? [];
    if (links.isNotEmpty) {
      return InkWell(
        onTap: () {
          user?.checkIsBlocked(() {
            if (links.length > 1) {
              Get.bottomSheet(UserLinkSheet(links: links),
                  isScrollControlled: true,
                  barrierColor: blackPure(context).withValues(alpha: .7));
            } else {
              (links.first.url ?? '').lunchUrlWithHttps;
            }
          });
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AssetRes.icLink,
                height: 20, width: 20, color: themeAccentSolid(context)),
            const SizedBox(width: 3),
            Expanded(
              child: Text(shortUrl,
                  style: TextStyleCustom.outFitRegular400(
                      fontSize: 15, color: themeAccentSolid(context))),
            )
          ],
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  String get shortUrl {
    List<Link> links = user?.links ?? [];
    String firstLink = links.first.url ?? '';
    String andMore = '';
    if (firstLink.length >= 40) {
      int endCount = links.length > 1 ? 25 : 35;
      firstLink = '${firstLink.substring(0, endCount)}...';
    }
    if (links.length > 1) {
      andMore = ' & ${links.length - 1} ${LKey.more.tr.toLowerCase()}';
    }
    return '$firstLink$andMore';
  }
}

class UserBioView extends StatelessWidget {
  final User? user;

  const UserBioView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if ((user?.bio ?? '').isEmpty) {
      return const SizedBox();
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Text(
        user?.bio ?? '',
        style: TextStyleCustom.outFitMedium500(
          color: textDarkGrey(context),
          fontSize: 13,
        ),
      ),
    );
  }
}

class UserButtonView extends StatelessWidget {
  final User? user;
  final ProfileScreenController controller;

  const UserButtonView(
      {super.key, required this.user, required this.controller});

  @override
  Widget build(BuildContext context) {
    User? user = controller.profileController.user;

    bool isMe = user?.id?.toInt() == SessionManager.instance.getUserID();
    bool isBlock = (user?.isBlock == true &&
        user?.id != SessionManager.instance.getUserID());
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
            child: isBlock
                ? UnblockButton(
                    onTap: () => controller.toggleBlockUnblock(true))
                : (isMe
                    ? _MeActionButtons(
                        controller: controller, user: user, isMe: isMe)
                    : RowButton(
                        controller: controller, isMe: isMe, user: user)),
          ),
          const SizedBox(width: 12),
          if (isMe) ...[
            // Settings Button
            Container(
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: bgGrey(context),
              ),
              child: IconButton(
                onPressed: () {
                  Get.to(() => const SettingsScreen());
                },
                icon: Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: textDarkGrey(context),
                ),
              ),
            ),
          ] else
            Obx(
              () => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: bgGrey(context),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CustomPopupMenuButton(
                  items: [
                    MenuItem(
                        user?.isBlock == true ? LKey.unBlock.tr : LKey.block.tr,
                        () {
                      controller.toggleBlockUnblock(user?.isBlock ?? false);
                    }),
                    MenuItem(LKey.report.tr, () => controller.reportUser(user)),
                    if (SessionManager.instance.isModerator.value == 1)
                      MenuItem(
                          user?.isFreez == 1
                              ? LKey.unFreeze.tr
                              : LKey.freeze.tr,
                          () =>
                              controller.freezeUnfreezeUser(user?.isFreez == 1))
                  ],
                  child: IconButton(
                    onPressed: () {},
                    icon: Image.asset(
                      AssetRes.icMore,
                      height: 20,
                      width: 20,
                      color: textDarkGrey(context),
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

/// "HiTune Music" relationship card on the user's own profile — shows the
/// linked HiTune account and opens the HiTune app/site, or starts the
/// link flow ("Continue with HiTune") when not connected yet.
class _HiTuneCard extends StatelessWidget {
  final User? user;

  const _HiTuneCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isMe = user?.id?.toInt() == SessionManager.instance.getUserID();
    if (!isMe) return const SizedBox.shrink();

    final linked = (user?.hituneSub ?? '').isNotEmpty;
    final htName = user?.hituneUsername ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (linked) {
              launchUrl(Uri.parse('https://music.hitune.in/'),
                  mode: LaunchMode.externalApplication);
            } else {
              HituneAuthService.shared.startLogin();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0FA8D4).withValues(alpha: 0.16),
                  const Color(0xFFE56BD8).withValues(alpha: 0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: themeAccentSolid(context).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: whitePure(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Image.asset(AssetRes.icMusic,
                        width: 20, height: 20, color: themeAccentSolid(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HiTune Music',
                          style: TextStyleCustom.outFitSemiBold600(
                              color: textDarkGrey(context), fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        linked
                            ? 'Connected · @${htName.isNotEmpty ? htName : 'hitune'}'
                            : 'Link HiTune — use your songs in reels',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyleCustom.outFitRegular400(
                            color: linked
                                ? Colors.green
                                : textLightGrey(context),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  linked ? Icons.open_in_new : Icons.link,
                  size: 18,
                  color: textLightGrey(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeActionButtons extends StatelessWidget {
  final ProfileScreenController controller;
  final User? user;
  final bool isMe;

  const _MeActionButtons(
      {required this.controller, required this.user, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextButtonCustom(
              onTap: () => Get.to(() =>
                  EditProfileScreen(onUpdateUser: controller.onUpdateUser)),
              title: LKey.editProfile.tr,
              fontSize: 14,
              backgroundColor: bgGrey(context),
              titleColor: textDarkGrey(context),
              horizontalMargin: 0,
              btnHeight: 38),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextButtonCustom(
            onTap: () {
              ShareManager.shared
                  .showCustomShareSheet(user: user, keys: ShareKeys.user);
            },
            title: LKey.share.tr,
            fontSize: 14,
            btnHeight: 38,
            backgroundColor: bgGrey(context),
            titleColor: textDarkGrey(context),
            horizontalMargin: 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextButtonCustom(
            onTap: () => Get.to(() =>
                SubscriptionScreen(onUpdateUser: controller.onUpdateUser)),
            title: 'Subscription',
            fontSize: 11,
            btnHeight: 38,
            backgroundColor: bgGrey(context),
            titleColor: textDarkGrey(context),
            horizontalMargin: 0,
          ),
        ),
      ],
    );
  }
}

class _ProBadges extends StatelessWidget {
  final User? user;

  const _ProBadges({required this.user});

  @override
  Widget build(BuildContext context) {
    final isMe = user?.id?.toInt() == SessionManager.instance.getUserID();
    if (!isMe) {
      return const SizedBox();
    }

    final ProfessionalController proCtrl =
        Get.isRegistered<ProfessionalController>()
            ? Get.find<ProfessionalController>()
            : Get.put(ProfessionalController());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vault Button - New
        GestureDetector(
          onTap: () {
            AssetVaultScreen.open();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 16, color: Colors.purple.shade700),
                const SizedBox(width: 6),
                Text(
                  'Vault',
                  style: TextStyleCustom.outFitSemiBold600(
                    fontSize: 12,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(() {
          final enabled = (proCtrl.stats.value?.professionalEnabled ?? false) ||
              proCtrl.localProfessionalEnabled.value;
          if (!enabled) {
            return const SizedBox();
          }
          return GestureDetector(
            onTap: () {
              Get.to(() => const ProfessionalDashboardScreen());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_outlined,
                      size: 16, color: textDarkGrey(context)),
                  const SizedBox(width: 6),
                  Text(
                    'Dashboard',
                    style: TextStyleCustom.outFitSemiBold600(
                      fontSize: 12,
                      color: textDarkGrey(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        Obx(() {
          final status = EconomyState.instance.monetizationStatus.value;
          final isMonetized = status == 'approved';
          if (!isMonetized) {
            return const SizedBox();
          }
          return GestureDetector(
            onTap: () {
              Get.to(() => const MonetizationPage());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.currency_rupee,
                      size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Earn',
                    style: TextStyleCustom.outFitSemiBold600(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class NoUserFoundButton extends StatelessWidget {
  const NoUserFoundButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButtonCustom(
      onTap: () {},
      title: LKey.userNotFound.tr,
      btnHeight: 40,
      backgroundColor: bgMediumGrey(context),
      fontSize: 15,
      radius: 8,
      titleColor: textLightGrey(context),
      margin: const EdgeInsets.only(bottom: 10, left: 40, right: 40, top: 20),
    );
  }
}

class UnblockButton extends StatelessWidget {
  final VoidCallback onTap;

  const UnblockButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButtonCustom(
      onTap: onTap,
      title: LKey.unBlock.tr,
      fontSize: 16,
      backgroundColor: blueFollow(context),
      titleColor: whitePure(context),
      horizontalMargin: 0,
      btnHeight: 45,
    );
  }
}

class RowButton extends StatelessWidget {
  final bool isMe;
  final ProfileScreenController controller;
  final User? user;

  const RowButton({
    super.key,
    required this.isMe,
    required this.controller,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Become Plus Button
        if (isMe) ...[
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: bgGrey(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: textLightGrey(context).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Get.to(() => SubscriptionScreen(
                      onUpdateUser: controller.onUpdateUser)),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add,
                          size: 16,
                          color: textDarkGrey(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Plus+',
                          style: TextStyleCustom.outFitSemiBold600(
                            color: textDarkGrey(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Follow/Unfollow Button for others
        if (!isMe)
          Expanded(
            child: Obx(
              () {
                bool isFollowProgress =
                    controller.isFollowUnFollowInProcess.value;
                Color textColor = user?.isFollowing == true
                    ? textDarkGrey(context)
                    : whitePure(context);
                return Container(
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: user?.isFollowing == true
                        ? whitePure(context)
                        : blueFollow(context),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: user?.isFollowing == true
                        ? Border.all(
                            color:
                                textLightGrey(context).withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        if (!isFollowProgress) {
                          controller.followUnFollowUser();
                        }
                      },
                      child: Center(
                        child: isFollowProgress
                            ? CupertinoActivityIndicator(
                                radius: 8,
                                color: textColor,
                              )
                            : Text(
                                user?.isFollowing == true
                                    ? LKey.unFollow.tr
                                    : LKey.follow.tr,
                                style: TextStyleCustom.outFitSemiBold600(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        const SizedBox(width: 8),

        // Publish/Message Button
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: bgGrey(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: textLightGrey(context).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => controller.handlePublishOrMessageBtn(isMe),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isMe) ...[
                        Icon(
                          Icons.add,
                          size: 16,
                          color: textDarkGrey(context),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        isMe ? Icons.send_outlined : Icons.message_outlined,
                        size: 16,
                        color: textDarkGrey(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMe ? LKey.publish.tr : LKey.message.tr,
                        style: TextStyleCustom.outFitSemiBold600(
                          color: textDarkGrey(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Stat Item Model
class StatItem {
  final num value;
  final String label;

  StatItem({required this.value, required this.label});
}
