import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletSendOutcomeScreen extends BaseView<WalletController> {
  const WalletSendOutcomeScreen({super.key});
  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Transfer Status',
    subtitle: 'Saved evidence and ledger verification.',
    children: <Widget>[
      Obx(() {
        final outcome = controller.transferOutcome.value;
        return WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (outcome == null)
                const Text('No saved transfer is available.')
              else ...<Widget>[
                Text(switch (outcome.state) {
                  RewardsTransferState.confirmed =>
                    'Wellness Points sent — ledger confirmed',
                  RewardsTransferState.failed =>
                    outcome.resolution == null
                        ? 'Transfer failed on the ledger'
                        : 'Transfer resolved without payment',
                  RewardsTransferState.cancelled =>
                    outcome.resolution == null
                        ? 'Transfer cancelled before submission'
                        : 'Transfer expired without payment',
                  RewardsTransferState.uncertain =>
                    'Transfer outcome is being verified',
                }, style: Theme.of(context).textTheme.titleLarge),
                Text('${outcome.amount} ${outcome.assetCode}'),
                const Text('Receiving account'),
                SelectableText(outcome.publicAccount),
                const Text('Transaction hash'),
                SelectableText(outcome.transactionHash),
                if (outcome.resolution != null) Text(outcome.resolution!),
                if (outcome.state == RewardsTransferState.uncertain)
                  const Text(
                    'Do not send again. A missing transaction or network error does not establish failure.',
                  ),
              ],
              if (controller.transferStatusError.value.isNotEmpty)
                Text(controller.transferStatusError.value),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: controller.isCheckingTransfer.value
                    ? null
                    : () => controller.checkRewardsTransfer(reconcile: true),
                child: Text(
                  controller.isCheckingTransfer.value
                      ? 'Checking ledger…'
                      : 'Check saved transfer',
                ),
              ),
              if (outcome?.state == RewardsTransferState.uncertain)
                _PendingResolution(controller: controller),
              FilledButton(
                onPressed: controller.openWalletOverview,
                child: const Text('Return to Wellness Points'),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

class _PendingResolution extends StatefulWidget {
  const _PendingResolution({required this.controller});
  final WalletController controller;
  @override
  State<_PendingResolution> createState() => _PendingResolutionState();
}

class _PendingResolutionState extends State<_PendingResolution> {
  final _reference = TextEditingController();
  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      OutlinedButton(
        onPressed: widget.controller.isCheckingTransfer.value
            ? null
            : () => widget.controller.resolvePendingTransfer(),
        child: const Text('Resolve expired transfer'),
      ),
      TextField(
        controller: _reference,
        maxLength: 64,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Conflicting transaction reference (optional)',
          helperText:
              'Use only a reference supplied by support. The SDK verifies it.',
        ),
      ),
      OutlinedButton(
        onPressed: widget.controller.isCheckingTransfer.value
            ? null
            : () => widget.controller.resolvePendingTransfer(
                competingHash: _reference.text,
              ),
        child: const Text('Verify support reference'),
      ),
    ],
  );
}
