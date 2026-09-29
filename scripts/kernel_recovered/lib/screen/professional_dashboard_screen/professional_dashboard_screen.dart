import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/ads_controller.dart';
import 'package:shortzz/common/controller/professional_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/manager/economy_state.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/utils/format.dart';
import 'package:shortzz/model/professional/leaderboard_model.dart';
import 'package:shortzz/screen/ads_hub/create_ad_request_screen.dart';
import 'package:shortzz/screen/professional_dashboard_screen/monetization_form_screen.dart';
import 'package:shortzz/screen/professional_dashboard_screen/enable_professional_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:shortzz/screen/ads_manager/screen/advertiser_dashboard/advertiser_dashboard_screen.dart';
import 'package:shortzz/common/manager/logger.dart';
// Removed EconomyBadge from this screen header for a cleaner, more professional look

class ProfessionalDashboardScreen extends StatelessWidget {
  const ProfessionalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfessionalController());
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: scaffoldBackgroundColor(context),
          foregroundColor: textDarkGrey(context),
          elevation: 0.6,
          title: Text(
            'Professional Dashboard',
            style: TextStyle(
              color: textDarkGrey(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.fetchAll,
              icon: Icon(Icons.refresh, color: textDarkGrey(context)),
            ),
          ],
          // Keep header minimal per request – no wallet/status actions here
          bottom: TabBar(
            isScrollable: true,
            labelColor: textDarkGrey(context),
            unselectedLabelColor: textLightGrey(context).withValues(alpha: 0.9),
            indicatorColor: themeAccentSolid(context),
            dividerColor: textLightGrey(context).withValues(alpha: 0.15),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Ads'),
              Tab(text: 'Tasks'),
              Tab(text: 'Leaderboard'),
              Tab(text: 'Earnings'),
            ],
          ),
        ),
        body: Obx(() {
          final enabled =
              (controller.stats.value?.professionalEnabled ?? false) ||
                  controller.localProfessionalEnabled.value;
          // If not enabled, show Enable screen instead of dashboard
          if (!enabled) {
            return const EnableProfessionalScreen();
          }

          return TabBarView(
            children: [
              _OverviewTab(controller: controller),
              _AdsTab(controller: controller),
              _TasksTab(controller: controller),
              _LeaderboardTab(controller: controller),
              const _EarningsTab(),
            ],
          );
        }),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller});

  final ProfessionalController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.stats.value == null && controller.isLoading.value)
            const _CardSkeleton(height: 190)
          else
            _StatsCard(controller: controller),
          Obx(() {
            final s = controller.stats.value;
            if (s == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _RatesAndConversionsCard(stats: s),
            );
          }),
          const SizedBox(height: 16),
          Obx(() {
            final enabled =
                (controller.stats.value?.professionalEnabled ?? false) ||
                    controller.localProfessionalEnabled.value;
            if (enabled) {
              return SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final ok = await _confirmDisable(context);
                    if (ok == true) {
                      await controller.disableProfessional();
                    }
                  },
                  icon: const Icon(Icons.power_settings_new, color: Colors.red),
                  label: const Text('Off Professional'),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

class _AdsTab extends StatelessWidget {
  const _AdsTab({required this.controller});

  final ProfessionalController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            surfaceTintColor: Theme.of(context).cardColor,
            color: Theme.of(context).cardColor,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: textLightGrey(context).withValues(alpha: 0.16)),
            ),
            child: ListTile(
              leading: Icon(Icons.campaign_outlined,
                  color: textDarkGrey(context).withValues(alpha: 0.85)),
              title: const Text(
                'Ads Manager',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Dashboard • Campaigns • Wallet • Earnings',
              ),
              trailing: Icon(Icons.chevron_right,
                  color: textLightGrey(context)),
              onTap: () {
                Get.to(() => const AdvertiserDashboardScreen(),
                    preventDuplicates: false);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            surfaceTintColor: Theme.of(context).cardColor,
            color: Theme.of(context).cardColor,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: textLightGrey(context).withValues(alpha: 0.16)),
            ),
            child: ListTile(
              leading: Icon(Icons.add_box_outlined,
                  color: textDarkGrey(context).withValues(alpha: 0.85)),
              title: const Text(
                'Create Ad ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Submit a platform ad for admin approval'),
              trailing: Icon(Icons.chevron_right,
                  color: textLightGrey(context)),
              onTap: () {
                Get.to(() => const CreateAdRequestScreen(),
                    preventDuplicates: false);
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'How it works: You can boost a post to send a request. Platform ads / admin promotions are managed by the admin team.',
            style: TextStyle(
              fontSize: 13,
              color: textLightGrey(context),
            ),
          ),
        ],
      ),
    );
  }
 }

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.controller});
  final ProfessionalController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TasksSection(controller: controller),
        ],
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({required this.controller});
  final ProfessionalController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.fetchAll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.lbInitialLoading.value)
                const Column(
                  children: [
                    _CardSkeleton(height: 70),
                    SizedBox(height: 8),
                    _CardSkeleton(height: 70),
                    SizedBox(height: 8),
                    _CardSkeleton(height: 70),
                  ],
                )
              else
                SizedBox(
                  height: constraints.maxHeight,
                  child: _LeaderboardSection(controller: controller),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EarningsTab extends StatelessWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Earnings (read-only)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final coins = EconomyState.instance.coins.value;
          final points = EconomyState.instance.points.value;
          final earnings = EconomyState.instance.earnings.value;
          return Column(
            children: [
              _MiniStatTile(label: 'IYOL', value: coins.toString()),
              const SizedBox(height: 10),
              _MiniStatTile(label: 'Points', value: points.toString()),
              const SizedBox(height: 10),
              _MiniStatTile(label: 'Earnings', value: earnings.toStringAsFixed(2)),
            ],
          );
        }),
        const SizedBox(height: 12),
        Text(
          'Note: yahan se sirf summary dikhayi ja rahi hai. Withdrawal/Wallet actions profile/wallet me rahenge (ads related nahi).',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  const _MiniStatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.75),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.controller});
  final ProfessionalController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.stats.value;
    final canShowMonetization = s?.canShowMonetization ?? true;
    final isMinerOnly = s?.isMinerOnly ?? false;
    final typeLabel = () {
      final t = s?.professionalType ?? '';
      if (t == 'creator_miner') return 'Creator + Miner';
      if (t == 'business') return 'Business';
      if (t == 'astrologer') return 'Astrologer';
      if (t == 'miner') return 'Miner';
      return 'Creator';
    }();
    return Card(
      elevation: 0,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Stats', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Obx(() {
                  final status = EconomyState.instance.monetizationStatus.value;
                  final submittedLocal = controller.monetizationSubmittedLocal.value;
                  final effectiveStatus = (status == 'pending' && !submittedLocal) ? '' : status;
                  if (!canShowMonetization) {
                    return const SizedBox.shrink();
                  }
                  Color color;
                  switch (effectiveStatus) {
                    case 'approved':
                      color = Colors.green;
                      break;
                    case 'pending':
                      color = Colors.orange;
                      break;
                    case 'rejected':
                      color = Colors.red;
                      break;
                    default:
                      color = Colors.grey;
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text((effectiveStatus.isEmpty ? 'not_set' : effectiveStatus).toUpperCase(),
                            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: controller.fetchAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric('Likes', s?.likes ?? 0),
                _metric('Views', s?.views ?? 0),
                _metric('Comments', s?.comments ?? 0),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric('Points', s?.points ?? 0),
                _metric('IYOL', s?.coins ?? 0),
                _metric('Earnings', formatCurrency(s?.earnings ?? 0)),
              ],
            ),
            const SizedBox(height: 12),
            Obx(() {
              final status = EconomyState.instance.monetizationStatus.value;
              final submittedLocal = controller.monetizationSubmittedLocal.value;
              final effectiveStatus = (status == 'pending' && !submittedLocal) ? '' : status;
              final targetsDone = controller.stats.value?.targetsComplete ?? false;
              if (!canShowMonetization) {
                return const SizedBox.shrink();
              }
              // Approved chip
              if (effectiveStatus == 'approved') {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.verified, color: Colors.green, size: 18),
                    label: const Text(
                      'Approved',
                      style: TextStyle(
                        color: Colors.green, // 👈 text green
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }

              // Pending state button (disabled)
              if (effectiveStatus == 'pending') {
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.timelapse_outlined),
                    label: const Text('Pending Review'),
                  ),
                );
              }
              // Monetize CTA with gating on targets
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: targetsDone
                      ? () {
                          Get.to(() => MonetizationFormScreen(controller: controller));
                        }
                      : null,
                  icon: const Icon(Icons.monetization_on_outlined),
                  label: Text(targetsDone ? 'Monetize' : 'Complete targets to Monetize'),
                ),
              );
            }),
            const SizedBox(height: 8),
            // Miner info box
            if (isMinerOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '⛏ Miner Mode\nLike, watch and comment on posts to earn points.\nPoints convert into IYOL automatically.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, Object value) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _RatesAndConversionsCard extends StatelessWidget {
  const _RatesAndConversionsCard({required this.stats});
  final dynamic stats;

  String _fmtNum(num v) {
    // Keep output readable: 2 decimals max, trim trailing zeros
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    num? n(dynamic v) => v is num ? v : null;

    final likePoints = n(stats.likePoints);
    final viewPoints = n(stats.viewPoints);
    final commentPoints = n(stats.commentPoints);
    final creditsPerToken = n(stats.creditsPerToken);
    final tokenPerCredit = n(stats.tokenPerCredit);
    final tokenPerDollar = n(stats.tokenPerDollar);
    final dollarPerToken = n(stats.dollarPerToken);
    final pointsPerToken = n(stats.pointsPerToken);
    final tokenPerPoint = n(stats.tokenPerPoint);

    final bool isMinerOnly = (stats.isMinerOnly == true);
    final bool isCreatorMiner = (stats.professionalType?.toString().toLowerCase() == 'creator_miner');
    final bool minerApplies = isMinerOnly || isCreatorMiner;

    String v(num? value) => value == null ? 'NOT_SET' : _fmtNum(value);

    return Card(
      elevation: 0,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rates & Conversions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              'Miner (Points earning)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              minerApplies
                  ? 'Applies to Miner mode'
                  : 'Only Miner users earn points for like/watch/comment',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            _InfoRow(label: 'Like points', value: v(likePoints)),
            _InfoRow(label: 'Watch/View points', value: v(viewPoints)),
            _InfoRow(label: 'Comment points', value: v(commentPoints)),
            const SizedBox(height: 12),
            Text(
              'Token / Credits',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 6),
            _InfoRow(label: '1 Token = Points', value: v(pointsPerToken)),
            _InfoRow(label: '1 Point = Token', value: v(tokenPerPoint)),
            _InfoRow(label: '1 Token = Credits', value: v(creditsPerToken)),
            _InfoRow(label: '1 Credit = Token', value: v(tokenPerCredit)),
            _InfoRow(label: '\$1 = Tokens', value: v(tokenPerDollar)),
            _InfoRow(label: '1 Token = \$ (USD)', value: v(dollarPerToken)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TasksSection extends StatelessWidget {
  const _TasksSection({required this.controller});
  final ProfessionalController controller;

  String _typeLabel(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'like':
        return 'Like';
      case 'view':
        return 'Watch';
      case 'comment':
        return 'Comment';
      case 'ad':
        return 'Watch Ad';
      default:
        return (type ?? '').isEmpty ? 'Task' : (type ?? '');
    }
  }

  IconData _typeIcon(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'like':
        return Icons.favorite_outline;
      case 'view':
        return Icons.play_circle_outline;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'ad':
        return Icons.local_play_outlined;
      default:
        return Icons.task_alt;
    }
  }

  Color _typeColor(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'like':
        return Colors.pink;
      case 'view':
        return Colors.blue;
      case 'comment':
        return Colors.green;
      case 'ad':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.emoji_events_outlined, 
                    color: Colors.amber.shade800, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Daily Tasks', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh tasks',
                  onPressed: controller.refreshTasks,
                )
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Complete daily tasks to earn points',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              if (controller.isLoading.value && controller.tasks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (controller.tasks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, 
                          size: 48, 
                          color: Colors.black.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No tasks available today',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Check back tomorrow for new tasks!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final visibleTasks = controller.tasks
                  .where((t) => (t.requiredCount ?? 0) > 0)
                  .toList();

              // DEBUG: Show task counts
              Loggers.info('[TASK_UI] Total tasks: ${controller.tasks.length}, Visible: ${visibleTasks.length}');
              for (final t in controller.tasks) {
                Loggers.info('[TASK_UI]   Task id=${t.id}, type=${t.type}, required=${t.requiredCount}, progress=${t.progressCount}, completed=${t.completed}');
              }

              if (visibleTasks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'No active tasks available',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (controller.tasks.isNotEmpty)
                          Text(
                            '(${controller.tasks.length} tasks hidden - requiredCount is 0)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: visibleTasks.asMap().entries.map((entry) {
                  final t = entry.value;
                  final isLast = entry.key == visibleTasks.length - 1;
                  final isCompleted = t.completed == true;
                  final progress = (t.progressCount ?? 0);
                  final required = (t.requiredCount ?? 1);
                  final progressPercent = (progress / required).clamp(0.0, 1.0);
                  final typeColor = _typeColor(t.type);
                  
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCompleted 
                            ? Colors.green.withValues(alpha: 0.05)
                            : typeColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted
                              ? Colors.green.withValues(alpha: 0.3)
                              : typeColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : typeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.check : _typeIcon(t.type),
                                    color: isCompleted ? Colors.green : typeColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.title ?? 'Task',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_typeLabel(t.type)} • +${t.points ?? 0} pts',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isCompleted ? 'Completed' : 'In Progress',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isCompleted 
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progressPercent,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey.withValues(
                                            alpha: 0.2),
                                          valueColor: AlwaysStoppedAnimation(
                                            isCompleted ? Colors.green : typeColor),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$progress / $required completed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isCompleted) ...[
                                  const SizedBox(width: 12),
                                  _ActionButton(
                                    type: t.type,
                                    onTap: () => _navigateToTask(context, t.type, controller),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _navigateToTask(BuildContext context, String? type, ProfessionalController controller) async {
    final taskType = (type ?? '').toLowerCase();
    switch (taskType) {
      case 'like':
      case 'like_reel':
      case 'like_feed':
        // Like task - Navigate to reels with only unliked posts
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
          
          // Find the like task (check all like variants)
          final likeTask = controller.tasks.firstWhereOrNull(
            (t) => (t.type?.toLowerCase() == 'like' || 
                    t.type?.toLowerCase() == 'like_reel' ||
                    t.type?.toLowerCase() == 'like_feed') && (t.completed != true),
          );
          
          if (likeTask == null || (likeTask.id ?? 0) <= 0) {
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No active like task found. Refresh and try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            break;
          }
          
          // For like_feed, fetch regular posts, for like_reel/like, fetch reels
          final isFeedTask = likeTask.type?.toLowerCase() == 'like_feed';
          final posts = await PostService.instance.fetchPostsDiscover(
            type: isFeedTask ? '0' : '1', // 0 = feed posts, 1 = reels
          );
          
          if (context.mounted) Navigator.pop(context);
          
          // Filter to only unliked posts
          final unlikedPosts = posts.where((p) => p.isLiked != true).toList();
          
          if (unlikedPosts.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No posts available to like at this time'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          
          // Navigate to reels/feed screen with unliked posts
          final reels = unlikedPosts.toList().obs;
          ReelsScreenController.prewarm(
            reels: reels,
            position: 0,
            isHomePage: false,
            isFromTask: true, // Flag to indicate task flow for 15-sec delay
            taskType: likeTask.type, // Pass task type
            onLikeAction: (postId) async {
              // When user likes a post, update task progress
              Loggers.info('[TASK_LIKE] Post liked: $postId - updating task progress');
              try {
                final result = await controller.completeTask(likeTask.id!);
                
                // Show progress or completion message
                final currentTask = controller.tasks.firstWhereOrNull((t) => t.id == likeTask.id);
                final isFullyCompleted = currentTask?.completed == true;
                final progressText = '${currentTask?.progressCount ?? 1}/${likeTask.requiredCount ?? 5}';
                
                if (context.mounted) {
                  if (isFullyCompleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Task Complete! +${likeTask.points ?? 0} points earned!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Progress: $progressText posts liked'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              } catch (e) {
                Loggers.info('[TASK_LIKE] Error updating task: $e');
              }
            },
          ).then((tag) {
            Get.to(() => ReelsScreen(
              reels: reels,
              position: 0,
              controllerTag: tag,
            ));
          });
        } catch (e) {
          if (context.mounted) Navigator.pop(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading reels: $e')),
            );
          }
        }
        break;
      case 'view':
      case 'view_reel':
      case 'view_post':
        // View task - Navigate to any reels/posts
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
          
          // Find the view task (check all view variants)
          final viewTask = controller.tasks.firstWhereOrNull(
            (t) => (t.type?.toLowerCase() == 'view' || 
                    t.type?.toLowerCase() == 'view_reel' ||
                    t.type?.toLowerCase() == 'view_post') && (t.completed != true),
          );
          
          if (viewTask == null || (viewTask.id ?? 0) <= 0) {
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No active view task found. Refresh and try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            break;
          }
          
          // For view_post, fetch regular posts, for view_reel/view, fetch reels
          final isFeedTask = viewTask.type?.toLowerCase() == 'view_post';
          final posts = await PostService.instance.fetchPostsDiscover(
            type: isFeedTask ? '0' : '1',
          );
          
          if (context.mounted) Navigator.pop(context);
          
          if (posts.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No reels available right now')),
              );
            }
            return;
          }
          
          final reels = posts.toList().obs;
          ReelsScreenController.prewarm(
            reels: reels,
            position: 0,
            isHomePage: false,
            onViewAction: (postId) async {
              Loggers.info('[TASK_VIEW] Post viewed: $postId - updating task progress');
              try {
                final result = await controller.completeTask(viewTask.id!);
                
                final currentTask = controller.tasks.firstWhereOrNull((t) => t.id == viewTask.id);
                final isFullyCompleted = currentTask?.completed == true;
                final progressText = '${currentTask?.progressCount ?? 1}/${viewTask.requiredCount ?? 5}';
                
                if (context.mounted) {
                  if (isFullyCompleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Task Complete! +${viewTask.points ?? 0} points earned!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Progress: $progressText reels watched'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              } catch (e) {
                Loggers.info('[TASK_VIEW] Error updating task: $e');
              }
            },
          ).then((tag) {
            Get.to(() => ReelsScreen(
              reels: reels,
              position: 0,
              controllerTag: tag,
            ));
          });
        } catch (e) {
          if (context.mounted) Navigator.pop(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading reels: $e')),
            );
          }
        }
        break;
      case 'comment':
        // Comment task - Navigate to reels with posts that need comments
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
          
          // Find the comment task first
          final commentTask = controller.tasks.firstWhereOrNull(
            (t) => t.type?.toLowerCase() == 'comment' && (t.completed != true),
          );
          
          if (commentTask == null || (commentTask.id ?? 0) <= 0) {
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No active comment task found. Refresh and try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            break;
          }
          
          final posts = await PostService.instance.fetchPostsDiscover(
            type: '1',
          );
          
          if (context.mounted) Navigator.pop(context);
          
          if (posts.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No posts available to comment at this time')),
              );
            }
            return;
          }
          
          final reels = posts.toList().obs;
          ReelsScreenController.prewarm(
            reels: reels,
            position: 0,
            isHomePage: false,
            onCommentAction: (postId) async {
              Loggers.info('[TASK_COMMENT] Comment added: $postId - updating task progress');
              try {
                final result = await controller.completeTask(commentTask.id!);
                
                final currentTask = controller.tasks.firstWhereOrNull((t) => t.id == commentTask.id);
                final isFullyCompleted = currentTask?.completed == true;
                final progressText = '${currentTask?.progressCount ?? 1}/${commentTask.requiredCount ?? 5}';
                
                if (context.mounted) {
                  if (isFullyCompleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Task Complete! +${commentTask.points ?? 0} points earned!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Progress: $progressText comments added'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              } catch (e) {
                Loggers.info('[TASK_COMMENT] Error updating task: $e');
              }
            },
          ).then((tag) {
            Get.to(() => ReelsScreen(
              reels: reels,
              position: 0,
              controllerTag: tag,
            ));
          });
        } catch (e) {
          if (context.mounted) Navigator.pop(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading reels: $e')),
            );
          }
        }
        break;
      case 'share':
      case 'share_reel':
      case 'share_post':
        // Share task - Navigate to reels/posts with 15-sec delay for action buttons
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
          
          // Find the share task (check all share variants)
          final shareTask = controller.tasks.firstWhereOrNull(
            (t) => (t.type?.toLowerCase() == 'share' || 
                    t.type?.toLowerCase() == 'share_reel' ||
                    t.type?.toLowerCase() == 'share_post') && (t.completed != true),
          );
          
          if (shareTask == null || (shareTask.id ?? 0) <= 0) {
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No active share task found. Refresh and try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            break;
          }
          
          // For share_post, fetch regular posts, for share_reel/share, fetch reels
          final isFeedTask = shareTask.type?.toLowerCase() == 'share_post';
          final posts = await PostService.instance.fetchPostsDiscover(
            type: isFeedTask ? '0' : '1', // 0 = feed posts, 1 = reels
          );
          
          if (context.mounted) Navigator.pop(context);
          
          if (posts.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No posts available to share at this time'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          
          // Navigate to reels/feed screen with posts
          final reels = posts.toList().obs;
          ReelsScreenController.prewarm(
            reels: reels,
            position: 0,
            isHomePage: false,
            isFromTask: true, // Flag to enable 15-sec delay
            taskType: shareTask.type,
            onViewAction: (postId) async {
              // Note: Share action is tracked via ShareManager
              // We still need to call completeTask when user shares
              Loggers.info('[TASK_SHARE] Post shared: $postId - updating task progress');
              try {
                final result = await controller.completeTask(shareTask.id!);
                
                // Show progress or completion message
                final currentTask = controller.tasks.firstWhereOrNull((t) => t.id == shareTask.id);
                final isFullyCompleted = currentTask?.completed == true;
                final progressText = '${currentTask?.progressCount ?? 1}/${shareTask.requiredCount ?? 5}';
                
                if (context.mounted) {
                  if (isFullyCompleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Task Complete! +${shareTask.points ?? 0} points earned!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Progress: $progressText posts shared'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              } catch (e) {
                Loggers.info('[TASK_SHARE] Error updating task: $e');
              }
            },
          ).then((tag) {
            Get.to(() => ReelsScreen(
              reels: reels,
              position: 0,
              controllerTag: tag,
            ));
          });
        } catch (e) {
          if (context.mounted) Navigator.pop(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading reels: $e')),
            );
          }
        }
        break;
      case 'ad':
        // Show reward ad and complete task - FIXED: Use new showRewardedAd method
        Loggers.info('[TASK_AD] Starting ad task flow');
        Loggers.info('[TASK_AD] Available tasks: ${controller.tasks.length}');
        for (final t in controller.tasks) {
          Loggers.info('[TASK_AD] Task: id=${t.id}, type=${t.type}, completed=${t.completed}, required=${t.requiredCount}, progress=${t.progressCount}');
        }
        
        final adsController = Get.isRegistered<AdsController>() 
            ? Get.find<AdsController>() 
            : Get.put(AdsController());
        
        Loggers.info('[TASK_AD] Rewarded ad available: ${adsController.rewardedAd != null}');
        
        // Find the ad task first
        final adTask = controller.tasks.firstWhereOrNull(
          (t) => t.type?.toLowerCase() == 'ad' && (t.completed != true),
        );
        
        if (adTask == null || (adTask.id ?? 0) <= 0) {
          Loggers.info('[TASK_AD] No incomplete ad task found!');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active ad task found. Refresh and try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;
        }
        
        Loggers.info('[TASK_AD] Found ad task: ${adTask.id}, title: ${adTask.title}');
        
        // Show the rewarded ad using the new method
        final rewardEarned = await adsController.showRewardedAd(
          onRewardEarned: (reward) async {
            Loggers.info('[TASK_AD] User earned reward callback fired: ${reward.amount} ${reward.type}');
            
            // Complete the ad task
            Loggers.info('[TASK_AD] Calling completeTask API for task ${adTask.id}');
            try {
              final result = await controller.completeTask(adTask.id!);
              Loggers.info('[TASK_AD] completeTask result: status=${result.status}, message=${result.message}');
              
              if (result.status == true) {
                Loggers.info('[TASK_AD] Task progress updated successfully!');
                
                // Check if task is fully completed
                final currentTask = controller.tasks.firstWhereOrNull((t) => t.id == adTask.id);
                final isFullyCompleted = currentTask?.completed == true;
                final progressText = '${currentTask?.progressCount ?? 1}/${adTask.requiredCount ?? 400}';
                
                if (context.mounted) {
                  if (isFullyCompleted) {
                    // Task fully completed - show points earned
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Task Complete! +${adTask.points ?? 0} points earned!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // Partial progress - show progress update only
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Progress: $progressText ads watched'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              } else {
                Loggers.info('[TASK_AD] Task completion failed: ${result.message}');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: ${result.message ?? "Unknown error"}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              Loggers.info('[TASK_AD] Error calling completeTask: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
        
        // Show feedback if no reward earned
        if (!rewardEarned && context.mounted) {
          Loggers.info('[TASK_AD] Ad dismissed without earning reward');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Watch the full ad to earn points!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;
      default:
        break;
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.type, required this.onTap});
  final String? type;
  final VoidCallback onTap;

  String _getLabel() {
    switch ((type ?? '').toLowerCase()) {
      case 'like':
      case 'like_reel':
      case 'like_feed':
        return 'Like Posts';
      case 'view':
      case 'view_reel':
      case 'view_post':
        return 'Watch Reels';
      case 'comment':
        return 'Comment';
      case 'share':
      case 'share_reel':
      case 'share_post':
        return 'Share Posts';
      case 'ad':
        return 'Watch Ad';
      default:
        return 'Start';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _getLabel(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.controller});
  final ProfessionalController controller;

  String _name(LeaderboardEntry e) {
    return e.professionalName ?? e.fullname ?? e.username ?? '';
  }

  Widget _buildRankBadge(int rank, bool isMe) {
    Color badgeColor;
    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
    } else {
      badgeColor = Colors.black.withValues(alpha: 0.6);
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: rank <= 3 ? badgeColor.withValues(alpha: 0.15) : Colors.transparent,
        shape: BoxShape.circle,
        border: rank <= 3
            ? Border.all(color: badgeColor.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          rank > 0 ? '$rank' : '-',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: rank <= 3 ? 16 : 14,
            color: rank <= 3 ? badgeColor.withValues(alpha: 0.8) : badgeColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and toggle
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, 
                  color: Color(0xFFFFA000), size: 24),
                const SizedBox(width: 8),
                Text(
                  'Leaderboard', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _buildTypeToggle(),
              ],
            ),
            const SizedBox(height: 16),
            // List with infinite scroll and shimmer - EXPANDED TO FULL HEIGHT
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scroll) {
                  if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 80) {
                    if (controller.lbHasMore && !controller.lbLoadingMore.value) {
                      controller.loadMoreLeaderboard();
                    }
                  }
                  return false;
                },
                child: Obx(() {
                  final initialLoading = controller.lbInitialLoading.value;
                  final data = controller.leaderboard;

                  if (initialLoading) {
                    return ListView.builder(
                      itemCount: 8,
                      itemBuilder: (_, i) => const _LeaderboardRowSkeleton(),
                    );
                  }

                  if (data.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.leaderboard_outlined,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No leaderboard data yet.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete tasks to climb the ranks!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: data.length + (controller.lbLoadingMore.value ? 3 : 0),
                    itemBuilder: (context, index) {
                      if (index >= data.length) {
                        return const _LeaderboardRowSkeleton();
                      }
                      
                      final e = data[index];
                      final isMe = (e.userId ?? -1) == SessionManager.instance.getUserID();
                      final rank = e.rank ?? 0;
                      final score = e.score ?? 0;
                      final photo = (e.profilePhoto ?? '').trim();
                      final isMiner = controller.leaderboardType.value == 'miner';
                      
                      return _buildLeaderboardRow(
                        context: context,
                        entry: e,
                        isMe: isMe,
                        rank: rank,
                        score: score,
                        photo: photo,
                        isMiner: isMiner,
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Obx(() {
      final isCreator = controller.leaderboardType.value == 'creator';
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton(
              label: 'Creator',
              isSelected: isCreator,
              onTap: () => controller.fetchLeaderboard('creator'),
              icon: Icons.video_library_outlined,
            ),
            _buildToggleButton(
              label: 'Miner',
              isSelected: !isCreator,
              onTap: () => controller.fetchLeaderboard('miner'),
              icon: Icons.local_fire_department_outlined,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF667EEA)
                  : Colors.black.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF667EEA)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow({
    required BuildContext context,
    required LeaderboardEntry entry,
    required bool isMe,
    required int rank,
    required int score,
    required String photo,
    required bool isMiner,
  }) {
    final name = _name(entry);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(
                colors: [
                  const Color(0xFF667EEA).withValues(alpha: 0.15),
                  const Color(0xFF764BA2).withValues(alpha: 0.1),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isMe ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(
                color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: ListTile(
        onTap: entry.userId != null ? () => _navigateToUserProfile(entry.userId!) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRankBadge(rank, isMe),
            const SizedBox(width: 12),
            _buildAvatar(photo, name, entry.userId),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isMe ? const Color(0xFF667EEA) : Colors.black87,
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667EEA),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildStatsRow(entry, score, isMiner),
        ),
      ),
    );
  }

  Widget _buildAvatar(String photo, String name, int? userId) {
    final initial = name.isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : '?';
    
    // Construct full image URL if needed
    String imageUrl = photo;
    if (photo.isNotEmpty && !photo.startsWith('http')) {
      // Add base URL prefix if photo is a relative path
      imageUrl = 'https://app.iyoloo.com/api/$photo';
    }

    return GestureDetector(
      onTap: userId != null ? () => _navigateToUserProfile(userId) : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: photo.isEmpty
              ? const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: photo.isNotEmpty ? Colors.grey[200] : null,
        ),
        child: photo.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to initials on error
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
      ),
    );
  }

  void _navigateToUserProfile(int userId) {
    // Navigate to user profile screen
    Get.toNamed('/user-profile', arguments: {'userId': userId});
  }

  Widget _buildStatsRow(LeaderboardEntry entry, int score, bool isMiner) {
    if (isMiner) {
      return Row(
        children: [
          Icon(
            Icons.local_fire_department,
            size: 14,
            color: Colors.orange.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            '${entry.weightedScore ?? 0} mining pts',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Score: $score',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _buildStatChip(Icons.favorite, '${entry.likes ?? 0}', Colors.red),
        _buildStatChip(Icons.remove_red_eye, '${entry.views ?? 0}', Colors.blue),
        _buildStatChip(Icons.comment, '${entry.comments ?? 0}', Colors.green),
        Text(
          'Score: $score',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF667EEA).withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Helper for disabling professional confirmation
Future<bool?> _confirmDisable(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Turn off Professional?'),
        content: const Text(
          'You\'ll lose access to earnings and stats.\n\n'
          'You cannot re-enable for 7 days after turning off.\n'
          'All progress and targets will reset.\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Turn Off'),
          ),
        ],
      );
    },
  );
}

class _LeaderboardRowSkeleton extends StatelessWidget {
  const _LeaderboardRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        title: Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            height: 10,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
