import 'package:flutter/material.dart';
import 'package:shortzz/common/manager/economy_state.dart';
import 'package:shortzz/common/service/api/ad_spend_service.dart';
import 'package:shortzz/common/service/api/ads_analytics_service.dart';
import 'package:shortzz/common/service/api/boost_service.dart';
import 'package:shortzz/common/service/api/platform_ads_service.dart';
import 'package:shortzz/common/service/api/promotion_service.dart';
import 'package:shortzz/common/service/api/user_ads_service.dart';
import 'package:shortzz/common/utils/format.dart';
import 'package:shortzz/common/widget/ads_metric_cards.dart';
import 'package:shortzz/screen/ads_hub/ad_details_screen.dart';
import 'package:shortzz/screen/ads_hub/boost_request_details_screen.dart';
import 'package:shortzz/model/ads/ad_spend_model.dart';
import 'package:shortzz/model/ads/ads_analytics_model.dart';
import 'package:shortzz/model/boost/boost_model.dart';
import 'package:shortzz/model/platform_ads/platform_ads_model.dart';
import 'package:shortzz/model/promotions/app_open_promotion_model.dart';
import 'package:shortzz/utilities/theme_res.dart';

class AdsHubScreen extends StatefulWidget {
  const AdsHubScreen({super.key});

  @override
  State<AdsHubScreen> createState() => _AdsHubScreenState();
}

class _AdsHubScreenState extends State<AdsHubScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        backgroundColor: scaffoldBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: scaffoldBackgroundColor(context),
          foregroundColor: textDarkGrey(context),
          iconTheme: IconThemeData(color: textDarkGrey(context)),
          titleTextStyle: TextStyle(
            color: textDarkGrey(context),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          title: const Text('Ads Hub'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: textDarkGrey(context),
            unselectedLabelColor: textLightGrey(context).withValues(alpha: 0.9),
            indicatorColor: themeAccentSolid(context),
            dividerColor: textLightGrey(context).withValues(alpha: 0.15),
            tabs: const [
              Tab(text: 'My Ads'),
              Tab(text: 'Boost Post'),
              Tab(text: 'Pending Approval'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
              Tab(text: 'Analytics'),
              Tab(text: 'Ad Spend'),
              Tab(text: 'Admin Promotions'),
              Tab(text: 'Platform Ads'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyAdsTab(),
            _BoostPostTab(),
            _PendingApprovalTab(),
            _ApprovedTab(),
            _RejectedTab(),
            _AnalyticsTab(),
            _AdSpendTab(),
            _AdminPromotionsTab(),
            _PlatformAdsTab(),
          ],
        ),
      ),
    );
  }
}

class _MyAdsTab extends StatelessWidget {
  const _MyAdsTab();

  @override
  Widget build(BuildContext context) {
    return const _MyUserAdsRequests(
      initialFilter: 'all',
      showChips: true,
    );
  }
}

class _BoostPostTab extends StatelessWidget {
  const _BoostPostTab();

  @override
  Widget build(BuildContext context) {
    return const _BoostRequestsList();
  }
}

class _BoostRequestsList extends StatefulWidget {
  const _BoostRequestsList();

  @override
  State<_BoostRequestsList> createState() => _BoostRequestsListState();
}

class _BoostRequestsListState extends State<_BoostRequestsList>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<BoostRequest> _items = <BoostRequest>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _items = await BoostService.instance.fetchMyBoostRequests();
    } catch (_) {
      _items = <BoostRequest>[];
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Boost Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textDarkGrey(context),
            ),
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            Text(
              'No boost requests',
              style: TextStyle(color: textLightGrey(context), fontSize: 13),
            )
          else
            ..._items.map((b) {
              final status = (b.status ?? '').toString();
              final postId = (b.postId ?? '').toString();
              final budget = (b.budget ?? '').toString();
              final spend = (b.spend ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: textLightGrey(context).withValues(alpha: 0.15),
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BoostRequestDetailsScreen(boost: b),
                      ),
                    );
                  },
                  title: Text(
                    'Post #$postId',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textDarkGrey(context),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Status: $status\nBudget: $budget   Spend: $spend',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: textLightGrey(context),
                      ),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: textLightGrey(context),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AdminPromotionsTab extends StatefulWidget {
  const _AdminPromotionsTab();

  @override
  State<_AdminPromotionsTab> createState() => _AdminPromotionsTabState();
}

