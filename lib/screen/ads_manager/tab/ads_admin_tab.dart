import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/ads_manager/screen/create_campaign/create_campaign_screen.dart';
import 'package:shortzz/screen/withdrawals_screen/withdrawals_screen.dart';
import 'package:shortzz/utilities/theme_res.dart';

class AdsAdminTab extends StatelessWidget {
  const AdsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = SessionManager.instance.getUser();

    final canWithdrawApprove =
        user?.isAdmin == true || user?.hasPermission('withdrawals_approve') == true;

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      bool primary = false,
    }) {
      return Material(
        color: primary
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: textLightGrey(context).withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: textDarkGrey(context),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: textLightGrey(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textLightGrey(context)),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Admin dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: textDarkGrey(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Role: ${(user?.role ?? '').trim().isEmpty ? 'user' : user?.role}',
          style: TextStyle(fontSize: 12, color: textLightGrey(context)),
        ),
        const SizedBox(height: 14),
        tile(
          icon: Icons.campaign_outlined,
          title: 'Create campaign',
          subtitle: 'Start a new ad campaign',
          primary: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateCampaignScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        tile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Withdrawals',
          subtitle: canWithdrawApprove
              ? 'Review withdrawal requests'
              : 'You do not have permission',
          onTap: () {
            if (!canWithdrawApprove) {
              BaseController.share
                  .showSnackBar('Forbidden: withdrawals_approve required');
              return;
            }
            Get.to(() => const WithdrawalsScreen(), preventDuplicates: false);
          },
        ),
      ],
    );
  }
}
