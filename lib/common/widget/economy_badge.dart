import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/economy_state.dart';
import 'package:shortzz/screen/professional_dashboard_screen/professional_dashboard_screen.dart';
import 'package:shortzz/common/utils/format.dart';

class EconomyBadge extends StatelessWidget {
  const EconomyBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final coins = EconomyState.instance.coins;
    final points = EconomyState.instance.points;
    final earnings = EconomyState.instance.earnings;

    return GestureDetector(
      onTap: () {
        // Controller inside will redirect to Enable screen if not enabled
        Get.to(() => const ProfessionalDashboardScreen());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Obx(() {
          final style = TextStyle(
            color: Colors.white,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          );
          final iconSize = compact ? 14.0 : 16.0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monetization_on_outlined, size: iconSize, color: Colors.amberAccent),
              const SizedBox(width: 4),
              Text('${coins.value}', style: style),
              const SizedBox(width: 10),
              Icon(Icons.bolt_outlined, size: iconSize, color: Colors.lightBlueAccent),
              const SizedBox(width: 4),
              Text('${points.value}', style: style),
              const SizedBox(width: 10),
              Icon(Icons.account_balance_wallet_outlined, size: iconSize, color: Colors.greenAccent),
              const SizedBox(width: 4),
              Text(formatCurrency(earnings.value), style: style),
            ],
          );
        }),
      ),
    );
  }
}