class _AdminPromotionsTabState extends State<_AdminPromotionsTab>
    with AutomaticKeepAliveClientMixin {
  AppOpenPromotion? _promotion;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await PromotionService.instance.fetchActiveAppOpenPromotion();
      _promotion = res.data;
    } catch (_) {
      _promotion = null;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'App Open Promotions (admin)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textDarkGrey(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_promotion == null)
            Text(
              'No active app-open promotion',
              style: TextStyle(color: textLightGrey(context), fontSize: 13),
            )
          else
            _PromotionCard(p: _promotion!),
          const SizedBox(height: 12),
          Text(
            'Rule: No ad goes live without admin approval.\nSponsored label is mandatory.',
            style: TextStyle(color: textLightGrey(context), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            'To advertise your content or business, please contact the admin team:\nhello@vidmite.com\nsupport.vidmite.com',
            style: TextStyle(
              color: textLightGrey(context),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  final AppOpenPromotion p;

  const _PromotionCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.title ?? 'Promotion',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textDarkGrey(context),
              ),
            ),
            if ((p.subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                p.subtitle ?? '',
                style: TextStyle(color: textLightGrey(context), fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Frequency: ${p.frequency ?? 'always'}',
              style: TextStyle(color: textLightGrey(context), fontSize: 12),
            ),
            if ((p.action ?? '').isNotEmpty)
              Text(
                'Action: ${p.action}',
                style: TextStyle(color: textLightGrey(context), fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlatformAdsTab extends StatefulWidget {
  const _PlatformAdsTab();

  @override
  State<_PlatformAdsTab> createState() => _PlatformAdsTabState();
}

class _PlatformAdsTabState extends State<_PlatformAdsTab>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<PlatformAd> _feed = <PlatformAd>[];
  List<PlatformAd> _reels = <PlatformAd>[];
  List<PlatformAd> _story = <PlatformAd>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await Future.wait([
        PlatformAdsService.instance.fetchPlatformAds(placement: 'feed'),
        PlatformAdsService.instance.fetchPlatformAds(placement: 'reels'),
        PlatformAdsService.instance.fetchPlatformAds(placement: 'story'),
      ]);
      _feed = res[0];
      _reels = res[1];
      _story = res[2];
    } catch (_) {
      _feed = <PlatformAd>[];
      _reels = <PlatformAd>[];
      _story = <PlatformAd>[];
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _adsSection(context, title: 'Feed Ads', items: _feed),
          const SizedBox(height: 12),
          _adsSection(context, title: 'Reels Ads', items: _reels),
          const SizedBox(height: 12),
          _adsSection(context, title: 'Story Ads', items: _story),
        ],
      ),
    );
  }

  Widget _adsSection(BuildContext context,
      {required String title, required List<PlatformAd> items}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textLightGrey(context).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textDarkGrey(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.07),
                  ),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textLightGrey(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'No ads',
              style: TextStyle(color: textLightGrey(context), fontSize: 13),
            )
          else
            ...items.take(10).map(
                  (a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title ?? 'Ad',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textDarkGrey(context),
                          ),
                        ),
                        if ((a.cta ?? '').isNotEmpty ||
                            (a.destinationUrl ?? '').isNotEmpty)
                          Text(
                            '${a.cta ?? ''}  ${a.destinationUrl ?? ''}',
                            style: TextStyle(
                              color: textLightGrey(context),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _MyUserAdsRequests extends StatefulWidget {
  const _MyUserAdsRequests({
    this.initialFilter = 'all',
    this.showChips = true,
  });

  final String initialFilter;
  final bool showChips;

  @override
  State<_MyUserAdsRequests> createState() => _MyUserAdsRequestsState();
}

class _MyUserAdsRequestsState extends State<_MyUserAdsRequests>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _all = <Map<String, dynamic>>[];
  late String _filter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final raw = await UserAdsService.instance.listMyRequests();
      _all = _extractItems(raw);
    } catch (_) {
      _all = <Map<String, dynamic>>[];
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> raw) {
    dynamic data = raw['data'] ?? raw['items'] ?? raw['list'] ?? raw['requests'];
    // Some backends return the list at top-level under other keys.
    data ??= raw['ads'] ?? raw['results'] ?? raw['rows'];
    if (data is Map) {
      data = data['items'] ??
          data['data'] ??
          data['list'] ??
          data['requests'] ??
          data['ads'] ??
          data['results'] ??
          data['rows'];
    }
    if (data is! List) return <Map<String, dynamic>>[];
    return data
        .whereType<dynamic>()
        .map((e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _matches(Map<String, dynamic> b) {
    final rawStatus = b['status'] ?? b['approval_status'] ?? b['state'] ?? b['request_status'] ?? '';
    final s = rawStatus.toString().toLowerCase().trim();

    final isApprovedRaw = b['is_approved'] ?? b['approved'] ?? b['isApproved'];
    final isRejectedRaw = b['is_rejected'] ?? b['rejected'] ?? b['isRejected'];
    final isApproved = isApprovedRaw == true || isApprovedRaw == 1 || isApprovedRaw?.toString() == '1';
    final isRejected = isRejectedRaw == true || isRejectedRaw == 1 || isRejectedRaw?.toString() == '1';

    if (_filter == 'pending') {
      if (isApproved || isRejected) return false;
      return s.isEmpty || s == 'pending' || s == '0' || s == 'review' || s == 'in_review' || s == 'submitted';
    }
    if (_filter == 'approved') {
      return isApproved || s == 'approved' || s == '1' || s == 'active' || s == 'live';
    }
    if (_filter == 'rejected') {
      return isRejected || s == 'rejected' || s == '2' || s == 'declined';
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _all.where(_matches).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'My Ads',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textDarkGrey(context),
            ),
          ),
          const SizedBox(height: 10),
          if (widget.showChips) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'All', 'all'),
                _chip(context, 'Pending', 'pending'),
                _chip(context, 'Approved', 'approved'),
                _chip(context, 'Rejected', 'rejected'),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            Text(
              'No ads',
              style: TextStyle(color: textLightGrey(context), fontSize: 13),
            )
          else
            ...items.map((b) {
              final status = (b['status'] ?? b['approval_status'] ?? '').toString();
              final title = (b['title'] ?? b['name'] ?? 'Ad').toString();
              final id = (b['id'] ?? b['ad_id'] ?? '').toString();
              final placement = (b['placement'] ?? '').toString();
              final budget = (b['budget_coins'] ?? b['budget'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: textLightGrey(context).withValues(alpha: 0.15),
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdDetailsScreen(ad: b),
                      ),
                    );
                  },
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textDarkGrey(context),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Placement: $placement\nBudget: $budget\nStatus: $status\nID: $id',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: textLightGrey(context),
                      ),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: textLightGrey(context),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String key) {
    final selected = _filter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _filter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? themeAccentSolid(context).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? themeAccentSolid(context).withValues(alpha: 0.55)
                : textLightGrey(context).withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? themeAccentSolid(context) : textDarkGrey(context),
          ),
        ),
      ),
    );
  }
}

