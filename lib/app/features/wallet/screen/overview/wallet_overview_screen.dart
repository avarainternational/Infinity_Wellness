import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletOverviewScreen extends BaseView<WalletController> {
  const WalletOverviewScreen({super.key});
  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Employee Wallet',
    subtitle: 'Your Wellness Points.',
    trailing: IconButton.filledTonal(
      onPressed: controller.openLocked,
      tooltip: 'Lock protected Wellness Points actions',
      icon: const Icon(Icons.lock_outline),
    ),
    children: <Widget>[
      _RewardsBalanceCard(controller: controller),
      const SizedBox(height: 18),
      Row(
        children: <Widget>[
          Expanded(
            child: WalletActionCard(
              icon: Icons.qr_code_2,
              label: 'Receive',
              onTap: controller.openReceive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: WalletActionCard(
              icon: Icons.send_outlined,
              label: 'Send',
              onTap: controller.openSend,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      WalletCard(
        child: Column(
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: const Text('Wellness Points history'),
              subtitle: const Text('Review confirmed Wellness Points payments'),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.openHistory,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Latest transfer status'),
              subtitle: const Text('Restore or verify a saved transfer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.openTransferStatus,
            ),
            Obx(
              () => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.system_update_alt),
                title: const Text('Update Wellness Points service'),
                subtitle: Text(
                  controller.configurationError.value.isEmpty
                      ? 'Request protected settings from Wellness Admin'
                      : controller.configurationError.value,
                ),
                trailing: controller.isCreatingConfigurationRequest.value
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: controller.isCreatingConfigurationRequest.value
                    ? null
                    : controller.openConfigurationRequest,
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phonelink_erase_outlined),
              title: const Text('Disable access on this device'),
              subtitle: const Text(
                'Keep the wallet; require authentication to return',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.openRemoveWallet,
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Back up or restore Wellness Points'),
              subtitle: const Text(
                'Save a backup or remove credentials from this device',
              ),
              onTap: controller.openRewardsRecovery,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: controller.openAppMaster,
        icon: const Icon(Icons.hub_outlined),
        label: const Text('Open Wellness Admin'),
      ),
      const SizedBox(height: 12),
      const WalletPreviewNotice(),
    ],
  );
}

class _RewardsBalanceCard extends StatefulWidget {
  const _RewardsBalanceCard({required this.controller});
  final WalletController controller;
  @override
  State<_RewardsBalanceCard> createState() => _RewardsBalanceCardState();
}

class _RewardsBalanceCardState extends State<_RewardsBalanceCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.refreshRewardsBalance();
    });
  }

  @override
  Widget build(BuildContext context) => WalletCard(
    child: Obx(() {
      final balance = widget.controller.rewardsBalance.value;
      final bool loading = widget.controller.isRefreshingBalance.value;
      final String error = widget.controller.balanceError.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: Text('Available balance')),
              IconButton(
                onPressed: loading
                    ? null
                    : widget.controller.refreshRewardsBalance,
                tooltip: 'Refresh Wellness Points balance',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          if (balance != null) ...<Widget>[
            Text(
              '${balance.available} ${balance.assetCode}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Total Wellness Points: ${balance.total} ${balance.assetCode}',
            ),
            Text('Last checked: ${balance.observedAt.toLocal()}'),
            if (widget.controller.isBalanceStale.value)
              const Text('Previously checked balance — refresh unavailable.'),
          ] else if (!loading)
            const Text('Balance unavailable'),
          if (error.isNotEmpty) Text(error),
        ],
      );
    }),
  );
}
