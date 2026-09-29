import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/enum/chat_enum.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:shortzz/common/manager/story_view/add_to_cart/add_to_cart_animation.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/post_story/story/story_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet_controller.dart';
import 'package:shortzz/screen/hashtag_screen/hashtag_screen.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

import '../controller/story_controller.dart';
import '../utils.dart';
import 'story_image.dart';
import 'story_video.dart';
import 'viewers_sheet.dart';

/// Indicates where the progress indicators should be placed.
enum ProgressPosition { top, bottom, none }

/// This is used to specify the height of the progress indicator. Inline stories
/// should use [small]
enum IndicatorHeight { small, large }

/// This is a representation of a story item (or page).
class StoryItem {
  /// Specifies how long the page should be displayed. It should be a reasonable
  /// amount of time greater than 0 milliseconds.
  final Duration duration;

  final num id;
  List<String> viewedByUsersIds;

  /// Has this page been shown already? This is used to indicate that the page
  /// has been displayed. If some pages are supposed to be skipped in a story,
  /// mark them as shown `shown = true`.
  ///
  /// However, during initialization of the story view, all pages after the
  /// last un shown page will have their `shown` attribute altered to false. This
  /// is because the next item to be displayed is taken by the last un shown
  /// story item.
  bool shown;

  /// The page content
  final Widget view;
  final Story? story;

  StoryItem(
    this.view, {
    required this.id,
    required this.viewedByUsersIds,
    required this.duration,
    required this.story,
    this.shown = false,
  });

