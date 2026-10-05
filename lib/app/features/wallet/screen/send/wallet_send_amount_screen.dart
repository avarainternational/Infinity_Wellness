import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletSendAmountScreen extends BaseView<WalletController> {
  const WalletSendAmountScreen({super.key});
  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Send Wellness Points',
    subtitle: 'Enter an amount to prepare a transfer review.',
    children: <Widget>[
      Obx(() {
        final recipient = controller.rewardsRecipient.value;
        final busy = controller.isPreparingTransfer.value;
        return WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (recipient == null)
                const Text('Check a receiving account first.')
              else ...<Widget>[
                const Text('Receiving account'),
                SelectableText(recipient.publicAccount),
                TextField(
                  controller: controller.amountController,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => controller.transferReview.value = null,
                  decoration: InputDecoration(
                    labelText: 'Wellness Points amount',
                    suffixText: recipient.assetCode,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Available Wellness Points, receiving capacity, and native fee funds will be checked before review.',
                ),
              ],
              if (controller.transferError.value.isNotEmpty)
                Text(controller.transferError.value),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: busy || recipient == null
                    ? null
                    : controller.prepareRewardsTransfer,
                child: Text(
                  busy ? 'Preparing transfer…' : 'Prepare transfer review',
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}
