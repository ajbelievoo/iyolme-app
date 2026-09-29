import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:get/get.dart';
import 'package:shortzz/model/chat/message_data.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatTextMessage extends StatelessWidget {
  final bool isMe;
  final MessageData message;

  const ChatTextMessage({super.key, required this.isMe, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      constraints: BoxConstraints(maxWidth: Get.width / 1.3),
      decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
              borderRadius:
                  SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1),
              side: isMe
                  ? BorderSide.none
                  : BorderSide(
                      color: bgGrey(context),
                      strokeAlign: BorderSide.strokeAlignInside)),
          color: isMe ? null : bgLightGrey(context),
          gradient: isMe ? StyleRes.themeGradient : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyTo != null) ...[
            Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5), width: 1)),
                child: Text(
                  (message.replyTo?['text_message'] != null &&
                          message.replyTo!['text_message'].isNotEmpty)
                      ? message.replyTo!['text_message']
                      : (message.replyTo?['message_type']
                              ?.toString()
                              .capitalize ??
                          'Message'),
                  style: TextStyleCustom.outFitRegular400(
                      color: isMe
                          ? whitePure(context).withValues(alpha: 0.8)
                          : textDarkGrey(context).withValues(alpha: 0.8),
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
          ],
          Linkify(
            onOpen: (link) async {
              if (!await launchUrl(Uri.parse(link.url),
                  mode: LaunchMode.externalApplication)) {
                // throw Exception('Could not launch ${link.url}');
              }
            },
            text: message.textMessage ?? '',
            style: TextStyleCustom.outFitRegular400(
                color: isMe ? whitePure(context) : textDarkGrey(context),
                fontSize: 16),
            linkStyle: TextStyleCustom.outFitRegular400(
                    color: isMe ? whitePure(context) : Colors.blue,
                    fontSize: 16)
                .copyWith(decoration: TextDecoration.underline),
          ),
        ],
      ),
    );
  }
}
T