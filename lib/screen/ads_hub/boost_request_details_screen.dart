import 'package:flutter/material.dart';
import 'package:shortzz/model/boost/boost_model.dart';
import 'package:shortzz/utilities/theme_res.dart';

class BoostRequestDetailsScreen extends StatelessWidget {
  const BoostRequestDetailsScreen({
    super.key,
    required this.boost,
  });

  final BoostRequest boost;

  String _s(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final status = _s(boost.status);
    final postId = _s(boost.postId);
    final budget = _s(boost.budget);
    final spend = _s(boost.spend);
    final startsAt = _s(boost.startsAt);
    final endsAt = _s(boost.endsAt);

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        title: const Text('Boost Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
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
                  'Post ID: $postId',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textDarkGrey(context),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    if (status.isNotEmpty) 'Status: $status',
                    if (budget.isNotEmpty) 'Budget: $budget',
                    if (spend.isNotEmpty) 'Spend: $spend',
                    if (startsAt.isNotEmpty) 'Starts: $startsAt',
                    if (endsAt.isNotEmpty) 'Ends: $endsAt',
                  ].join('\n'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: textLightGrey(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Note: Boost analytics (impressions/clicks) feed tracking se aayega. Abhi backend me spend/budget/status available hai.',
            style: TextStyle(color: textLightGrey(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
