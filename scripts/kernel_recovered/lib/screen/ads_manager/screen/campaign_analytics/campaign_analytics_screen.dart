import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/utils/format.dart';
import 'package:shortzz/common/widget/ads_metric_cards.dart';
import 'package:shortzz/screen/ads_manager/data/ads_dto.dart';
import 'package:shortzz/screen/ads_manager/data/ads_repository.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_empty_state.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_line_chart_placeholder.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_section_header.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_skeleton_card.dart';
import 'package:shortzz/screen/ads_manager/widget/ads_time_range_switch.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:shortzz/screen/ads_manager/mock/ads_manager_mock_data.dart';

class CampaignAnalyticsScreen extends StatefulWidget {
  const CampaignAnalyticsScreen({
    super.key,
    required this.campaign,
  });

  final AdsManagerCampaignItem campaign;

  @override
  State<CampaignAnalyticsScreen> createState() => _CampaignAnalyticsScreenState();
}

class _CampaignAnalyticsScreenState extends State<CampaignAnalyticsScreen> {
  final AdsManagerRepository _repo = AdsManagerRepository();

  AdsTimeRange _range = AdsTimeRange.days7;
  AdsManagerCampaignAnalyticsDto? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _repo.fetchCampaignAnalytics(campaignId: widget.campaign.id);
      if (!mounted) return;
      setState(() {
        _analytics = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analytics = null;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _analytics;
    final impressions = a?.impressions;
    final clicks = a?.clicks;
    final spend = a?.spend;
    final ctr = a?.ctr;
    final cpc = a?.cpc;
    final cpa = a?.cpa;
    final dailySeries = a?.dailySeries ?? <Map<String, dynamic>>[];
    
    // Currency handling removed for now; spend is shown as numeric

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        foregroundColor: textDarkGrey(context),
        elevation: 0.6,
        title: Text(
          widget.campaign.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) ...const [
              AdsSkeletonCard(height: 56),
              SizedBox(height: 10),
              AdsSkeletonCard(height: 180),
              SizedBox(height: 14),
              AdsSkeletonCard(height: 120),
              SizedBox(height: 14),
              AdsSkeletonCard(height: 180),
            ] else if ((_error ?? '').trim().isNotEmpty) ...[
              AdsSectionHeader(
                title: 'Analytics',
                action: TextButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
              const SizedBox(height: 10),
              AdsEmptyState(
                title: 'Could not load analytics',
                subtitle: _error,
                icon: Icons.wifi_off,
                action: ElevatedButton(
                  onPressed: _fetch,
                  child: const Text('Try again'),
                ),
              ),
            ] else ...[
              AdsSectionHeader(
                title: 'Analytics',
                action: AdsTimeRangeSwitch(
                  value: _range,
                  onChanged: (v) {
                    setState(() {
                      _range = v;
                    });
                    BaseController.share.showSnackBar(
                      v == AdsTimeRange.days7
                          ? 'Showing last 7 days'
                          : 'Showing last 30 days',
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              if (dailySeries.isEmpty)
                const AdsLineChartPlaceholder(height: 180)
              else
                _DailySeriesLineChart(
                  series: dailySeries,
                  height: 180,
                ),
              const SizedBox(height: 14),
              AdsMetricCardsGrid(
                items: [
                  AdsMetric(
                    label: 'Impressions',
                    value: formatCompact(impressions ?? 0),
                    icon: Icons.visibility_outlined,
                    color: Colors.indigo,
                  ),
                  AdsMetric(
                    label: 'Clicks',
                    value: formatCompact(clicks ?? 0),
                    icon: Icons.ads_click,
                    color: Colors.blue,
                  ),
                  AdsMetric(
                    label: 'Spend',
                    value: (spend ?? 0).toStringAsFixed(2),
                    icon: Icons.payments_outlined,
                    color: Colors.deepOrange,
                    subtitle: 'Total spend',
                  ),
                  AdsMetric(
                    label: 'CTR',
                    value: ctr == null ? '-' : '${ctr.toStringAsFixed(2)}%',
                    icon: Icons.trending_up,
                    color: Colors.green,
                    subtitle: 'Click Rate',
                  ),
                  AdsMetric(
                    label: 'CPC',
                    value: cpc == null ? '-' : cpc.toStringAsFixed(2),
                    icon: Icons.touch_app_outlined,
                    color: Colors.blueGrey,
                    subtitle: 'Cost/Click',
                  ),
                  AdsMetric(
                    label: 'CPA',
                    value: cpa == null ? '-' : cpa.toStringAsFixed(2),
                    icon: Icons.verified_outlined,
                    color: Colors.purple,
                    subtitle: 'Cost/Action',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const AdsSectionHeader(title: 'Daily performance'),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final series = a?.dailySeries ?? <Map<String, dynamic>>[];
                  if (series.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: textLightGrey(context).withValues(alpha: 0.16),
                        ),
                      ),
                      child: const AdsEmptyState(
                        title: 'No daily series',
                        subtitle:
                            'Day-wise spend/impressions/clicks will appear here.',
                        icon: Icons.show_chart,
                      ),
                    );
                  }

                  String readStr(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      final s = v.toString().trim();
                      if (s.isNotEmpty) return s;
                    }
                    return '-';
                  }

                  int readInt(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      if (v is num) return v.toInt();
                      final n = int.tryParse(v.toString());
                      if (n != null) return n;
                    }
                    return 0;
                  }

                  num readNum(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      if (v is num) return v;
                      final n = num.tryParse(v.toString());
                      if (n != null) return n;
                    }
                    return 0;
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: textLightGrey(context).withValues(alpha: 0.16),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Spend')),
                          DataColumn(label: Text('Impr')),
                          DataColumn(label: Text('Clicks')),
                        ],
                        rows: series.map((d) {
                          final date = readStr(d, ['date', 'day', 'label']);
                          final spend =
                              readNum(d, ['spend', 'amount', 'spent', 'cost']);
                          final impr = readInt(d, ['impressions', 'impr', 'views']);
                          final clk = readInt(d, ['clicks', 'clk', 'taps']);
                          return DataRow(
                            cells: [
                              DataCell(Text(date)),
                              DataCell(Text(spend.toStringAsFixed(2))),
                              DataCell(Text(formatCompact(impr))),
                              DataCell(Text(formatCompact(clk))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const AdsSectionHeader(title: 'Placement breakdown'),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final placements = a?.placementStats ?? <Map<String, dynamic>>[];
                  if (placements.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: textLightGrey(context).withValues(alpha: 0.16),
                        ),
                      ),
                      child: const AdsEmptyState(
                        title: 'No placement stats',
                        subtitle: 'Placement-wise breakdown will appear here.',
                        icon: Icons.view_carousel_outlined,
                      ),
                    );
                  }

                  String readStr(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      final s = v.toString().trim();
                      if (s.isNotEmpty) return s;
                    }
                    return '-';
                  }

                  int readInt(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      if (v is num) return v.toInt();
                      final n = int.tryParse(v.toString());
                      if (n != null) return n;
                    }
                    return 0;
                  }

                  num readNum(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      if (v is num) return v;
                      final n = num.tryParse(v.toString());
                      if (n != null) return n;
                    }
                    return 0;
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: textLightGrey(context).withValues(alpha: 0.16),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Placement')),
                          DataColumn(label: Text('Spend')),
                          DataColumn(label: Text('Impr')),
                          DataColumn(label: Text('Clicks')),
                        ],
                        rows: placements.map((p) {
                          final placement =
                              readStr(p, ['placement', 'name', 'type', 'label']);
                          final spend =
                              readNum(p, ['spend', 'amount', 'spent', 'cost']);
                          final impr = readInt(p, ['impressions', 'impr', 'views']);
                          final clk = readInt(p, ['clicks', 'clk', 'taps']);
                          return DataRow(
                            cells: [
                              DataCell(Text(placement)),
                              DataCell(Text(spend.toStringAsFixed(2))),
                              DataCell(Text(formatCompact(impr))),
                              DataCell(Text(formatCompact(clk))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const AdsSectionHeader(title: 'Country stats'),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final countries = a?.countryStats ?? <Map<String, dynamic>>[];
                  if (countries.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: textLightGrey(context).withValues(alpha: 0.16),
                        ),
                      ),
                      child: const AdsEmptyState(
                        title: 'No country stats',
                        subtitle: 'Country-wise breakdown will appear here.',
                        icon: Icons.public,
                      ),
                    );
                  }

                  String readStr(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      final s = v.toString().trim();
                      if (s.isNotEmpty) return s;
                    }
                    return '-';
                  }

                  int readInt(Map<String, dynamic> m, List<String> keys) {
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      if (v is num) return v.toInt();
                      final n = int.tryParse(v.toString());
                      if (n != null) return n;
                    }
                    return 0;
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: textLightGrey(context).withValues(alpha: 0.16),
                      ),
                    ),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Country')),
                        DataColumn(label: Text('Impr')),
                        DataColumn(label: Text('Clicks')),
                      ],
                      rows: countries.map((c) {
                        final country = readStr(c, ['country', 'name', 'code']);
                        final impr = readInt(c, ['impressions', 'impr', 'views']);
                        final clk = readInt(c, ['clicks', 'clk', 'taps']);
                        return DataRow(
                          cells: [
                            DataCell(Text(country)),
                            DataCell(Text(formatCompact(impr))),
                            DataCell(Text(formatCompact(clk))),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                _range == AdsTimeRange.days7
                    ? 'Showing last 7 days.'
                    : 'Showing last 30 days.',
                style: TextStyle(
                  fontSize: 12,
                  color: textLightGrey(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailySeriesLineChart extends StatelessWidget {
  const _DailySeriesLineChart({
    required this.series,
    required this.height,
  });

  final List<Map<String, dynamic>> series;
  final double height;

  num _readNum(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num) return v;
      final n = num.tryParse(v.toString());
      if (n != null) return n;
    }
    return 0;
  }

  String _readStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  DateTime? _tryParseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(series);
    items.sort((a, b) {
      final da = _tryParseDate(_readStr(a, ['date', 'day', 'label']));
      final db = _tryParseDate(_readStr(b, ['date', 'day', 'label']));
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });

    final spendSpots = <FlSpot>[];
    final imprSpots = <FlSpot>[];
    final clickSpots = <FlSpot>[];

    for (var i = 0; i < items.length; i++) {
      final d = items[i];
      final x = i.toDouble();
      final spend = _readNum(d, ['spend', 'amount', 'spent', 'cost']).toDouble();
      final impr =
          _readNum(d, ['impressions', 'impr', 'views']).toDouble();
      final clicks = _readNum(d, ['clicks', 'clk', 'taps']).toDouble();

      spendSpots.add(FlSpot(x, spend));
      imprSpots.add(FlSpot(x, impr));
      clickSpots.add(FlSpot(x, clicks));
    }

    const spendColor = Colors.deepOrange;
    const imprColor = Colors.indigo;
    const clickColor = Colors.blue;

    Widget legendDot(Color c) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              legendDot(spendColor),
              const SizedBox(width: 6),
              Text(
                'Spend',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              legendDot(imprColor),
              const SizedBox(width: 6),
              Text(
                'Impr',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              legendDot(clickColor),
              const SizedBox(width: 6),
              Text(
                'Clicks',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: null,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: items.length <= 4 ? 1 : 2,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= items.length) {
                          return const SizedBox.shrink();
                        }
                        final raw = _readStr(items[idx], ['date', 'day', 'label']);
                        final d = _tryParseDate(raw);
                        final label = d == null
                            ? (raw.length > 6 ? raw.substring(0, 6) : raw)
                            : '${d.month}/${d.day}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spendSpots,
                    isCurved: true,
                    color: spendColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: spendColor.withValues(alpha: 0.10),
                    ),
                  ),
                  LineChartBarData(
                    spots: imprSpots,
                    isCurved: true,
                    color: imprColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: false,
                    ),
                  ),
                  LineChartBarData(
                    spots: clickSpots,
                    isCurved: true,
                    color: clickColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: false,
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ],
      ),
    );
  }
}
