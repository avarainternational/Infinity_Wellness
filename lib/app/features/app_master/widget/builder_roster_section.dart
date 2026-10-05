import 'package:employee_wellness/app/constant/resources/wellness_copy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/features/app_master/controller/app_master_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class BuilderRosterSection extends StatelessWidget {
  const BuilderRosterSection({required this.controller, super.key});
  final AppMasterController controller;
  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Wellness Points accounts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: controller.isLoadingRoster.value
                  ? null
                  : controller.loadRoster,
              tooltip: 'Refresh points accounts',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Accounts holding the configured points asset. Employee identity is not verified by this list.',
        ),
        const SizedBox(height: 12),
        if (controller.isLoadingRoster.value) const LinearProgressIndicator(),
        if (controller.rosterError.value.isNotEmpty)
          WalletCard(child: Text(controller.rosterError.value)),
        if (!controller.isLoadingRoster.value &&
            controller.rosterError.value.isEmpty &&
            controller.rosterEntries.isEmpty)
          const WalletCard(
            child: Text('No accounts hold this Wellness Points asset yet.'),
          ),
        for (final entry in controller.rosterEntries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WalletCard(
              child: ListTile(
                title: Text(
                  entry.publicAccount == null
                      ? employeeFacingText(entry.displayName)
                      : 'Points account',
                ),
                subtitle: Text(
                  '${entry.publicAccount ?? 'Account not linked'}\nUpdated ${entry.updatedAt.toLocal()}',
                ),
                isThreeLine: true,
                trailing: Text(switch (entry.state) {
                  BuilderAccessState.pending => 'Awaiting approval',
                  BuilderAccessState.active =>
                    '${entry.rewardsBalance ?? '—'} points',
                  BuilderAccessState.suspended =>
                    '${entry.rewardsBalance ?? '—'} points\nRestricted',
                }),
              ),
            ),
          ),
        if (controller.rosterPage.value?.nextCursor != null)
          OutlinedButton(
            onPressed: controller.isLoadingRoster.value
                ? null
                : () => controller.loadRoster(more: true),
            child: const Text('Load more Employees'),
          ),
      ],
    ),
  );
}
