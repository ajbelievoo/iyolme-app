import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/share_manager.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/share_sheet_widget/share_sheet_widget_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ShareSheetWidget extends StatelessWidget {
  final VoidCallback onMoreTap;
  final String link;
  final bool isDownloadShow;
  final Post? post;
  final ShareKeys keys;
  final Function()? onCallBack;
  final Map<String, dynamic>? extraData;

  const ShareSheetWidget(
      {super.key,
      required this.onMoreTap,
      required this.link,
      this.isDownloadShow = false,
      this.post,
      required this.keys,
      this.onCallBack,
      this.extraData});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
        ShareSheetWidgetController(post, onCallBack, extraData: extraData));
    final isLive = keys == ShareKeys.live;

    return Wrap(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              key: controller.screenShotKey,
              child: Column(
                children: [
                  Obx(
                    () => controller.waterMarkPath.value.isEmpty
                        ? const SizedBox()
                        : Image.file(File(controller.waterMarkPath.value),
                            fit: BoxFit.contain, height: 50, width: 100),
                  ),
                  Text(
                    '@${post?.user?.username ?? AppRes.appName}',
                    style: TextStyleCustom.unboundedBold700(
                            color: whitePure(context), fontSize: 15)
                        .copyWith(shadows: [
                      const Shadow(color: Colors.black, blurRadius: 20)
                    ]),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2.5),
              decoration: ShapeDecoration(
                  shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.vertical(
                          top: SmoothRadius(
                              cornerRadius: 40, cornerSmoothing: 1))),
                  color: scaffoldBackgroundColor(context)),
              child: Column(
                children: [
                  // Custom Header with Yellow Underline
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 20),
                    child: Column(
                      children: [
                        Text(
                          'Invite to join the channel',
                          style: TextStyleCustom.outFitBold700(
                              color: themeAccentSolid(context), fontSize: 18),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 3,
                          width: 30,
                          color: themeAccentSolid(context),
                        )
                      ],
                    ),
                  ),

                  // Social Media Icons Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSocialIcon(
                          context,
                          icon: Icons.link,
                          color: Colors.orange,
                          onTap: () async {
                            Get.back();
                            await link.copyText;
                            DebounceAction.shared.call(() {
                              controller.increaseShareCount(post?.id);
                            }, milliseconds: 1000);
                          },
                        ),
                        _buildSocialIcon(
                          context,
                          icon: Icons.person_add,
                          color: Colors.blue,
                          onTap: () {
                            // Invite Contacts Logic
                          },
                        ),
                        _buildSocialIcon(
                          context,
                          icon: Icons.call,
                          color: Colors.green,
                          onTap: () {
                            // WhatsApp Share Logic
                            controller.onShareSheetBottomBtnTap(
                                ShareOption.whatsapp, link,
                                post: post);
                          },
                        ),
                        _buildSocialIcon(
                          context,
                          icon: Icons.facebook,
                          color: Colors.blue[800]!,
                          onTap: () {
                            // Facebook Share Logic
                          },
                        ),
                        _buildSocialIcon(
                          context,
                          icon: Icons.chat_bubble,
                          color: Colors.greenAccent[700]!,
                          onTap: () {
                            // Line Share Logic
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const CustomDivider(),

                  // Users List
                  if (keys == ShareKeys.post ||
                      keys == ShareKeys.reel ||
                      isLive)
                    Obx(() {
                      List<ChatThread> users = controller.chatsUsers;
                      if (users.isEmpty) {
                        return const SizedBox();
                      }
                      return Container(
                        height: 300,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            ChatThread chatConversation = users[index];
                            AppUser? chatUser = chatConversation.chatUser;
                            bool isSelected = controller.selectedConversation
                                .contains(chatConversation);
                            bool isFollowing = controller.followingIds
                                .contains(chatUser?.userId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              child: Row(
                                children: [
                                  CustomImage(
                                      size: const Size(50, 50),
                                      image: chatUser?.profile?.addBaseURL(),
                                      fullName: chatUser?.fullname),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chatUser?.fullname ?? '',
                                          style:
                                              TextStyleCustom.outFitRegular400(
                                                  color: textDarkGrey(context),
                                                  fontSize: 16),
                                        ),
                                        Text(
                                          'Contact "${chatUser?.username ?? ''}"',
                                          style:
                                              TextStyleCustom.outFitRegular400(
                                                  color: textLightGrey(context),
                                                  fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (!isFollowing) {
                                        controller
                                            .onFollowTap(chatConversation);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isFollowing
                                            ? bgLightGrey(context)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.grey
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        isFollowing ? 'Following' : 'Follow',
                                        style: TextStyleCustom.outFitBold700(
                                            color: isFollowing
                                                ? textLightGrey(context)
                                                : Colors.black,
                                            fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => controller.onNotifyTap(
                                        chatConversation, link),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? themeAccentSolid(context)
                                            : Colors.amber
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isSelected ? 'Notified' : 'Notify',
                                        style: TextStyleCustom.outFitBold700(
                                            color: isSelected
                                                ? Colors.white
                                                : themeAccentSolid(context),
                                            fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIcon(BuildContext context,
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class CustomAssetWithBgButton extends StatelessWidget {
  final String image;
  final double boxSize;
  final double iconSize;
  final double radius;
  final VoidCallback? onTap;

  const CustomAssetWithBgButton(
      {super.key,
      required this.image,
      required this.boxSize,
      required this.iconSize,
      this.radius = 15,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: boxSize,
        width: boxSize,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
            color: bgGrey(context),
            shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1))),
        child: Image.asset(image,
            height: iconSize, width: iconSize, color: textDarkGrey(context)),
      ),
    );
  }
}

enum ShareOption {
  download,
  whatsapp,
  share,
  instagram,
  telegram,
  more,
  copy;

  String value(String link) {
    switch (this) {
      case ShareOption.whatsapp:
        return "whatsapp://send?text=$link";
      case ShareOption.instagram:
        return "instagram://sharesheet?text=$link";
      case ShareOption.telegram:
        return "https://t.me/share/url?url=${Uri.encodeComponent(link)}";
      case ShareOption.download:
      case ShareOption.share:
      case ShareOption.more:
      case ShareOption.copy:
        return '';
    }
  }
}

enum ShareType { videoPost, imagePost, textPost, reelPost }
