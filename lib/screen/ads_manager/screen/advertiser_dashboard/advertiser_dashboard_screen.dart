import 'package:flutter/material.dart';
import 'package:shortzz/screen/ads_manager/ads_manager_screen.dart';
import 'package:shortzz/screen/ads_manager/tab/ads_dashboard_tab.dart';
import 'package:shortzz/utilities/theme_res.dart';

class AdvertiserDashboardScreen extends StatelessWidget {
  const AdvertiserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        foregroundColor: textDarkGrey(context),
        elevation: 0.6,
        title: const Text(
          'Advertiser Dashboard',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdsManagerScreen()),
              );
            },
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Manager'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const AdsDashboardTab(),
    );
  }
}
