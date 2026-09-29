import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/professional_controller.dart';
import 'package:shortzz/screen/professional_dashboard_screen/monetization_form_screen.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/utilities/theme_res.dart';

class MonetizationPage extends StatelessWidget {
  const MonetizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ProfessionalController>()
        ? Get.find<ProfessionalController>()
        : Get.put(ProfessionalController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        foregroundColor: textDarkGrey(context),
        title: Text(
          'Monetization',
          style: TextStyle(color: textDarkGrey(context)),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'reset_monetization_local') {
                controller.clearLocalMonetizationSubmission();
                await controller.fetchAll();
                final server = controller.stats.value?.monetizationStatus ?? '';
                final local = controller.monetizationSubmittedLocal.value;
                BaseController.share.showSnackBar(
                  'Reset done. server=$server localSubmitted=$local',
                );
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'reset_monetization_local',
                child: Text('Reset monetization status'),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        final s = controller.stats.value;
        final status = s?.monetizationStatus ?? '';
        final targetsDone = s?.targetsComplete ?? false;
        final submittedLocal = controller.monetizationSubmittedLocal.value;
        final effectiveStatus = targetsDone
            ? (status == 'pending' && !submittedLocal ? '' : status)
            : '';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(status: effectiveStatus, targetsDone: targetsDone),
            const SizedBox(height: 20),

            Text(
              'Complete Targets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            _TargetTile(
              icon: Icons.favorite,
              title: 'Likes',
              value: s?.likes ?? 0,
              target: s?.requiredLikes ?? 0,
            ),
            _TargetTile(
              icon: Icons.remove_red_eye,
              title: 'Views',
              value: s?.views ?? 0,
              target: s?.requiredViews ?? 0,
            ),
            _TargetTile(
              icon: Icons.comment,
              title: 'Comments',
              value: s?.comments ?? 0,
              target: s?.requiredComments ?? 0,
            ),

            const SizedBox(height: 24),

            if (status != 'approved')
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.monetization_on_outlined),
                  onPressed: (targetsDone && effectiveStatus != 'pending')
                      ? () {
                          Get.to(() => MonetizationFormScreen(
                                controller: controller,
                              ));
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  label: Text(
                    !targetsDone
                        ? 'Complete all targets'
                        : effectiveStatus == 'pending'
                            ? 'Under Review'
                            : 'Apply for Monetization',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            const _InfoNotes(),
          ],
        );
      }),
    );
  }
}

/* ================= STATUS BANNER ================= */

class _StatusBanner extends StatelessWidget {
  final String status;
  final bool targetsDone;
  const _StatusBanner({required this.status, required this.targetsDone});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (!targetsDone) {
      color = Colors.blueGrey;
      text = 'Complete targets to apply for monetization';
    } else {
      switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Monetization Approved';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Application Under Review';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Application Rejected';
        break;
      default:
        color = Colors.blueGrey;
        text = 'Monetization Not Applied';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ================= TARGET TILE ================= */

class _TargetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int value;
  final int target;

  const _TargetTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final double progress =
    target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0).toDouble();

    final isDone = target > 0 && value >= target;
    final accent = isDone ? Colors.green : themeAccentSolid(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textLightGrey(context).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textDarkGrey(context),
                  ),
                ),
              ),
              Text(
                '$value / $target',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textLightGrey(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}

/* ================= INFO BOX ================= */

class _InfoNotes extends StatelessWidget {
  const _InfoNotes();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textLightGrey(context).withValues(alpha: 0.16)),
      ),
      child: const Text(
        '• Monetization unlocks after completing all targets\n'
            '• Fake engagement may lead to rejection\n'
            '• Review time: 24–48 hours',
        style: TextStyle(height: 1.5),
      ),
    );
  }
}
