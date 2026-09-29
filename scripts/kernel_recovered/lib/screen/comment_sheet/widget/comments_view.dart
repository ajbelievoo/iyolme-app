import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/widget/highlight_wrapper.dart';
import 'package:shortzz/common/widget/load_more_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/post_story/comment/fetch_comment_model.dart';
import 'package:shortzz/screen/comment_sheet/comment_sheet_controller.dart';
import 'package:shortzz/screen/comment_sheet/widget/comment_card.dart';
import 'package:shortzz/screen/comment_sheet/widget/reply_comments.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class CommentsView extends StatelessWidget {
  final CommentSheetController controller;

  const CommentsView({super.key, required this.controller});

  String _normalizeText(String input) {
    return input
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String _authorKey(Comment c) {
    final userId = (c.userId ?? c.user?.id)?.toString().trim() ?? '';
    if (userId.isNotEmpty) return 'id:$userId';
    final username = _normalizeText(c.user?.username ?? '');
    if (username.isNotEmpty) return 'u:$username';
    return '';
  }

  String _uiDedupeKey(Comment c) {
    final userId = _authorKey(c);
    final text = _normalizeText(c.comment ?? c.reply ?? '');

    if (userId.isNotEmpty && text.isNotEmpty) {
      return 'c:u:$userId|m:$text';
    }

    if (text.isNotEmpty) {
      return 'c:t:$text';
    }

    final id = c.id;
    if (id != null) return 'id:$id';
    return 'c:u:$userId|m:$text';
  }

  List<Comment> _uiDedupe(List<Comment> source) {
    final seen = <String>{};
    final out = <Comment>[];
    for (final c in source) {
      final k = _uiDedupeKey(c);
      if (seen.add(k)) {
        out.add(c);
      }
    }

    if (kDebugMode && out.length != source.length) {
      Loggers.warning(
          '[COMMENTS_DUP][ui_render] source=${source.length} deduped=${out.length}');
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final list = _uiDedupe(controller.getCommentsList);
        return GestureDetector(
          onTap: () {
            controller.commentHelper.detectableTextFocusNode.unfocus();
          },
          child: LoadMoreWidget(
            loadMore: controller.fetchComments,
            child: ListView.builder(
              itemCount: list.length,
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 5),
              itemBuilder: (context, index) {
                Comment comment = list[index];
                bool isNotify = false;
                if (controller.isFromNotification == true &&
                    controller.replyComment == null &&
                    controller.commentBlinkId == null) {
                  isNotify = (controller.comment?.id == comment.id);
                  if (isNotify) {
                    controller.commentBlinkId = controller.comment?.id;
                  }
                }
                return HighlightWrapper(
                  highlight: isNotify,
                  highlightColor:
                      themeAccentSolid(context).withValues(alpha: 0.3),
                  child:
                      CommentItems(controller: controller, comment: comment),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class CommentItems extends StatelessWidget {
  final Comment comment;
  final CommentSheetController controller;

  const CommentItems(
      {super.key, required this.comment, required this.controller});

  @override
  Widget build(BuildContext context) {
    int commentId = comment.id?.toInt() ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommentCard(
            controller: controller,
            comment: comment,
            isLikeButtonVisible: true,
            isReplyVisible: true),
        ReplyCommentSectionWidget(
          commentId: commentId,
          comment: comment,
          controller: controller,
        ),
      ],
    );
  }
}

class ReplyCommentSectionWidget extends StatelessWidget {
  final int commentId;
  final Comment comment;
  final CommentSheetController
      controller; // Replace with actual controller type

  const ReplyCommentSectionWidget(
      {super.key,
      required this.commentId,
      required this.comment,
      required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      List<Comment> replyComments =
          controller.getReplyCommentsList[commentId] ?? [];
      if ((comment.repliesCount ?? 0) <= 0) {
        return const SizedBox();
      }
      var count = (comment.repliesCount ?? 0) - replyComments.length;
      return Row(
        children: [
          const SizedBox(width: 45),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReplyCommentsView(
                    replyComments: replyComments, controller: controller),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: controller.isFetchReplyComment.value &&
                          comment.id == controller.replyCommentId.value
                      ? const CupertinoActivityIndicator(radius: 10)
                      : InkWell(
                          onTap: () {
                            if (count <= 0) {
                              controller.hideReplyComment(comment);
                            } else {
                              controller.fetchReplyComment(comment);
                            }
                          },
                          child: Row(
                            children: [
                              Container(
                                  height: 1,
                                  width: 30,
                                  color: textLightGrey(context)),
                              const SizedBox(width: 5),
                              Text(
                                (count) <= 0
                                    ? '${LKey.hide.tr} ${LKey.replies.tr}'
                                    : '${LKey.view.tr} $count ${LKey.replies.tr}',
                                style: TextStyleCustom.outFitRegular400(
                                  fontSize: 13,
                                  color: textLightGrey(context),
                                ),
                              )
                              // Text(
                              //   (comment.repliesCount ?? 0) <= 0
                              //       ? '${LKey.hide.tr} ${LKey.replies.tr}'
                              //       : '${LKey.view.tr} ${comment.repliesCount ?? 0} ${LKey.replies.tr}',
                              //   style: TextStyleCustom.outFitRegular400(
                              //     fontSize: 13,
                              //     color: textLightGrey(context),
                              //   ),
                              // )
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
