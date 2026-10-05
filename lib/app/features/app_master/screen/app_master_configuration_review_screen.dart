import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/app_master/controller/app_master_controller.dart';
import 'package:employee_wellness/app/features/app_master/widget/app_master_page.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class AppMasterConfigurationReviewScreen extends BaseView<AppMasterController> {
  const AppMasterConfigurationReviewScreen({super.key});

  @override
  Widget buildView(BuildContext context) => Obx(() {
    final ConfigurationRequestReview? review =
        controller.configurationRequestReview.value;
    return AppMasterPage(
      title: 'Review Configuration Request',
      subtitle:
          'Confirm the Employee device request before creating an update.',
      children: <Widget>[
        if (review == null)
          const WalletBoundaryNotice(
            icon: Icons.qr_code_2,
            text: 'Scan or import a valid configuration request first.',
          )
        else ...<Widget>[
          WalletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WalletStatusBadge(label: 'Request verified'),
                const SizedBox(height: 16),
                WalletReviewRow(label: 'Request ID', value: review.requestId),
                WalletReviewRow(
                  label: 'Current version',
                  value: 'v${review.currentVersion}',
                ),
                WalletReviewRow(
                  label: 'Environment',
                  value: review.environment == ProviderEnvironment.test
                      ? 'Test'
                      : 'Production',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const WalletBoundaryNotice(
            icon: Icons.admin_panel_settings_outlined,
            text:
                'The SDK creates an authorized update encrypted for this Employee device only.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.isCreatingConfigurationUpdate.value
                ? null
                : controller.createConfigurationUpdate,
            icon: controller.isCreatingConfigurationUpdate.value
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2),
            label: const Text('Create update QR'),
          ),
        ],
        if (controller.configurationRotationError.value.isNotEmpty)
          Text(
            controller.configurationRotationError.value,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  });
}
