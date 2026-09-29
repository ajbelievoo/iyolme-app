import 'package:flutter/material.dart';
import 'package:shortzz/common/service/api/user_ads_service.dart';
import 'package:shortzz/common/utils/format.dart';
import 'package:shortzz/common/widget/ads_metric_cards.dart';
import 'package:shortzz/utilities/theme_res.dart';

class AdDetailsScreen extends StatefulWidget {
  const AdDetailsScreen({
    super.key,
    required this.ad,
  });

  final Map<String, dynamic> ad;

  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;

  int? _adId() {
    final raw = widget.ad['id'] ?? widget.ad['ad_id'] ?? widget.ad['adId'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  num _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  String _asStr(dynamic v) => (v ?? '').toString();

  num _readNum(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (!m.containsKey(k)) continue;
      final v = m[k];
      final n = _asNum(v);
      if (n != 0) return n;
      // Keep searching; some APIs return 0 for missing.
    }
    // second pass: return first numeric if all were 0
    for (final k in keys) {
      if (!m.containsKey(k)) continue;
      return _asNum(m[k]);
    }
    return 0;
  }

  String _readStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = _asStr(v).trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  Map<String, dynamic>? _extractAnalyticsData(Map<String, dynamic> raw) {
    final data = raw['data'] ?? raw['analytics'] ?? raw['result'] ?? raw;
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    _analytics = null;
    final id = _adId();
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final raw = await UserAdsService.instance.getAdAnalytics(adId: id);
      _analytics = _extractAnalyticsData(raw);
    } catch (_) {
      _analytics = null;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;

    final title = _asStr(ad['title'] ?? ad['name'] ?? 'Ad');
    final placement = _asStr(ad['placement']);
    final status = _asStr(ad['status'] ?? ad['approval_status'] ?? ad['state']);
    final budgetCoins = _asStr(ad['budget_coins'] ?? ad['budget']);
    final billing = _asStr(ad['billing']);
    final cta = _asStr(ad['cta'] ?? ad['cta_text']);
    final ctaUrl = _asStr(ad['cta_url'] ?? ad['destination_url'] ?? ad['url']);

    final a = _analytics ?? const <String, dynamic>{};

    final impressions = _readNum(a, ['impressions', 'impression', 'views', 'view_count', 'viewCount']);
    final clicks = _readNum(a, ['clicks', 'click_count', 'clickCount', 'taps', 'tap_count', 'link_clicks']);
    final reach = _readNum(a, ['reach', 'unique_reach', 'uniqueReach']);
    final spend = _readNum(a, [
      'spend',
      'spent',
      'amount_spent',
      'spend_amount',
      'cost',
      'spend_coins',
      'spendCoins',
    ]);
    final currency = _readStr(a, ['currency', 'currency_symbol', 'currencySymbol', 'symbol']);

    final ctr = impressions > 0 ? (clicks / impressions) * 100 : 0;
    final cpm = impressions > 0 ? (spend / impressions) * 1000 : 0;
    final cpc = clicks > 0 ? (spend / clicks) : 0;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        title: const Text('Ad Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(
                    title: title,
                    subtitle: [
                      if (placement.isNotEmpty) 'Placement: $placement',
                      if (status.isNotEmpty) 'Status: $status',
                      if (budgetCoins.isNotEmpty) 'Budget: $budgetCoins',
                      if (billing.isNotEmpty) 'Billing: $billing',
                      if (cta.isNotEmpty) 'CTA: $cta',
                      if (ctaUrl.isNotEmpty) 'URL: $ctaUrl',
                    ].join('\n'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textDarkGrey(context),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 14),
                  if (_analytics == null)
                    Text(
                      'Analytics not available for this ad yet.',
                      style: TextStyle(color: textLightGrey(context), fontSize: 13),
                    ),
                ],
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textLightGrey(context).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDarkGrey(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: textLightGrey(context),
            ),
          ),
        ],
      ),
    );
  }
}

