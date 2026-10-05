import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletConfigurationOutcomeScreen extends BaseView<WalletController> {
  const WalletConfigurationOutcomeScreen({super.key});

  @override
  Widget buildView(BuildContext context) => Obx(() {
    final ProviderConfigurationStatus? status =
        controller.configurationOutcome.value?.status;
    return WalletPage(
      title: 'Service Updated',
      subtitle: 'Your Wellness Points service settings are ready.',
      children: <Widget>[
        const WalletStepIndicator(current: 3, total: 3, label: 'Complete'),
        const SizedBox(height: 16),
        WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const WalletStatusBadge(label: 'Configuration ready'),
              const SizedBox(height: 16),
              WalletReviewRow(
                label: 'Version',
                value: status?.version == null
                    ? 'Unavailable'
                    : 'v${status!.version}',
              ),
              WalletReviewRow(
                label: 'Environment',
                value: status?.environment == ProviderEnvironment.test
                    ? 'Test'
                    : 'Production',
              ),
              WalletReviewRow(
                label: 'Service host',
                value: status?.endpointHost ?? 'Protected service',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.finishConfigurationUpdate,
          child: const Text('Return to Wellness Points'),
        ),
      ],
    );
  });
}
