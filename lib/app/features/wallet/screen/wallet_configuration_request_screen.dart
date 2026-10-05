import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletConfigurationRequestScreen extends BaseView<WalletController> {
  const WalletConfigurationRequestScreen({super.key});

  @override
  Widget buildView(BuildContext context) => Obx(() {
    final ConfigurationRequestView? request =
        controller.configurationRequest.value;
    return WalletPage(
      title: 'Update Wellness Points Service',
      subtitle: 'Let Wellness Admin prepare a protected service update.',
      children: <Widget>[
        const WalletStepIndicator(current: 1, total: 3, label: 'Request'),
        const SizedBox(height: 16),
        WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: request == null
                    ? const Icon(Icons.qr_code_2, size: 190)
                    : QrImageView(
                        data: request.qrValue,
                        size: 190,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                      ),
              ),
              const SizedBox(height: 16),
              WalletReviewRow(
                label: 'Request ID',
                value: request?.requestId ?? 'Unavailable',
              ),
              WalletReviewRow(
                label: 'Valid until',
                value: request == null
                    ? 'Unavailable'
                    : _formatDate(request.expiresAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const WalletBoundaryNotice(
          icon: Icons.security_outlined,
          text:
              'This request identifies this device without revealing service credentials.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: request == null
              ? null
              : controller.openConfigurationScanner,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan update QR'),
        ),
        OutlinedButton.icon(
          onPressed: request == null
              ? null
              : controller.importConfigurationUpdate,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Import update QR image'),
        ),
        if (controller.configurationError.value.isNotEmpty)
          Text(
            controller.configurationError.value,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  });

  static String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
