import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletConfigurationReviewScreen extends BaseView<WalletController> {
  const WalletConfigurationReviewScreen({super.key});

  @override
  Widget buildView(BuildContext context) => Obx(() {
    final ConfigurationReview? review = controller.configurationReview.value;
    return WalletPage(
      title: 'Review Service Update',
      subtitle: 'Confirm the verified service details before applying them.',
      children: <Widget>[
        const WalletStepIndicator(current: 2, total: 3, label: 'Review'),
        const SizedBox(height: 16),
        if (review == null)
          const WalletBoundaryNotice(
            icon: Icons.qr_code_2,
            text: 'Scan or import a verified configuration update first.',
          )
        else ...<Widget>[
          WalletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WalletStatusBadge(label: 'Update verified'),
                const SizedBox(height: 16),
                WalletReviewRow(label: 'Update ID', value: review.updateId),
                WalletReviewRow(
                  label: 'Environment',
                  value: review.environment == ProviderEnvironment.test
                      ? 'Test'
                      : 'Production',
                ),
                WalletReviewRow(
                  label: 'Configuration version',
                  value: 'v${review.version}',
                ),
                WalletReviewRow(
                  label: 'Service host',
                  value: review.endpointHost,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const WalletBoundaryNotice(
            icon: Icons.health_and_safety_outlined,
            text:
                'The current service settings remain active unless this update passes its health check.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.isApplyingConfigurationUpdate.value
                ? null
                : controller.applyConfigurationUpdate,
            icon: controller.isApplyingConfigurationUpdate.value
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt),
            label: const Text('Apply service update'),
          ),
        ],
        if (controller.configurationError.value.isNotEmpty)
          Text(
            controller.configurationError.value,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  });
}
