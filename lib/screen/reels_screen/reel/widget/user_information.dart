import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:readmore/readmore.dart';
import 'package:shortzz/common/controller/follow_controller.dart';
import 'package:shortzz/common/controller/profile_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/audio_details_screen/audio_sheet.dart';
import 'package:shortzz/screen/hashtag_screen/hashtag_screen.dart';
import 'package:shortzz/screen/location_screen/location_screen.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/font_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class UserInformation extends StatelessWidget {
  final ReelController controller;

  const UserInformation({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UserInfoHeader(controller: controller),
          Obx(() {
            final Post p = controller.reelData.value;
            if (!p.isSponsored || (p.id ?? 0) < 0) {
              return const SizedBox();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                (p.sponsoredLabel ?? 'Sponsored'),
                style: TextStyleCustom.outFitLight300(
                    color: whitePure(context), opacity: .8, fontSize: 11),
              ),
            );
          }),
          const SizedBox(height: 2),
          UserStats(controller: controller),
          UserLocation(controller: controller),
          UserDescription(controller: controller),
          ReelSoundAttribution(controller: controller),
        ],
      ),
    );
  }
}

class UserInfoHeader extends StatelessWidget {
  const UserInfoHeader({required this.controller, super.key});

  final ReelController controller;

  @override
  Widget build(BuildContext context) {
    User? reelUser = controller.reelData.value.user;
    late ProfileController profileController;
    if (Get.isRegistered<ProfileController>(tag: '${reelUser?.id}')) {
      profileController = Get.find<ProfileController>(tag: '${reelUser?.id}');
      profileController.updateUser(reelUser);
    } else {
      profileController =
          Get.put(ProfileController(reelUser), tag: '${reelUser?.id}');
    }
    User? user = profileController.user;
    return Row(
      children: [
        InkWell(
          onTap: () => controller.onUserTap(user),
          child: FullNameWithBlueTick(
              username: user?.username,
              userId: user?.id?.toInt(),
              isVerify: user?.isVerify,
              fontColor: whitePure(context),
              fontSize: 14,
              iconSize: 18),
        ),
        FollowButton(controller: controller),
      ],
    );
  }
}

class FollowButton extends StatefulWidget {
  final ReelController controller;

  const FollowButton({super.key, required this.controller});

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  @override
  Widget build(BuildContext context) {
    final followController = Get.put(
        FollowController(widget.controller.reelData.value.user.obs),
        tag: '${widget.controller.reelData.value.userId}');
    RxBool isLoading = false.obs;
    return Obx(() {
      bool isFollow = followController.user.value?.isFollowing ?? false;
      if (followController.user.value?.id ==
          SessionManager.instance.getUserID()) {
        return const SizedBox();
      }
      return AnimatedOpacity(
        opacity: isFollow ? 0 : 1,
        duration: const Duration(milliseconds: 10),
        child: InkWell(
          onTap: isFollow
              ? () {}
              : () async {
                  isLoading.value = true;
                  await followController.followUnFollowUser();
                  await Future.delayed(const Duration(milliseconds: 100));
                  isLoading.value = false;
                },
          child: isLoading.value
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4.0, horizontal: 5),
                  child: CupertinoActivityIndicator(
                      radius: 8.5,
                      color: whitePure(context).withValues(alpha: .3)))
              : Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: ShapeDecoration(
                    shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(cornerRadius: 30),
                        side: BorderSide(
                            color: whitePure(context).withValues(alpha: .3)),
                        borderAlign: BorderAlign.inside),
                    color: whitePure(context).withValues(alpha: .05),
                  ),
                  child: Text(
                    LKey.follow.tr,
                    style: TextStyleCustom.outFitRegular400(
                        fontSize: 13, color: whitePure(context)),
                  ),
                ),
        ),
      );
    });
  }
}

class UserStats extends StatelessWidget {
  const UserStats({super.key, required this.controller});

  final ReelController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Post? reel = controller.reelData.value;
      num views = reel.views ?? 0;
      return Row(
        children: [
          Text(
            reel.id == -1
                ? DateFormat('dd MMM yyyy').format(DateTime.now())
                : (reel.createdAt ?? '').formatDate,
            style: TextStyleCustom.outFitLight300(
                color: whitePure(context), opacity: .8, fontSize: 11),
          ),
          if (views > 0)
            Row(
              children: [
                Container(
                  height: 3,
                  width: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                      color: whitePure(context).withValues(alpha: .8),
                      shape: BoxShape.circle),
                ),
                Text(
                  '${reel.views ?? '0'} ${LKey.views.tr}',
                  style: TextStyleCustom.outFitLight300(
                      color: whitePure(context), opacity: .8, fontSize: 11),
                ),
              ],
            )
        ],
      );
    });
  }
}

class UserLocation extends StatelessWidget {
  final ReelController controller;

