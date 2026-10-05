import 'package:employee_wellness/app/constant/resources/wellness_copy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletActivationReviewScreen extends BaseView<WalletController> {
  const WalletActivationReviewScreen({super.key});

  @override
  Widget buildView(BuildContext context) => Obx(() {
    final ActivationReview? review = controller.activationReview.value;
    return WalletPage(
      title: 'Review Activation',
      subtitle: 'Confirm the Wellness Points setup prepared for you.',
      children: <Widget>[
        const WalletStepIndicator(current: 2, total: 3, label: 'Review'),
        const SizedBox(height: 16),
        if (review == null)
          const WalletBoundaryNotice(
            icon: Icons.qr_code_2,
            text: 'Scan or import a verified activation QR first.',
          )
        else ...<Widget>[
          WalletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WalletStatusBadge(label: 'Activation verified'),
                const SizedBox(height: 18),
                WalletReviewRow(
                  label: 'Activation ID',
                  value: review.responseId,
                ),
                WalletReviewRow(
                  label: 'Prepared by',
                  value: employeeFacingText(review.preparedBy),
                ),
                for (final String step in review.setupSteps)
                  WalletReviewRow(
                    label: 'Setup',
                    value: employeeFacingText(step),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const WalletBoundaryNotice(
            icon: Icons.verified_user_outlined,
            text:
                'This activation only sets up Wellness Points access and starting Wellness Points.',
          ),
          const SizedBox(height: 16),
          if (controller.activationOutcome.value == null)
            FilledButton.icon(
              onPressed: controller.isApprovingActivation.value
                  ? null
                  : controller.approveActivation,
              icon: controller.isApprovingActivation.value
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint),
              label: const Text('Approve and activate'),
            )
          else
            WalletBoundaryNotice(
              icon: Icons.schedule_outlined,
              text: employeeFacingText(
                controller.activationOutcome.value!.message,
              ),
            ),
          if (controller.activationResponseError.value.isNotEmpty)
            Text(controller.activationResponseError.value),
        ],
        OutlinedButton(
          onPressed: controller.importActivationResponse,
          child: const Text('Choose another QR image'),
        ),
      ],
    );
  });
}
