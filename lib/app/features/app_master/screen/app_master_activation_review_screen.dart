import 'package:employee_wellness/app/constant/resources/wellness_copy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/app_master/controller/app_master_controller.dart';
import 'package:employee_wellness/app/features/app_master/widget/app_master_page.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class AppMasterActivationReviewScreen extends BaseView<AppMasterController> {
  const AppMasterActivationReviewScreen({super.key});

  @override
  Widget buildView(BuildContext context) => Obx(() {
    final ActivationRequestReview? review =
        controller.activationRequestReview.value;
    return AppMasterPage(
      title: 'Activate Employee',
      subtitle: 'Review the Employee request and activation setup.',
      children: review == null
          ? <Widget>[
              const WalletBoundaryNotice(
                icon: Icons.qr_code_2,
                text:
                    'Scan or import a valid Employee activation request first.',
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: controller.finishActivation,
                child: const Text('Back to Wellness Admin'),
              ),
            ]
          : _reviewContent(review),
    );
  });

  List<Widget> _reviewContent(ActivationRequestReview review) => <Widget>[
    WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WalletStatusBadge(label: 'Request verified'),
          const SizedBox(height: 18),
          WalletReviewRow(label: 'Employee', value: review.builder.displayName),
          WalletReviewRow(label: 'Phone', value: review.builder.phone),
          WalletReviewRow(label: 'Activation ID', value: review.requestId),
          WalletReviewRow(
            label: 'Valid until',
            value: _formatExpiry(review.expiresAt),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Activation package',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          for (int index = 0; index < review.setupSteps.length; index++)
            WalletReviewRow(
              label:
                  '${index + 1}. ${employeeFacingText(review.setupSteps[index])}',
              value: index == 0 ? 'Activation costs covered' : 'Ready',
            ),
          const WalletReviewRow(
            label: 'Setup cost',
            value: 'Covered by Wellness Admin',
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    const WalletBoundaryNotice(
      icon: Icons.verified_user_outlined,
      text:
          'The Employee reviews and approves this activation on their own device.',
    ),
    const SizedBox(height: 16),
    Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (controller.activationResponseError.value.isNotEmpty)
            Text(
              controller.activationResponseError.value,
              style: const TextStyle(color: Colors.red),
            ),
          FilledButton.icon(
            onPressed: controller.isCreatingActivationResponse.value
                ? null
                : controller.openActivationQr,
            icon: controller.isCreatingActivationResponse.value
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.draw_outlined),
            label: const Text('Create activation QR'),
          ),
        ],
      ),
    ),
    OutlinedButton(
      onPressed: controller.finishActivation,
      child: const Text('Cancel'),
    ),
  ];

  String _formatExpiry(DateTime value) {
    final DateTime local = value.toLocal();
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.hour}:$minute';
  }
}
