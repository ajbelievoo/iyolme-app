import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/custom_search_text_field.dart';
import 'package:shortzz/common/widget/custom_tab_switcher.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/widget/live_stream_user_info_sheet.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class MembersSheet extends StatefulWidget {
  final bool isHost;

  const MembersSheet({super.key, required this.isHost});

  @override
  State<MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<MembersSheet> {
  LivestreamScreenController? controller;
  final PageController pageController = PageController(initialPage: 0);
  final RxInt selectedTab = 0.obs;

  void onSelectedTab(int index) {
    selectedTab.value = index;
    pageController.animateToPage(index,
        duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<LivestreamScreenController>()) {
      controller = Get.find<LivestreamScreenController>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) return const SizedBox();
    final isPrivileged = widget.isHost ||
        ((c.liveData.value.coHostIds ?? const <int>[]).contains(c.myUserId));
    return Container(
      margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
      decoration: ShapeDecoration(
        color: whitePure(context),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)),
        ),
      ),
      child: Obx(() {
        return Column(
          children: [
            BottomSheetTopView(
                title: LKey.members.tr, sideBtnVisibility: false),
            if (isPrivileged)
              CustomTabSwitcher(
                items: [
                  LKey.requests.tr,
                  LKey.audience.tr,
                  LKey.invited.tr,
                  LKey.coHosts.tr
                ],
                onTap: onSelectedTab,
                selectedIndex: selectedTab,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: bgLightGrey(context),
                selectedFontColor: themeAccentSolid(context),
              ),
            Obx(() => (selectedTab.value == 2 || selectedTab.value == 3)
                ? const SizedBox()
                : CustomSearchTextField(
                    backgroundColor: bgLightGrey(context),
                    onChanged: (value) {
                      DebounceAction.shared.call(() {
                        List<LivestreamUserState> itemList = [];
                        itemList =
                            c.liveUsersStates.search(value, (p0) {
                          AppUser? data =
                              p0.getUser(c.firestoreController.users);
                          return data?.username ?? '';
                        }, (p1) {
                          AppUser? data =
                              p1.getUser(c.firestoreController.users);
                          return data?.fullname ?? '';
                        });
                        if (isPrivileged) {
                          if (selectedTab.value == 0) {
                            c.requestList.value = itemList
                                .where((element) =>
                                    element.type ==
                                    LivestreamUserType.requested)
                                .toList();
                          } else if (selectedTab.value == 1) {
                            c.audienceList.value = itemList
                                .where((element) =>
                                    element.type != LivestreamUserType.host &&
                                    element.type != LivestreamUserType.left)
                                .toList();
                          }
                        } else {
                          c.audienceMemberList.value = itemList
                              .where((element) =>
                                  element.type != LivestreamUserType.left)
                              .toList();
                        }
                      }, milliseconds: 500);
                    },
                  )),
            Expanded(
              child: !isPrivileged
                  ? NoDataView(
                      showShow: c.audienceMemberList.isEmpty,
                      title: LKey.userListEmptyTitle.tr,
                      description: LKey.userListEmptyDescription.tr,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: c.audienceMemberList.length,
                        itemBuilder: (context, index) {
                          final state = c.audienceMemberList[index];
                          final user = c.firestoreController.users
                              .firstWhereOrNull(
                                  (element) => element.userId == state.userId);
                          final bool isInvited =
                              state.type == LivestreamUserType.invited;
                          return MemberProfileCard(
                              user: user,
                              widget:
                                  _buildActionWidget(state, user, isInvited),
                              onTap: () {
                                if (user == null) return;
                                Get.back();
                                Get.bottomSheet(
                                  LiveStreamUserInfoSheet(
                                    isAudience: !widget.isHost,
                                    liveUser: user,
                                    controller: c,
                                  ),
                                  isScrollControlled: true,
                                );
                              });
                        },
                      ),
                    )
                  : PageView(
                      controller: pageController,
                      onPageChanged: (value) {
                        selectedTab.value = value;
                      },
                      children: [
                        NoDataView(
                          showShow: c.requestList.isEmpty,
                          title: LKey.requestTitle.tr,
                          description: LKey.requestDescription.tr,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: c.requestList.length,
                            itemBuilder: (context, index) {
                              final state = c.requestList[index];
                              final user = c.firestoreController.users
                                  .firstWhereOrNull((element) =>
                                      element.userId == state.userId);
                              final bool isInvited =
                                  state.type == LivestreamUserType.invited;
                              return MemberProfileCard(
                                user: user,
                                widget:
                                    _buildActionWidget(state, user, isInvited),
                                onTap: () {
                                  if (user == null) return;
                                  Get.back();
                                  Get.bottomSheet(
                                    LiveStreamUserInfoSheet(
                                      isAudience: !widget.isHost,
                                      liveUser: user,
                                      controller: c,
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        NoDataView(
                          showShow: c.audienceList.isEmpty,
                          title: LKey.audienceListEmptyTitle.tr,
                          description: LKey.audienceListEmptyDescription.tr,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: c.audienceList.length,
                            itemBuilder: (context, index) {
                              final state = c.audienceList[index];
                              final user = c.firestoreController.users
                                  .firstWhereOrNull((element) =>
                                      element.userId == state.userId);
                              final bool isInvited =
                                  state.type == LivestreamUserType.invited;
                              return MemberProfileCard(
                                user: user,
                                widget:
                                    _buildActionWidget(state, user, isInvited),
                                onTap: () {
                                  if (user == null) return;
                                  Get.back();
                                  Get.bottomSheet(
                                    LiveStreamUserInfoSheet(
                                      isAudience: !widget.isHost,
                                      liveUser: user,
                                      controller: c,
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        NoDataView(
                          showShow: c.invitedList.isEmpty,
                          title: LKey.invitedListEmptyTitle.tr,
                          description: LKey.invitedListEmptyDescription.tr,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: c.invitedList.length,
                            itemBuilder: (context, index) {
                              final state = c.invitedList[index];
                              final user = c.firestoreController.users
                                  .firstWhereOrNull((element) =>
                                      element.userId == state.userId);
                              final bool isInvited =
                                  state.type == LivestreamUserType.invited;
                              return MemberProfileCard(
                                user: user,
                                widget:
                                    _buildActionWidget(state, user, isInvited),
                                onTap: () {
                                  if (user == null) return;
                                  Get.back();
                                  Get.bottomSheet(
                                    LiveStreamUserInfoSheet(
                                      isAudience: !widget.isHost,
                                      liveUser: user,
                                      controller: c,
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        NoDataView(
                          showShow: c.coHostList.isEmpty,
                          title: LKey.coHostListEmptyTitle.tr,
                          description: LKey.coHostListEmptyDescription.tr,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: c.coHostList.length,
                            itemBuilder: (context, index) {
                              final state = c.coHostList[index];
                              final user = c.firestoreController.users
                                  .firstWhereOrNull((element) =>
                                      element.userId == state.userId);
                              final bool isInvited =
                                  state.type == LivestreamUserType.invited;
                              return MemberProfileCard(
                                user: user,
                                widget:
                                    _buildActionWidget(state, user, isInvited),
                                onTap: () {
                                  if (user == null) return;
                                  Get.back();
                                  Get.bottomSheet(
                                    LiveStreamUserInfoSheet(
                                      isAudience: !widget.isHost,
                                      liveUser: user,
                                      controller: c,
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildActionWidget(
      LivestreamUserState state, AppUser? user, bool isInvited) {
    final c = controller;
    if (c == null) return const SizedBox();
    final isPrivileged = widget.isHost ||
        ((c.liveData.value.coHostIds ?? const <int>[]).contains(c.myUserId));
    if (!isPrivileged) return const SizedBox();
    switch (state.type) {
      case LivestreamUserType.requested:
        return Row(
          children: [
            _buildActionBtn(AssetRes.icCheck, ColorRes.green, () {
              Get.back();
              c.handleRequestResponse(user: user, isRefused: false);
            }),
            _buildActionBtn(AssetRes.icClose1, ColorRes.likeRed, () {
              c.handleRequestResponse(user: user, isRefused: true);
            }),
          ],
        );
      case LivestreamUserType.audience:
        return TextBorderButton(
          text: isInvited ? LKey.invited.tr : LKey.invite.tr,
          textOpacity: isInvited ? .2 : 1,
          onTap: () => c.onInvite(user, isInvited: isInvited),
        );
      case LivestreamUserType.invited:
        return TextBorderButton(
          text: LKey.cancel.tr,
          onTap: () => c.onInvite(user, isInvited: isInvited),
        );
      case LivestreamUserType.coHost:
        return Row(
          children: [
            _buildActionBtn(
              state.videoStatus == VideoAudioStatus.on
                  ? AssetRes.icVideoCamera
                  : AssetRes.icVideoOff,
              textLightGrey(context),
              () => c.coHostVideoToggle(state),
            ),
            _buildActionBtn(
              state.audioStatus == VideoAudioStatus.on
                  ? AssetRes.icMicrophone
                  : AssetRes.icMicOff,
              textLightGrey(context),
              () => c.coHostAudioToggle(state),
            ),
            _buildActionBtn(AssetRes.icDelete1, ColorRes.likeRed,
                () => c.coHostDelete(state)),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildActionBtn(String asset, Color color, [VoidCallback? onTap]) {
    return BorderRoundedButton(
      image: asset,
      color: color,
      onTap: onTap,
      padding: 5,
    );
  }
}

class MemberProfileCard extends StatelessWidget {
  final Widget widget;
  final AppUser? user;
  final VoidCallback? onTap;

  const MemberProfileCard(
      {super.key, required this.widget, required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                CustomImage(
                    size: const Size(40, 40),
                    image: user?.profile?.addBaseURL(),
                    fullName: user?.fullname),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FullNameWithBlueTick(
                        userId: user?.userId,
                        username: user?.username,
                        isVerify: user?.isVerify,
                        fontSize: 13,
                        iconSize: 18,
                      ),
                      Text(user?.fullname ?? '',
                          style: TextStyleCustom.outFitLight300(
                              color: textLightGrey(context)))
                    ],
                  ),
                ),
                widget
              ],
            ),
            const SizedBox(height: 10),
            const CustomDivider()
          ],
        ),
      ),
    );
  }
}

class BorderRoundedButton extends StatelessWidget {
  final String image;
  final Color color;
  final VoidCallback? onTap;
  final double? padding;
  final double? width;
  final double? height;
  final Color? bgColor;

  const BorderRoundedButton(
      {super.key,
      required this.image,
      required this.color,
      this.onTap,
      this.padding,
      this.width,
      this.height,
      this.bgColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height ?? 34,
        width: width ?? 34,
        padding: EdgeInsets.all(padding ?? 0),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: color)),
        alignment: Alignment.center,
        child: Image.asset(image, color: color, width: 24, height: 24),
      ),
    );
  }
}

class TextBorderButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double? textOpacity;

  const TextBorderButton(
      {super.key, required this.text, this.onTap, this.textOpacity});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        width: 100,
        decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 8, cornerSmoothing: 1),
                side: BorderSide(color: bgGrey(context)))),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyleCustom.outFitRegular400(
              color: textLightGrey(context),
              fontSize: 15,
              opacity: textOpacity),
        ),
      ),
    );
  }
}

class Values {
  String image;
  Color color;
  double padding;

  Values(this.image, this.color, {this.padding = 0});
}