  /// Short hand to create text-only page.
  ///
  /// [title] is the text to be displayed on [backgroundColor]. The text color
  /// alternates between [Colors.black] and [Colors.white] depending on the
  /// calculated contrast. This is to ensure readability of text.
  ///
  /// Works for inline and full-page stories. See [StoryView.inline] for more on
  /// what inline/full-page means.
  ///
  static StoryItem text({
    required String title,
    required Color backgroundColor,
    Key? key,
    TextStyle? textStyle,
    bool shown = false,
    bool roundedTop = false,
    bool roundedBottom = false,
    required Duration duration,
    Story? story,
    num id = 0,
    List<String> viewedByUsersIds = const [],
  }) {
    double contrast = ContrastHelper.contrast([
      backgroundColor.r,
      backgroundColor.g,
      backgroundColor.b,
    ], [
      255,
      255,
      255
    ] /** white text */);

    return StoryItem(
        Container(
          key: key,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(roundedTop ? 8 : 0),
                bottom: Radius.circular(roundedBottom ? 8 : 0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: Text(
              title,
              style: textStyle?.copyWith(
                    color: contrast > 1.8 ? Colors.white : Colors.black,
                  ) ??
                  TextStyle(
                    color: contrast > 1.8 ? Colors.white : Colors.black,
                    fontSize: 18,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          //color: backgroundColor,
        ),
        shown: shown,
        duration: duration,
        viewedByUsersIds: viewedByUsersIds,
        id: id,
        story: story);
  }

  /// Factory constructor for page images. [controller] should be same instance as
  /// one passed to the `StoryView`
  factory StoryItem.pageImage({
    required String url,
    required StoryController controller,
    Key? key,
    BoxFit imageFit = BoxFit.fitWidth,
    String? caption,
    bool shown = false,
    Map<String, dynamic>? requestHeaders,
    required Duration duration,
    num id = 0,
    Story? story,
    List<String> viewedByUsersIds = const [],
  }) {
    return StoryItem(
        Container(
          key: key,
          color: Colors.black,
          child: Stack(
            children: <Widget>[
              StoryImage.url(
                url,
                controller: controller,
                fit: imageFit,
                requestHeaders: requestHeaders,
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      bottom: 24,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    color:
                        caption != null ? Colors.black54 : Colors.transparent,
                    child: caption != null
                        ? Text(
                            caption,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : const SizedBox(),
                  ),
                ),
              )
            ],
          ),
        ),
        shown: shown,
        viewedByUsersIds: viewedByUsersIds,
        duration: duration,
        id: id,
        story: story);
  }

  /// Shorthand for creating inline image. [controller] should be same instance as
  /// one passed to the `StoryView`
  factory StoryItem.inlineImage(
      {required String url,
      Text? caption,
      required StoryController controller,
      Key? key,
      BoxFit imageFit = BoxFit.cover,
      Map<String, dynamic>? requestHeaders,
      bool shown = false,
      bool roundedTop = true,
      bool roundedBottom = false,
      Duration? duration,
      num id = 0,
      List<String> viewedByUsersIds = const [],
      Story? story}) {
    return StoryItem(
        ClipSmoothRect(
          radius: SmoothBorderRadius.vertical(
              top: SmoothRadius(
                  cornerRadius: roundedTop ? 8 : 0, cornerSmoothing: 1),
              bottom: SmoothRadius(
                  cornerRadius: roundedBottom ? 8 : 0, cornerSmoothing: 1)),
          key: key,
          child: Container(
            color: Colors.grey[100],
            child: Container(
              color: Colors.black,
              child: Stack(
                children: <Widget>[
                  StoryImage.url(
                    url,
                    controller: controller,
                    fit: imageFit,
                    requestHeaders: requestHeaders,
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        width: double.infinity,
                        child: caption ?? const SizedBox(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        shown: shown,
        viewedByUsersIds: viewedByUsersIds,
        duration: duration ?? const Duration(seconds: 3),
        id: id,
        story: story);
  }

  /// Shorthand for creating page video. [controller] should be same instance as
  /// one passed to the `StoryView`
  factory StoryItem.pageVideo(
    String url, {
    required StoryController controller,
    Key? key,
    required Duration duration,
    BoxFit imageFit = BoxFit.fitWidth,
    String? caption,
    bool shown = false,
    Map<String, dynamic>? requestHeaders,
    num id = 0,
    Story? story,
    List<String> viewedByUsersIds = const [],
  }) {
    return StoryItem(
        Container(
          key: key,
          color: Colors.black,
          child: Stack(
            children: <Widget>[
              StoryVideo.url(
                url,
                controller: controller,
                requestHeaders: requestHeaders,
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    color:
                        caption != null ? Colors.black54 : Colors.transparent,
                    child: caption != null
                        ? Text(
                            caption,
                            style: const TextStyle(
                                fontSize: 15, color: Colors.white),
                            textAlign: TextAlign.center,
                          )
                        : const SizedBox(),
                  ),
                ),
              )
            ],
          ),
        ),
        shown: shown,
        viewedByUsersIds: viewedByUsersIds,
        duration: duration,
        id: id,
        story: story);
  }

  /// Shorthand for creating a story item from an image provider such as `AssetImage`
  /// or `NetworkImage`. However, the story continues to play while the image loads
  /// up.
  factory StoryItem.pageProviderImage(
    ImageProvider image, {
    Key? key,
    BoxFit imageFit = BoxFit.fitWidth,
    String? caption,
    bool shown = false,
    Duration? duration,
    num id = 0,
    Story? story,
    List<String> viewedByUsersIds = const [],
  }) {
    return StoryItem(
        Container(
          key: key,
          color: Colors.black,
          child: Stack(
            children: <Widget>[
              Center(
                child: Image(
                  image: image,
                  height: double.infinity,
                  width: double.infinity,
                  fit: imageFit,
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      bottom: 24,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    color:
                        caption != null ? Colors.black54 : Colors.transparent,
                    child: caption != null
                        ? Text(
                            caption,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : const SizedBox(),
                  ),
                ),
              )
            ],
          ),
        ),
        shown: shown,
        viewedByUsersIds: viewedByUsersIds,
        duration: duration ?? const Duration(seconds: 3),
        id: id,
        story: story);
  }

  /// Shorthand for creating an inline story item from an image provider such as `AssetImage`
  /// or `NetworkImage`. However, the story continues to play while the image loads
  /// up.
  factory StoryItem.inlineProviderImage(
    ImageProvider image, {
    Key? key,
    Text? caption,
    bool shown = false,
    bool roundedTop = true,
    bool roundedBottom = false,
    Duration? duration,
    Story? story,
    num id = 0,
    List<String> viewedByUsersIds = const [],
  }) {
    return StoryItem(
        Container(
          key: key,
          decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(roundedTop ? 8 : 0),
                bottom: Radius.circular(roundedBottom ? 8 : 0),
              ),
              image: DecorationImage(
                image: image,
                fit: BoxFit.cover,
              )),
          child: Container(
            margin: const EdgeInsets.only(
              bottom: 16,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: double.infinity,
                child: caption ?? const SizedBox(),
              ),
            ),
          ),
        ),
        shown: shown,
        duration: duration ?? const Duration(seconds: 3),
        viewedByUsersIds: viewedByUsersIds,
        id: id,
        story: story);
  }
}

class _StoryEditorMetaOverlay extends StatelessWidget {
  final int storyId;
  final StoryController storyController;
  final Future<void> Function(String username) onMentionTap;
  final VoidCallback onStickerTap;
  final VoidCallback onQuestionTap;

  const _StoryEditorMetaOverlay({
    required this.storyId,
    required this.storyController,
    required this.onMentionTap,
    required this.onStickerTap,
    required this.onQuestionTap,
  });

  bool _isAnimatedStickerUrl(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return false;
    final noQuery = u.split('?').first;
    return noQuery.endsWith('.gif') || noQuery.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    if (storyId <= 0) return const SizedBox();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('story_editor_meta')
          .doc(storyId.toString())
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) return const SizedBox();
        final texts = (data['texts'] as List?) ?? const [];
        final stickers = (data['stickers'] as List?) ?? const [];
        if (texts.isEmpty && stickers.isEmpty) return const SizedBox();

        return IgnorePointer(
          ignoring: false,
          child: Stack(
            children: [
              ...stickers.map((e) {
                if (e is! Map) return const SizedBox();
                final m = Map<String, dynamic>.from(e);
                final url = (m['url'] ?? '').toString().trim();
                if (url.isEmpty) return const SizedBox();

                final top = (m['top'] is num)
                    ? (m['top'] as num).toDouble()
                    : double.tryParse('${m['top'] ?? ''}') ?? 0.0;
                final left = (m['left'] is num)
                    ? (m['left'] as num).toDouble()
                    : double.tryParse('${m['left'] ?? ''}') ?? 0.0;
                final scale = (m['scale'] is num)
                    ? (m['scale'] as num).toDouble()
                    : double.tryParse('${m['scale'] ?? ''}') ?? 1.0;
                final angle = (m['angle'] is num)
                    ? (m['angle'] as num).toDouble()
                    : double.tryParse('${m['angle'] ?? ''}') ?? 0.0;

                return Positioned(
                  top: top,
                  left: left,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onStickerTap,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..rotateZ(angle)
                        ..scale(scale),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _isAnimatedStickerUrl(url)
                              ? CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) =>
                                      const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                )
                              : Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      color:
                                          blackPure(context).withValues(alpha: 0.2),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Sticker',
                                        style:
                                            TextStyleCustom.outFitRegular400(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              ...texts.map((e) {
                if (e is! Map) return const SizedBox();
                final m = Map<String, dynamic>.from(e);
                final text = (m['text'] ?? '').toString();
                if (text.trim().isEmpty) return const SizedBox();

                final top = (m['top'] is num)
                    ? (m['top'] as num).toDouble()
                    : double.tryParse('${m['top'] ?? ''}') ?? 0.0;
                final left = (m['left'] is num)
                    ? (m['left'] as num).toDouble()
                    : double.tryParse('${m['left'] ?? ''}') ?? 0.0;
                final fontSize = (m['font_size'] is num)
                    ? (m['font_size'] as num).toDouble()
                    : double.tryParse('${m['font_size'] ?? ''}') ?? 22.0;
                final fontScale = (m['font_scale'] is num)
                    ? (m['font_scale'] as num).toDouble()
                    : double.tryParse('${m['font_scale'] ?? ''}') ?? 1.0;
                final angle = (m['font_angle'] is num)
                    ? (m['font_angle'] as num).toDouble()
                    : double.tryParse('${m['font_angle'] ?? ''}') ?? 0.0;
                final opacity = (m['opacity'] is num)
                    ? (m['opacity'] as num).toDouble()
                    : double.tryParse('${m['opacity'] ?? ''}') ?? 1.0;

                final isLoc = text.trimLeft().startsWith('__loc__:');
                final isQst = text.trimLeft().startsWith('__qst__:');
                final isQRep = text.trimLeft().startsWith('__qrep__:');
                final baseStyle = TextStyleCustom.outFitMedium500(
                  fontSize: fontSize,
                  color: Colors.white,
                  opacity: opacity,
                );

                return Positioned(
                  top: top,
                  left: left,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: Matrix4.identity()
                      ..rotateZ(angle)
                      ..scale(fontScale),
                    child: SizedBox(
                      width: Get.width - 50,
                      child: isLoc
                          ? GestureDetector(
                              onTap: onStickerTap,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.place_rounded,
                                      size: 18,
                                      color: themeAccentSolid(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        text
                                            .trimLeft()
                                            .replaceFirst('__loc__:', '')
                                            .trim()
                                            .toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            TextStyleCustom.unboundedMedium500(
                                          color: themeAccentSolid(context),
                                          fontSize: fontSize.clamp(16, 28),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : isQst
                              ? GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onQuestionTap,
                                  child: Container(
                                    width: 260,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          text
                                              .trimLeft()
                                              .replaceFirst('__qst__:', '')
                                              .trim(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyleCustom
                                              .unboundedMedium500(
                                            color: Colors.black,
                                            fontSize: fontSize.clamp(14, 22),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          height: 40,
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withAlpha(18),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Type your answer',
                                            style: TextStyleCustom
                                                .outFitRegular400(
                                              color:
                                                  Colors.black.withAlpha(160),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                          : isQRep
                              ? Builder(builder: (context) {
                                  final payload = text
                                      .trimLeft()
                                      .replaceFirst('__qrep__:', '')
                                      .trim();
                                  final parts = payload.split('|');
                                  final who =
                                      parts.isNotEmpty ? parts[0].trim() : '';
                                  final ans = parts.length > 1
                                      ? parts.sublist(1).join('|').trim()
                                      : '';
                                  return Container(
                                    width: 260,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (who.isNotEmpty)
                                          Text(
                                            who,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyleCustom
                                                .unboundedMedium500(
                                              color:
                                                  Colors.black.withAlpha(170),
                                              fontSize: 13,
                                            ),
                                          ),
                                        if (who.isNotEmpty)
                                          const SizedBox(height: 6),
                                        Text(
                                          ans.isEmpty ? 'Reply' : ans,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyleCustom
                                              .unboundedMedium500(
                                            color: Colors.black,
                                            fontSize: fontSize.clamp(14, 20),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                          : _AnnotatedText(
                              text: text,
                              baseStyle: baseStyle,
                              onMentionTap: onMentionTap,
                            ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _AnnotatedText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Future<void> Function(String username) onMentionTap;

  const _AnnotatedText({
    required this.text,
    required this.baseStyle,
    required this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    final mentionStyle = baseStyle.copyWith(
      color: blueFollow(context),
      fontWeight: FontWeight.w600,
    );
    final hashStyle = baseStyle.copyWith(
      color: themeAccentSolid(context),
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    final matches = AppRes.combinedRegex.allMatches(text).toList();
    int last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: baseStyle));
      }
      final token = text.substring(m.start, m.end);
      if (token.startsWith('@')) {
        spans.add(
          TextSpan(
            text: token,
            style: mentionStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                onMentionTap(token);
              },
          ),
        );
      } else if (token.startsWith('#')) {
        spans.add(
          TextSpan(
            text: token,
            style: hashStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Get.to(
                  () => HashtagScreen(hashtag: token, index: 1),
                  preventDuplicates: false,
                );
              },
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: baseStyle));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

/// Widget to display stories just like Whatsapp and Instagram. Can also be used
/// inline/inside [ListView] or [Column] just like Google News app. Comes with
/// gestures to pause, forward and go to previous page.
class StoryView extends StatefulWidget {
  /// The pages to displayed.
  final List<StoryItem?> storyItems;

  /// Callback for when a full cycle of story is shown. This will be called
  /// each time the full story completes when [repeat] is set to `true`.
  final VoidCallback? onComplete;

  final VoidCallback? onBack;

  /// Callback for when a vertical swipe gesture is detected. If you do not
  /// want to listen to such event, do not provide it. For instance,
  /// for inline stories inside ListViews, it is preferable to not to
  /// provide this callback so as to enable scroll events on the list view.
  final Function(Direction?)? onVerticalSwipeComplete;

  /// Callback for when a story is currently being shown.
  final ValueChanged<StoryItem>? onStoryShow;

  /// Where the progress indicator should be placed.
  final ProgressPosition progressPosition;

  /// Should the story be repeated forever?
  final bool repeat;

  /// If you would like to display the story as full-page, then set this to
  /// `false`. But in case you would display this as part of a page (eg. in
  /// a [ListView] or [Column]) then set this to `true`.
  final bool inline;

  // Controls the playback of the stories
  final StoryController controller;

  // Indicator Color
  final Color indicatorColor;

  final Widget Function(StoryItem item)? overlayWidget;

  const StoryView(
      {super.key,
      required this.storyItems,
      required this.controller,
      this.onComplete,
      this.onStoryShow,
      this.progressPosition = ProgressPosition.top,
      this.repeat = false,
      this.inline = false,
      this.onVerticalSwipeComplete,
      this.indicatorColor = Colors.white,
      this.onBack,
      this.overlayWidget});

  @override
  State<StatefulWidget> createState() {
    return StoryViewState();
  }
}

class StoryViewState extends State<StoryView> with TickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _currentAnimation;
  Timer? _nextDeBouncer;

  final RxSet<int> giftedStoryIds = <int>{}.obs;
  final RxSet<int> likedStoryIds = <int>{}.obs;

  StreamSubscription<PlaybackState>? _playbackSubscription;

  final TextEditingController textEditingController = TextEditingController();
  final RxString _activeQuestionText = ''.obs;
  final RxBool _questionMetaLoading = false.obs;
  FocusNode inputNode = FocusNode();

  VerticalDragInfo? verticalDragInfo;

  StoryItem? get _currentStory {
    return widget.storyItems.firstWhereOrNull((it) => !it!.shown);
  }

  void _showViewers(List<String> ids) {
    widget.controller.pause();
    Get.bottomSheet(
      ViewersSheet(viewerIds: ids),
      isScrollControlled: true,
    ).then((_) {
      widget.controller.play();
    });
  }

  void _togglePauseResume() {
    try {
      if (widget.controller.playbackNotifier.hasValue &&
          widget.controller.playbackNotifier.value == PlaybackState.pause) {
        widget.controller.play();
      } else {
        widget.controller.pause();
      }
    } catch (_) {
      widget.controller.pause();
    }
  }

  void _focusAnswerInput() {
    try {
      widget.controller.pause();
    } catch (_) {}
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          FocusManager.instance.primaryFocus?.unfocus();
        } catch (_) {}

        FocusScope.of(context).requestFocus(inputNode);

        Future.delayed(const Duration(milliseconds: 60), () {
          if (!mounted) return;
          if (!inputNode.hasFocus) {
            FocusScope.of(context).requestFocus(inputNode);
          }
          try {
            SystemChannels.textInput.invokeMethod('TextInput.show');
          } catch (_) {}
        });
      });
    } catch (_) {}
  }

  Future<void> _openMentionProfile(String username) async {
    final u = username.replaceAll('@', '').trim();
    if (u.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_users')
          .where('username', isEqualTo: u)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;
      final data = snap.docs.first.data();

      final dynamic rawId = data['id'] ?? data['user_id'] ?? data['userId'];
      final Map<String, dynamic> mapped = Map<String, dynamic>.from(data);
      if (!mapped.containsKey('id') && rawId != null) {
        mapped['id'] = rawId;
      }

      final user = User.fromJson(mapped);
      await NavigationService.shared.openProfileScreen(user);
    } catch (e) {
      Loggers.error('Open mention profile failed: $e');
    }
  }

  Widget get _currentView {
    var item = widget.storyItems.firstWhereOrNull((it) => !it!.shown);
    item ??= widget.storyItems.last;
    return SafeArea(
      child: ClipSmoothRect(
        radius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 10, cornerSmoothing: 1)),
        child: item?.view ?? Container(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.storyItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.onComplete != null) {
          widget.controller.pause();
          widget.onComplete!.call();
        }
      });
      return;
    }

    // All pages after the first unShown page should have their shown value as
    // false
    final firstPage = widget.storyItems.firstWhereOrNull((it) => !it!.shown);
    if (firstPage == null) {
      for (var it2 in widget.storyItems) {
        it2?.shown = false;
      }
    } else {
      final lastShownPos = widget.storyItems.indexOf(firstPage);
      widget.storyItems.sublist(lastShownPos).forEach((it) {
        it?.shown = false;
      });
    }

    _playbackSubscription =
        widget.controller.playbackNotifier.listen((playbackStatus) {
      switch (playbackStatus) {
        case PlaybackState.play:
          _removeNextHold();
          _animationController?.forward();
          break;

        case PlaybackState.pause:
          _holdNext(); // then pause animation
          _animationController?.stop(canceled: false);
          break;

        case PlaybackState.next:
          _removeNextHold();
          _goForward();
          break;

        case PlaybackState.previous:
          _removeNextHold();
          _goBack();
          break;
        case PlaybackState.playFromStart:
          // _goBack();
          break;
      }
    });

    _holdNext(); // then pause animation
    _animationController?.stop(canceled: false);

    _play();
  }

  @override
  void dispose() {
    _clearDeBouncer();

    _animationController?.dispose();
    _playbackSubscription?.cancel();

    textEditingController.dispose();
    inputNode.dispose();

    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void _play() {
    _animationController?.dispose();
    // get the next playing page
    final storyItem = widget.storyItems.firstWhere((it) {
      return !it!.shown;
    })!;

    if (widget.onStoryShow != null) {
      widget.onStoryShow!(storyItem);
    }

    _animationController =
        AnimationController(duration: storyItem.duration, vsync: this);
    _animationController?.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        storyItem.shown = true;
        if (widget.storyItems.last != storyItem) {
          _beginPlay();
        } else {
          // done playing
          _onComplete();
        }
      }
    });

    _currentAnimation =
        Tween(begin: 0.0, end: 1.0).animate(_animationController!);

    widget.controller.play();
  }

  void _beginPlay() {
    setState(() {});
    widget.controller.playFromStart();
    _play();
  }

  void _onComplete() {
    if (widget.onComplete != null) {
      widget.controller.pause();
      widget.onComplete!();
    }

    if (widget.repeat) {
      for (var it in widget.storyItems) {
        it!.shown = false;
      }

      _beginPlay();
    }
  }

  void _goBack() {
    _animationController!.stop();

    if (_currentStory == null) {
      widget.storyItems.last!.shown = false;
    }

    if (_currentStory == widget.storyItems.first) {
      _beginPlay();
      if (widget.onBack != null) {
        widget.onBack!();
      }
    } else {
      _currentStory!.shown = false;
      int lastPos = widget.storyItems.indexOf(_currentStory);
      final previous = widget.storyItems[lastPos - 1]!;

      previous.shown = false;

      _beginPlay();
    }
  }

  void _goForward() {
    if (_currentStory != widget.storyItems.last) {
      _animationController!.stop();

      // get last showing
      final last = _currentStory;

      if (last != null) {
        last.shown = true;
        if (last != widget.storyItems.last) {
          _beginPlay();
        }
      }
    } else {
      // this is the last page, progress animation should skip to end
      _animationController!
          .animateTo(1.0, duration: const Duration(milliseconds: 10));
    }
  }

  void _clearDeBouncer() {
    _nextDeBouncer?.cancel();
    _nextDeBouncer = null;
  }

  void _removeNextHold() {
    _nextDeBouncer?.cancel();
    _nextDeBouncer = null;
  }

  void _holdNext() {
    _nextDeBouncer?.cancel();
    _nextDeBouncer = Timer(const Duration(milliseconds: 500), () {});
  }

  GlobalKey<CartIconKey> cartKey = GlobalKey<CartIconKey>();
  late Function(GlobalKey) runAddToCartAnimation;
  double currentOpacity = 1;
  RxDouble viewOpacity = 1.0.obs;
  Duration viewOpacityDuration = const Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    if (widget.storyItems.isEmpty) {
      return const SizedBox();
    }
    var story = widget.storyItems.firstWhereOrNull((it) => !it!.shown);
    story ??= widget.storyItems.last;
    final bool isMyStory = story?.story?.user == null ||
        story?.story?.user?.id == SessionManager.instance.getUserID();
    return AddToCartAnimation(
      cartKey: cartKey,
      jumpAnimation: const JumpAnimationOptions(),
      createAddToCartAnimation: (cart) {
        // You can run the animation by addToCartAnimationMethod, just pass trough the the global key of  the image as parameter
        runAddToCartAnimation = cart;
      },
      child: StreamBuilder<bool>(
        stream: widget.controller.mediaLoadingNotifier.stream,
        initialData: false,
        builder: (context, mediaSnap) {
          final isMediaLoading = mediaSnap.data == true;

          return Column(
            children: [
              KeyboardVisibilityBuilder(builder: (context, isKeyboardOn) {
                isKeyboardOn
                    ? widget.controller.pause()
                    : widget.controller.play();
                return Expanded(
                  child: Stack(
                    children: <Widget>[
                      _currentView,
                      if (story != null)
                        Positioned.fill(
                          child: _QuestionMetaWatcher(
                            storyId: (story.id).toInt(),
                            onQuestion: (q) {
                              _activeQuestionText.value = q;
                            },
                          ),
                        ),
                      if (!isMediaLoading)
                        Obx(() {
                          return AnimatedOpacity(
                            duration: viewOpacityDuration,
                            opacity: viewOpacity.value,
                            child: Container(
                              height: double.infinity,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.transparent
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter),
                              ),
                            ),
                          );
                        }),
                      if (!isMediaLoading)
                        Obx(
                          () => AnimatedOpacity(
                            duration: viewOpacityDuration,
                            opacity: viewOpacity.value,
                            child: Visibility(
                              visible: widget.progressPosition !=
                                  ProgressPosition.none,
                              child: Align(
                                alignment: widget.progressPosition ==
                                        ProgressPosition.top
                                    ? Alignment.topCenter
                                    : Alignment.bottomCenter,
                                child: SafeArea(
                                  bottom: widget.inline ? false : true,
                                  // we use SafeArea here for notched and bezels phones
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: PageBar(
                                          widget.storyItems
                                              .map((it) => PageData(
                                                  it!.duration, it.shown))
                                              .toList(),
                                          _currentAnimation,
                                          key: UniqueKey(),
                                          indicatorHeight: widget.inline
                                              ? IndicatorHeight.small
                                              : IndicatorHeight.large,
                                          indicatorColor: widget.indicatorColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  Align(
                    alignment: Alignment.centerRight,
                    heightFactor: 1,
                    child: GestureDetector(
                      onVerticalDragStart: (details) {
                        verticalDragInfo = VerticalDragInfo();
                      },
                      onVerticalDragUpdate: (details) {
                        verticalDragInfo?.update(details.primaryDelta ?? 0);
                      },
                      onVerticalDragEnd: (details) {
                        if (verticalDragInfo != null &&
                            !verticalDragInfo!.cancel &&
                            verticalDragInfo!.direction != null) {
                          if (verticalDragInfo!.direction == Direction.up) {
                            if (isMyStory && story != null) {
                              _showViewers(story.viewedByUsersIds);
                            }
                          } else if (verticalDragInfo!.direction ==
                              Direction.down) {
                            widget.onVerticalSwipeComplete
                                ?.call(Direction.down);
                          }
                        }
                        verticalDragInfo = null;
                      },
                      onTap: () {
                         // Empty onTap to handle tap events if needed
                      },
                      onTapDown: (details) {
                        widget.controller.pause();
                        viewOpacity.value = 0;
                        Loggers.success('onTapDown');
                      },
                      onTapCancel: () {
                        widget.controller.play();
                        Loggers.success('onTapCancel');
                        viewOpacity.value = 1;
                      },
                      onTapUp: (details) {
                        // if debounce timed out (not active) then continue anim
                        if (_nextDeBouncer?.isActive == false) {
                          widget.controller.play();
                        } else {
                          final tapX = details.localPosition.dx;
                          final widgetWidth = MediaQuery.of(context).size.width;

                          if (tapX < widgetWidth / 2) {
                            // Tap on left side
                            widget.controller.previous();
                            debugPrint('Tapped Left');
                          } else {
                            // Tap on right side
                            widget.controller.next();
                            debugPrint('Tapped Right');
                          }
                        }
                        viewOpacity.value = 1;
                      },
                    ),
                  ),
                      if (!isMediaLoading && story != null)
                        Positioned.fill(
                          child: _StoryEditorMetaOverlay(
                            storyId: (story.id).toInt(),
                            storyController: widget.controller,
                            onMentionTap: _openMentionProfile,
                            onStickerTap: _togglePauseResume,
                            onQuestionTap: _focusAnswerInput,
                          ),
                        ),
                      if (!isMediaLoading &&
                          widget.overlayWidget != null &&
                          story != null)
                        SafeArea(
                          child: Obx(
                            () => AnimatedOpacity(
                                opacity: viewOpacity.value,
                                duration: viewOpacityDuration,
                                child: widget.overlayWidget!(story!)),
                          ),
                        ),
                  // Animation to show the cart icon
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 30, horizontal: 8),
                      child: AddToCartIcon(
                        cartKey: cartKey,
                        icon: Container(
                            width: 20, height: 20, color: Colors.transparent),
                        badgeOptions: const BadgeOptions(
                            active: true,
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.transparent),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: isKeyboardOn,
                    child: InkWell(
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: Container(
                        color: Colors.black
                            .withValues(alpha: isKeyboardOn ? 0.6 : 0),
                        alignment: Alignment.center,
                        child: GridView.builder(
                          primary: false,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 70),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3, childAspectRatio: 1),
                          itemCount: AppRes.storyQuickReplyEmojis.length,
                          itemBuilder: (BuildContext context, int index) {
                            GlobalKey widgetKey = GlobalKey();
                            return InkWell(
                              onTap: () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                currentOpacity = 0;
                                setState(() {});
                                HapticFeedback.mediumImpact();
                                await runAddToCartAnimation(widgetKey);
                                currentOpacity = 1;
                                await cartKey.currentState
                                    ?.runClearCartAnimation();
                                if (story != null) {
                                  if (isMyStory) return;
                                  sendReply(
                                      textReply:
                                          AppRes.storyQuickReplyEmojis[index],
                                      item: story);
                                }
                              },
                              child: AnimatedOpacity(
                                opacity: currentOpacity,
                                duration: const Duration(milliseconds: 1500),
                                child: Container(
                                  key: widgetKey,
                                  margin: const EdgeInsets.all(10),
                                  alignment: Alignment.center,
                                  child: Text(
                                    AppRes.storyQuickReplyEmojis[index],
                                    style: const TextStyle(
                                        fontSize: 40, color: Colors.black),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                  ),
                );
              }),
              isMyStory
                  ? SafeArea(
                      child: GestureDetector(
                        onTap: () {
                          if (story != null) {
                            _showViewers(story.viewedByUsersIds);
                          }
                        },
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.keyboard_arrow_up,
                                  color: Colors.white),
                              Text(
                                '${story?.viewedByUsersIds.length ?? 0} Viewers',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : isMediaLoading
                      ? const SizedBox(height: 48)
                      : Obx(
                          () => AnimatedOpacity(
                            duration: viewOpacityDuration,
                            opacity: viewOpacity.value,
                            child: StoryBottomVIew(
                              textEditingController: textEditingController,
                              focusNode: inputNode,
                              isGifted: giftedStoryIds
                                  .contains((story?.id ?? 0).toInt()),
                              isLiked: likedStoryIds
                                  .contains((story?.id ?? 0).toInt()),
                              onSendTap: () {
                                if (isMyStory) return;
                                if (story != null) {
                                  final q = _activeQuestionText.value.trim();
                                  if (q.isNotEmpty) {
                                    _submitQuestionAnswer(
                                        item: story, question: q);
                                  } else {
                                    sendReply(
                                      item: story,
                                      textReply:
                                          textEditingController.text.trim(),
                                    );
                                  }
                                }
                              },
                              onGiftTap: () {
                                if (isMyStory) return;
                                onGiftTap(story);
                              },
                              onLikeTap: () {
                                if (isMyStory) return;
                                onLikeTap(story);
                              },
                            ),
                          ),
                        )
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitQuestionAnswer({required StoryItem item, required String question}) async {
    final ans = textEditingController.text.trim();
    if (ans.isEmpty) return;
    final storyId = item.id.toInt();
    if (storyId <= 0) return;

    final sender = SessionManager.instance.getUser();
    final senderId = sender?.id;
    if (senderId == null) return;

    final owner = item.story?.user;
    final ownerId = item.story?.userId;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await FirebaseFirestore.instance
          .collection('story_question_replies')
          .doc(storyId.toString())
          .collection('items')
          .doc(now.toString())
          .set({
        'story_id': storyId,
        'owner_id': ownerId,
        'question': question,
        'answer': ans,
        'sender_id': senderId,
        'sender_username': sender?.username,
        'sender_fullname': sender?.fullname,
        'sender_profile': sender?.profilePhoto,
        'created_at': now,
        'replied': false,
      });
    } catch (e) {
      Loggers.error('Question answer save failed: $e');
    }

    // Also send to chat as story reply (requested)
    sendReply(item: item, textReply: ans);

    // Push notification to story owner
    try {
      final token = owner?.deviceToken;
      if ((token ?? '').trim().isNotEmpty && (ownerId ?? -1) != senderId) {
        NotificationService.instance.pushNotification(
          type: NotificationType.other,
          title: sender?.fullname?.isNotEmpty == true
              ? (sender?.fullname ?? '')
              : (sender?.username ?? ''),
          body: 'answered your question',
          token: token,
          deviceType: owner?.device,
          data: {
            'story_id': storyId,
            'sender_id': senderId,
            'type': 'story_question_answer',
          },
        );
      }
    } catch (e) {
      Loggers.error('Question answer notification failed: $e');
    }

    textEditingController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    BaseController.share.showSnackBar(LKey.messageSent.tr);
  }
  void onGiftTap(StoryItem? story) {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.controller.pause();

    if (story == null) {
      return widget.controller.play();
    }

    GiftManager.openGiftSheet(
        userId: story.story?.userId ?? -1,
        onCompletion: (giftManager) {
          giftedStoryIds.add(story.id.toInt());
          _saveStoryReaction(
            item: story,
            type: 'gift',
            giftJson: giftManager.gift.toJson(),
          );
          widget.controller.play();
          sendReply(
              textReply: '',
              item: story,
              imageReply: jsonEncode(giftManager.gift.toJson()));
        }).then((value) {
      widget.controller.play();
    });
  }

  void onLikeTap(StoryItem? story) {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.controller.pause();

    if (story == null) {
      return widget.controller.play();
    }

    likedStoryIds.add(story.id.toInt());
    _saveStoryReaction(item: story, type: 'like');
    widget.controller.play();
    sendReply(item: story, textReply: '❤️');
  }

  Future<void> _saveStoryReaction({
    required StoryItem item,
    required String type,
    Map<String, dynamic>? giftJson,
  }) async {
    final storyId = item.id.toInt();
    if (storyId <= 0) return;

    final sender = SessionManager.instance.getUser();
    final senderId = sender?.id;
    if (senderId == null || senderId <= 0) return;

    final time = DateTime.now().millisecondsSinceEpoch;
    try {
      await FirebaseFirestore.instance
          .collection('story_reactions')
          .doc(storyId.toString())
          .collection('items')
          .doc(time.toString())
          .set({
        'story_id': storyId,
        'type': type,
        'sender_id': senderId,
        'sender_username': sender?.username,
        'sender_fullname': sender?.fullname,
        'sender_profile': sender?.profilePhoto,
        'sender_is_verify': sender?.isVerify,
        'gift': giftJson,
        'created_at': time,
      });
    } catch (e) {
      Loggers.error('Story reaction save failed: $e');
    }
  }

  void sendReply(
      {required StoryItem item,
      required String textReply,
      String? imageReply}) {
    if (textReply.isEmpty && imageReply == null) return;
    User? user = item.story?.user;
    ChatThread conversation = ChatThread(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lastMsg: '',
        msgCount: 0,
        isDeleted: false,
        deletedId: 0,
        iAmBlocked: false,
        iBlocked: user?.isBlock ?? false,
        requestType: UserRequestAction.accept.title,
        chatType:
            user?.isFollowing ?? false ? ChatType.approved : ChatType.request,
        conversationId:
            [SessionManager.instance.getUserID(), user?.id].conversationId,
        userId: user?.id);
    conversation.chatUser = user?.appUser;

    var chattingController = Get.put(ChatScreenController(conversation.obs),
        tag: '${conversation.conversationId}');
    if (item.story != null) {
      HapticFeedback.mediumImpact();
      chattingController.sendStoryReply(
          story: item.story!, textReply: textReply, imageReply: imageReply);
      textEditingController.text = '';
      FocusManager.instance.primaryFocus?.unfocus();
      BaseController.share.showSnackBar(LKey.messageSent.tr);
    }
  }
}

class _QuestionMetaWatcher extends StatelessWidget {
  final int storyId;
  final void Function(String question) onQuestion;

  const _QuestionMetaWatcher({
    required this.storyId,
    required this.onQuestion,
  });

  @override
  Widget build(BuildContext context) {
    if (storyId <= 0) return const SizedBox();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('story_editor_meta')
          .doc(storyId.toString())
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final texts = (data?['texts'] as List?) ?? const [];
        String q = '';
        for (final e in texts) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final t = (m['text'] ?? '').toString();
          if (t.trimLeft().startsWith('__qst__:')) {
            q = t.trimLeft().replaceFirst('__qst__:', '').trim();
            break;
          }
        }
        onQuestion(q);
        return const SizedBox();
      },
    );
  }
}

class StoryBottomVIew extends StatelessWidget {
  final TextEditingController textEditingController;
  final FocusNode? focusNode;
  final VoidCallback onSendTap;
  final VoidCallback onGiftTap;
  final VoidCallback onLikeTap;
  final bool isGifted;
  final bool isLiked;

  const StoryBottomVIew(
      {super.key,
      required this.textEditingController,
      this.focusNode,
      required this.onSendTap,
      required this.onGiftTap,
      required this.onLikeTap,
      this.isGifted = false,
      this.isLiked = false});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: ShapeDecoration(
                    shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(cornerRadius: 30),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: .18))),
                  ),
                  child: TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 15),
                      border: InputBorder.none,
                      hintText: '${LKey.whatDoYouThink.tr}..',
                      hintStyle: TextStyleCustom.outFitLight300(
                          color: Colors.white, fontSize: 17, opacity: .42),
                      suffixIconConstraints: const BoxConstraints(),
                      suffixIcon: InkWell(
                        onTap: onSendTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            LKey.send.tr,
                            style: TextStyleCustom.unboundedMedium500(
                                fontSize: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    style: TextStyleCustom.outFitRegular400(
                        color: Colors.white, fontSize: 17),
                  ),
                ),
              ),
              InkWell(
                onTap: onGiftTap,
                child: Container(
                  height: 37,
                  width: 37,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: isGifted ? null : StyleRes.themeGradient,
                    color: isGifted ? themeAccentSolid(context) : null,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(AssetRes.icGift,
                      height: 20, width: 20, color: whitePure(context)),
                ),
              )
              ,
              InkWell(
                onTap: onLikeTap,
                child: Container(
                  height: 37,
                  width: 37,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLiked ? themeAccentSolid(context) : null,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22)),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    AssetRes.icFillHeart,
                    height: 18,
                    width: 18,
                    color: whitePure(context),
                  ),
                ),
              )
            ],
          ),
        ));
  }
}

/// Capsule holding the duration and shown property of each story. Passed down
/// to the pages bar to render the page indicators.
class PageData {
  Duration duration;
  bool shown;

  PageData(this.duration, this.shown);
}

/// Horizontal bar displaying a row of [StoryProgressIndicator] based on the
/// [pages] provided.
class PageBar extends StatefulWidget {
  final List<PageData> pages;
  final Animation<double>? animation;
  final IndicatorHeight indicatorHeight;
  final Color indicatorColor;

  const PageBar(
    this.pages,
    this.animation, {
    this.indicatorHeight = IndicatorHeight.large,
    this.indicatorColor = Colors.white,
    super.key,
  });

  @override
  State<StatefulWidget> createState() {
    return PageBarState();
  }
}

class PageBarState extends State<PageBar> {
  double spacing = 4;

  @override
  void initState() {
    super.initState();

    int count = widget.pages.length;
    spacing = (count > 15) ? 1 : ((count > 10) ? 2 : 4);

    widget.animation!.addListener(() {
      setState(() {});
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  bool isPlaying(PageData page) {
    return widget.pages.firstWhereOrNull((it) => !it.shown) == page;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: widget.pages.map((it) {
        return Expanded(
          child: Container(
            padding:
                EdgeInsets.only(right: widget.pages.last == it ? 0 : spacing),
            child: StoryProgressIndicator(
              isPlaying(it) ? widget.animation!.value : (it.shown ? 1 : 0),
              indicatorHeight:
                  widget.indicatorHeight == IndicatorHeight.large ? 5 : 3,
              indicatorColor: widget.indicatorColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Custom progress bar. Supposed to be lighter than the
/// original [ProgressIndicator], and rounded at the sides.
class StoryProgressIndicator extends StatelessWidget {
  /// From `0.0` to `1.0`, determines the progress of the indicator
  final double value;
  final double indicatorHeight;
  final Color indicatorColor;

  const StoryProgressIndicator(
    this.value, {
    super.key,
    this.indicatorHeight = 5,
    this.indicatorColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.fromHeight(
        indicatorHeight,
      ),
      foregroundPainter: IndicatorOval(
        indicatorColor.withValues(alpha: 0.8),
        value,
      ),
      painter: IndicatorOval(
        indicatorColor.withValues(alpha: 0.4),
        1.0,
      ),
    );
  }
}

class IndicatorOval extends CustomPainter {
  final Color color;
  final double widthFactor;

  IndicatorOval(this.color, this.widthFactor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width * widthFactor, size.height),
            const Radius.circular(3)),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

/// Concept source: https://stackoverflow.com/a/9733420
class ContrastHelper {
  static double luminance(int? r, int? g, int? b) {
    final a = [r, g, b].map((it) {
      double value = it!.toDouble() / 255.0;
      return value <= 0.03928
          ? value / 12.92
          : pow((value + 0.055) / 1.055, 2.4);
    }).toList();

    return a[0] * 0.2126 + a[1] * 0.7152 + a[2] * 0.0722;
  }

  static double contrast(rgb1, rgb2) {
    return luminance(rgb2[0], rgb2[1], rgb2[2]) /
        luminance(rgb1[0], rgb1[1], rgb1[2]);
  }
}
