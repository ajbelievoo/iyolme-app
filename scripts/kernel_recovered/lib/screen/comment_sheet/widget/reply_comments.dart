import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/widget/highlight_wrapper.dart';
import 'package:shortzz/model/post_story/comment/fetch_comment_model.dart';
import 'package:shortzz/screen/comment_sheet/comment_sheet_controller.dart';
import 'package:shortzz/screen/comment_sheet/widget/comment_card.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ReplyCommentsView extends StatelessWidget {
  final List<Comment> replyComments;
  final CommentSheetController controller;

  const ReplyCommentsView(
      {super.key, required this.replyComments, required this.controller});

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
          '[COMMENTS_DUP][ui_reply_render] source=${source.length} deduped=${out.length}');
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final list = _uiDedupe(replyComments);
    return ListView.builder(
      itemCount: list.length,
      primary: false,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        Comment comment = list[index];
        bool isNotify = false;
        if (controller.isFromNotification == true &&
            controller.commentBlinkId == null) {
          isNotify = (controller.replyComment?.id == comment.id);
          if (isNotify) {
            controller.commentBlinkId = controller.replyComment?.id;
          }
        }
        return HighlightWrapper(
          highlightColor: themeAccentSolid(context).withValues(alpha: 0.3),
          highlight: isNotify,
          child: CommentCard(
            comment: comment,
            controller: controller,
            isLikeButtonVisible: false,
            isReplyVisible: false,
          ),
        );
      },
    );
  }
}
d