class _PendingApprovalTab extends StatelessWidget {
  const _PendingApprovalTab();

  @override
  Widget build(BuildContext context) {
    return const _MyUserAdsRequests(
      initialFilter: 'pending',
      showChips: false,
    );
  }
}

class _ApprovedTab extends StatelessWidget {
  const _ApprovedTab();

  @override
  Widget build(BuildContext context) {
    return const _MyUserAdsRequests(
      initialFilter: 'approved',
      showChips: false,
    );
  }
}

class _RejectedTab extends StatelessWidget {
  const _RejectedTab();

  @override
  Widget build(BuildContext context) {
    return const _MyUserAdsRequests(
      initialFilter: 'rejected',
      showChips: false,
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  AdsAnalytics? _analytics;
  num _fallbackSpend = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    _analytics = null;
    _fallbackSpend = 0;

    try {
      final res = await AdsAnalyticsService.instance.fetchMyAdsAnalytics();
      _analytics = res.data;
    } catch (_) {
      _analytics = null;
    }

    // Fallback spend from boost requests (already present in model)
    try {
      final items = await BoostService.instance.fetchMyBoostRequests();
      _fallbackSpend =
          items.fold<num>(0, (sum, b) => sum + (b.spend ?? 0));
    } catch (_) {
      _fallbackSpend = 0;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final a = _analytics;
    final impressions = a?.impressions ?? 0;
    final clicks = a?.clicks ?? 0;
    final reach = a?.reach ?? 0;
    final spend = a?.spend ?? _fallbackSpend;
    final currency = (a?.currency ?? '').trim();

    final ctr = impressions > 0 ? (clicks / impressions) * 100 : 0;
    final cpm = impressions > 0 ? (spend / impressions) * 1000 : 0;
    final cpc = clicks > 0 ? (spend / clicks) : 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Analytics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textDarkGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          AdsMetricCardsGrid(
            items: [
              AdsMetric(
                label: 'Impressions',
                value: formatCompact(impressions),
                icon: Icons.visibility_outlined,
                color: Colors.indigo,
              ),
              AdsMetric(
                label: 'Clicks',
                value: formatCompact(clicks),
                icon: Icons.ads_click,
                color: Colors.blue,
              ),
              AdsMetric(
                label: 'CTR',
                value: '${ctr.toStringAsFixed(2)}%',
                icon: Icons.trending_up,
                color: Colors.purple,
                subtitle: 'Clicks / Impr',
              ),
              AdsMetric(
                label: 'Reach',
                value: formatCompact(reach),
                icon: Icons.people_alt_outlined,
                color: Colors.teal,
              ),
              AdsMetric(
                label: 'Spend',
                value: currency.isEmpty
                    ? spend.toStringAsFixed(2)
                    : '$currency ${spend.toStringAsFixed(2)}',
                icon: Icons.payments_outlined,
                color: Colors.deepOrange,
              ),
              AdsMetric(
                label: 'CPM',
                value: cpm.toStringAsFixed(2),
                icon: Icons.show_chart,
                color: Colors.green,
                subtitle: 'Per 1k impr',
              ),
              AdsMetric(
                label: 'CPC',
                value: cpc.toStringAsFixed(2),
                icon: Icons.touch_app_outlined,
                color: Colors.brown,
                subtitle: 'Per click',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Note: No ad goes live without admin approval.',
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

class _AdSpendTab extends StatefulWidget {
  const _AdSpendTab();

  @override
  State<_AdSpendTab> createState() => _AdSpendTabState();
}

class _AdSpendTabState extends State<_AdSpendTab>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  AdSpendSummary? _summary;
  num _fallbackBudget = 0;
  num _fallbackSpend = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    _summary = null;
    _fallbackBudget = 0;
    _fallbackSpend = 0;

    try {
      final res = await AdSpendService.instance.fetchMyAdSpendSummary();
      _summary = res.data;
    } catch (_) {
      _summary = null;
    }

    // Fallback totals from boost requests
    try {
      final items = await BoostService.instance.fetchMyBoostRequests();
      _fallbackBudget =
          items.fold<num>(0, (sum, b) => sum + (b.budget ?? 0));
      _fallbackSpend = items.fold<num>(0, (sum, b) => sum + (b.spend ?? 0));
    } catch (_) {
      _fallbackBudget = 0;
      _fallbackSpend = 0;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = _summary;
    final currency = (s?.currency ?? '').trim();
    final totalBudget = s?.totalBudget ?? _fallbackBudget;
    final totalSpend = s?.totalSpend ?? _fallbackSpend;
    final available = s?.availableBalance;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ad Spend / Wallet (read-only)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textDarkGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          AdsMetricCardsGrid(
            items: [
              AdsMetric(
                label: 'Total Budget',
                value: currency.isEmpty
                    ? totalBudget.toStringAsFixed(2)
                    : '$currency ${totalBudget.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.indigo,
              ),
              AdsMetric(
                label: 'Total Spend',
                value: currency.isEmpty
                    ? totalSpend.toStringAsFixed(2)
                    : '$currency ${totalSpend.toStringAsFixed(2)}',
                icon: Icons.payments_outlined,
                color: Colors.deepOrange,
              ),
              AdsMetric(
                label: 'Available',
                value: available == null
                    ? '—'
                    : (currency.isEmpty
                        ? available.toStringAsFixed(2)
                        : '$currency ${available.toStringAsFixed(2)}'),
                icon: Icons.savings_outlined,
                color: Colors.green,
              ),
              AdsMetric(
                label: 'Coins',
                value: formatCompact(EconomyState.instance.coins.value),
                icon: Icons.monetization_on_outlined,
                color: Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Earnings (read-only): ${EconomyState.instance.earnings.value}',
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

