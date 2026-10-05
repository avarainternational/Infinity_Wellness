import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletSendReviewScreen extends BaseView<WalletController> {
  const WalletSendReviewScreen({super.key});
  @override
  Widget buildView(BuildContext context) => Obx(
    () => PopScope(
      canPop: !controller.isSendingTransfer.value,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) controller.cancelTransferAuthorization();
      },
      child: WalletPage(
        title: 'Review Send',
        subtitle: 'Prepared transfer details. No payment has been sent.',
        children: <Widget>[
          Obx(() {
            final review = controller.transferReview.value;
            return WalletCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (review == null)
                    const Text('Prepare a transfer before reviewing it.')
                  else ...<Widget>[
                    WalletReviewRow(
                      label: 'Recipient',
                      value: review.publicAccount,
                    ),
                    WalletReviewRow(
                      label: 'Amount',
                      value: '${review.amount} ${review.assetCode}',
                    ),
                    WalletReviewRow(
                      label: 'Asset issuer',
                      value: review.assetIssuer,
                    ),
                    WalletReviewRow(
                      label: 'Network',
                      value: review.environment.name,
                    ),
                    WalletReviewRow(
                      label: 'Maximum native fee',
                      value: '${review.maximumFee} XLM',
                    ),
                    WalletReviewRow(
                      label: 'Review expires',
                      value: review.expiresAt.toLocal().toString(),
                    ),
                    const Text(
                      'Confirming invokes device authentication and sends this exact transfer once on the network shown above.',
                    ),
                    FilledButton(
                      onPressed: controller.isSendingTransfer.value
                          ? null
                          : controller.approveRewardsTransfer,
                      child: Text(
                        controller.isSendingTransfer.value
                            ? 'Authorizing and checking transfer…'
                            : 'Confirm and send',
                      ),
                    ),
                  ],
                  if (controller.authorizationMessage.value.isNotEmpty)
                    Text(controller.authorizationMessage.value),
                  if (controller.transferError.value.isNotEmpty)
                    Text(controller.transferError.value),
                  OutlinedButton(
                    onPressed: controller.isSendingTransfer.value
                        ? null
                        : Get.back,
                    child: const Text('Go back'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}
