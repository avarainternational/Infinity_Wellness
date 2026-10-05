import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/constant/routing/app_route.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

const String _mockRecipient = 'Avery Chen  •  BLD-AC-00831';

class WalletSendReviewScreen extends BaseView<WalletController> {
  const WalletSendReviewScreen({super.key});
  @override
  Widget buildView(BuildContext context) {
    final String amount = controller.amountController.text.trim().isEmpty
        ? '25 pts'
        : '${controller.amountController.text.trim()} pts';
    return WalletPage(
      title: 'Review Send',
      subtitle: 'Check the details before the mock confirmation.',
      children: <Widget>[
        WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const WalletReviewRow(label: 'Recipient', value: _mockRecipient),
              WalletReviewRow(label: 'Amount', value: amount),
              const WalletReviewRow(
                label: 'Reward type',
                value: 'Wellness Points',
              ),
              const WalletReviewRow(label: 'Status', value: 'UI preview only'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => controller.requestAuthentication(
                  purpose: 'Authorize mock Wellness Points send',
                  nextRoute: Routes.walletSendOutcome,
                ),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Confirm send'),
              ),
              OutlinedButton(onPressed: Get.back, child: const Text('Go back')),
            ],
          ),
        ),
      ],
    );
  }
}
