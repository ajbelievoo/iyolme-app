import 'package:flutter/material.dart';
import 'package:shortzz/common/service/api/ad_event_service.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:url_launcher/url_launcher.dart';

class StoryAdView extends StatelessWidget {
  final String? imageUrl;
  final String? sponsoredLabel;
  final String? title;
  final String? cta;
  final String? destinationUrl;
  final int? adId;

  const StoryAdView({
    super.key,
    required this.imageUrl,
    required this.sponsoredLabel,
    required this.title,
    required this.cta,
    required this.destinationUrl,
    required this.adId,
  });

  Future<void> _openUrl() async {
    final raw = (destinationUrl ?? '').trim();
    if (raw.isEmpty) return;

    final uri = Uri.tryParse(raw);
    if (uri == null) return;

    try {
      final id = adId;
      if (id != null) {
        await AdEventService.instance.logAdEvent(
          eventType: 'click',
          adId: id,
          placement: 'story',
        );
      }
    } catch (_) {}

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        final id = adId;
        if (id != null) {
          try {
            await AdEventService.instance.logAdEvent(
              eventType: 'action',
              adId: id,
              placement: 'story',
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = (title ?? '').trim();
    final label = (sponsoredLabel ?? 'Sponsored').trim();
    final button = (cta ?? 'Learn more').trim();

    return GestureDetector(
      onTap: _openUrl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if ((imageUrl ?? '').isNotEmpty)
            Image.network(
              imageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.isEmpty ? 'Sponsored' : label,
                    style: TextStyle(
                      color: whitePure(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (t.isNotEmpty)
                    Text(
                      t,
                      style: TextStyle(
                        color: whitePure(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openUrl,
                      child: Text(button.isEmpty ? 'Learn more' : button),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
