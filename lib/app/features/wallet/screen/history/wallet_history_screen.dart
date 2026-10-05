import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletHistoryScreen extends BaseView<WalletController> {
  const WalletHistoryScreen({super.key});
  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Wellness Points History',
    subtitle: 'Confirmed Wellness Points payments.',
    children: <Widget>[_HistoryContent(controller: controller)],
  );
}

class _HistoryContent extends StatefulWidget {
  const _HistoryContent({required this.controller});
  final WalletController controller;
  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.loadRewardsHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final WalletController controller = widget.controller;
    final RewardsHistoryPage? page = controller.historyPage.value;
    final bool loading = controller.isLoadingHistory.value;
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: loading ? null : () => controller.loadRewardsHistory(),
              tooltip: 'Refresh Wellness Points history',
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (controller.historyError.value.isNotEmpty) ...<Widget>[
            Text(controller.historyError.value),
            OutlinedButton(
              onPressed: loading ? null : () => controller.loadRewardsHistory(),
              child: const Text('Retry history'),
            ),
          ],
          if (controller.isHistoryStale.value)
            const Text('Previously loaded history — refresh unavailable.'),
          if (page != null) Text('Last checked: ${page.observedAt.toLocal()}'),
          if (!loading && page != null && controller.historyItems.isEmpty)
            const Text('No Wellness Points payments on the pages checked.'),
          for (final RewardsHistoryItem item
              in controller.historyItems) ...<Widget>[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.direction == RewardsHistoryDirection.sent
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
              ),
              title: Text(
                item.direction == RewardsHistoryDirection.self
                    ? 'Self payment'
                    : (item.direction == RewardsHistoryDirection.received
                          ? 'Received Wellness Points'
                          : 'Sent Wellness Points'),
              ),
              subtitle: Text(
                '${item.counterparty}\n${item.createdAt.toLocal()}',
              ),
              trailing: Text('${item.amount} ${page?.assetCode ?? ""}'),
            ),
          ],
          if (page?.nextCursor != null)
            OutlinedButton(
              onPressed: loading
                  ? null
                  : () => controller.loadRewardsHistory(more: true),
              child: const Text('Load more history'),
            ),
        ],
      ),
    );
  });
}
