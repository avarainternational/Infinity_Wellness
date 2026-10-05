import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/app_master/controller/app_master_controller.dart';
import 'package:employee_wellness/app/features/app_master/widget/app_master_page.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class AppMasterConfigurationQrScreen extends BaseView<AppMasterController> {
  const AppMasterConfigurationQrScreen({super.key});

  @override
  Widget buildView(BuildContext context) => Obx(() {
    final ConfigurationUpdateView? update =
        controller.configurationUpdate.value;
    return AppMasterPage(
      title: 'Configuration Update QR',
      subtitle:
          'Let the requesting Employee device scan this protected update.',
      children: <Widget>[
        WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: update == null
                    ? const Icon(Icons.qr_code_2, size: 190)
                    : QrImageView(
                        data: update.qrValue,
                        size: 190,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                      ),
              ),
              const SizedBox(height: 16),
              WalletReviewRow(
                label: 'Update ID',
                value: update?.updateId ?? 'Unavailable',
              ),
              WalletReviewRow(
                label: 'Request ID',
                value: update?.requestId ?? 'Unavailable',
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: controller.finishConfigurationUpdate,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const WalletBoundaryNotice(
          icon: Icons.security_outlined,
          text:
              'This update expires and can be applied only by the requesting device.',
        ),
      ],
    );
  });
}