  const UserLocation({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    Post reel = controller.reelData.value;
    if (reel.placeTitle == null) {
      return const SizedBox();
    }

    return InkWell(
      onTap: () {
        double? latitude = reel.placeLat?.toDouble();
        double? longitude = reel.placeLon?.toDouble();
        LatLng latLng = LatLng(latitude ?? 0.0, longitude ?? 0.0);
        Get.to(
            () => LocationScreen(
                latLng: latLng, placeTitle: reel.placeTitle ?? ''),
            preventDuplicates: false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Image.asset(
                AssetRes.icLocationPin,
                width: 13,
                height: 13,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(reel.placeTitle ?? '',
                    style: TextStyleCustom.outFitLight300(
                      color: whitePure(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UserDescription extends StatefulWidget {
  const UserDescription({super.key, required this.controller});

  final ReelController controller;

  @override
  State<UserDescription> createState() => _UserDescriptionState();
}

class _UserDescriptionState extends State<UserDescription> {
  ValueNotifier<bool> isCollapsed = ValueNotifier(true);

  @override
  Widget build(BuildContext context) {
    Post? reel = widget.controller.reelData.value;
    if (reel.description == null || (reel.description ?? '').isEmpty) {
      return const SizedBox();
    }
    return InkWell(
      onTap: () {
        isCollapsed.value = !isCollapsed.value;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: ReadMoreText(
                reel.descriptionWithUserName,
                style: TextStyleCustom.outFitLight300(
                    color: whitePure(context), opacity: .8, fontSize: 15),
                isCollapsed: isCollapsed,
                annotations: [
                  Annotation(
                    regExp: AppRes.hashTagRegex,
                    spanBuilder: (
                            {required String text, TextStyle? textStyle}) =>
                        TextSpan(
                            text: text,
                            style: textStyle?.copyWith(
                              color: whitePure(context).withValues(alpha: .8),
                              fontFamily: FontRes.outFitMedium500,
                              fontSize: 15,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                await Get.to(
                                    () =>
                                        HashtagScreen(hashtag: text, index: 0),
                                    preventDuplicates: false);
                              }),
                  ),
                  Annotation(
                    regExp: AppRes.userNameRegex,
                    spanBuilder: (
                        {required String text, TextStyle? textStyle}) {
                      return TextSpan(
                        text: text,
                        style: textStyle?.copyWith(
                            color: whitePure(context).withValues(alpha: .8),
                            fontFamily: FontRes.outFitMedium500,
                            fontSize: 15),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            User? user = widget
                                .controller.reelData.value.mentionedUsers
                                ?.firstWhereOrNull((element) {
                              return element.username ==
                                  text.replaceAll('@', '');
                            });
                            if (user != null) {
                              NavigationService.shared.openProfileScreen(user);
                            }
                          },
                      );
                    },
                  ),
                ],
                trimMode: TrimMode.Line,
                trimLines: 3,
                trimCollapsedText: ' ...',
                trimExpandedText: '   ',
                delimiter: '',
                moreStyle: TextStyleCustom.outFitLight300(
                    color: whitePure(context), opacity: .8, fontSize: 15),
                lessStyle: TextStyleCustom.outFitLight300(
                    color: whitePure(context), opacity: .8, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// HiTune sound attribution row on the reel overlay (strategy doc §5):
/// "Original Sound by @user on HiTune Music" + optional "AI Original" badge.
/// Tapping it opens the existing AudioSheet (which carries the
/// "Listen Full Song on HiTune" button).
class ReelSoundAttribution extends StatelessWidget {
  const ReelSoundAttribution({super.key, required this.controller});

  final ReelController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final post = controller.reelData.value;
      final music = post.music;
      final label = music?.attributionLabel ?? '';
      final title = music?.title ?? '';
      final text = label.isNotEmpty
          ? label
          : (title.isNotEmpty ? '♪ $title' : '');
      // Post-level fallback: reels pushed from HiTune carry ai_badge in
      // post.metadata even when no sound is attached (IYOLME_INTEGRATION.md §6).
      final aiBadge = (music?.aiBadge ?? '').isNotEmpty
          ? music!.aiBadge!
          : (post.hituneAiBadge ?? '');
      if ((text.isEmpty && aiBadge.isEmpty) ||
          (music?.hituneTakenDown ?? false)) {
        return const SizedBox();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: InkWell(
          onTap: music == null
              ? null
              : () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Get.bottomSheet(AudioSheet(music: music),
                      isScrollControlled: true);
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (text.isNotEmpty)
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyleCustom.outFitLight300(
                        color: whitePure(context), opacity: .85, fontSize: 12),
                  ),
                ),
              if (aiBadge.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    aiBadge,
                    style: TextStyleCustom.outFitMedium500(
                        fontSize: 9, color: const Color(0xFFC4B5FD)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
