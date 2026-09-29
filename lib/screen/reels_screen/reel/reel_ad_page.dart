import 'package:flutter/material.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/api/ad_event_service.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ReelAdPage extends StatelessWidget {
  final Post adPost;

  const ReelAdPage({super.key, required this.adPost});

  Future<void> _openUrl() async {
    final raw = (adPost.sponsoredUrl ?? '').trim();
    if (raw.isEmpty) return;

    final uri = Uri.tryParse(raw);
    if (uri == null) return;

    try {
      final adId = adPost.sponsoredAdId;
      if (adId != null) {
        await AdEventService.instance.logAdEvent(
          eventType: 'click',
          adId: adId,
          contentUserId: adPost.userId,
          placement: 'reels',
        );
      }
    } catch (_) {}

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        final adId = adPost.sponsoredAdId;
        if (adId != null) {
          try {
            await AdEventService.instance.logAdEvent(
              eventType: 'action',
              adId: adId,
              contentUserId: adPost.userId,
              placement: 'reels',
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = (adPost.description ?? '').trim();
    final cta = (adPost.sponsoredCta ?? 'Learn more').trim();
    final adId = adPost.sponsoredAdId;
    
    // Debug logging for thumbnail URL
    final rawThumbnail = adPost.thumbnail ?? '';
    final finalUrl = rawThumbnail.addBaseURL();
    Loggers.info('[AD_DEBUG] ReelAdPage - Raw thumbnail: $rawThumbnail');
    Loggers.info('[AD_DEBUG] ReelAdPage - Final URL: $finalUrl');
    Loggers.info('[AD_DEBUG] ReelAdPage - isAd: ${adPost.isAd}, feedItemType: ${adPost.feedItemType}');

    return VisibilityDetector(
      key: ValueKey('reel_ad_${adPost.id ?? adId ?? ''}'),
      onVisibilityChanged: (info) async {
        if (info.visibleFraction <= 0.6) return;
        if (adId == null) return;
        try {
          await AdEventService.instance.logAdEvent(
            eventType: 'view',
            adId: adId,
            contentUserId: adPost.userId,
            placement: 'reels',
          );
        } catch (_) {}
      },
      child: Scaffold(
        backgroundColor: blackPure(context),
        body: SafeArea(
          child: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // FIXED: Constrained image that fills screen properly
                if ((adPost.thumbnail ?? '').isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      (adPost.thumbnail ?? '').addBaseURL(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[900],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, error, __) {
                        Loggers.info('[AD_DEBUG] Image load ERROR: $error');
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    color: Colors.red[900],
                    child: const Center(
                      child: Text(
                        'NO THUMBNAIL URL',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
                // Content at bottom
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adPost.sponsoredLabel ?? 'Sponsored',
                          style: TextStyle(
                            color: whitePure(context).withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (title.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              color: whitePure(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openUrl,
                            child: Text(cta.isEmpty ? 'Learn more' : cta),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
