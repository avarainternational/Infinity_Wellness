import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

/// Legacy route uses the same native SDK gate; it cannot approve a send/removal.
class WalletAuthenticationScreen extends BaseView<WalletController> {
  const WalletAuthenticationScreen({super.key});
  @override
  Widget buildView(BuildContext context) => Obx(
    () => WalletPage(
      title: 'Unlock Wellness Points',
      subtitle: 'Authenticate with your device.',
      children: <Widget>[
        const Text(
          'Use device authentication to unlock local access. Sending and removal require separate confirmation.',
        ),
        if (controller.accessError.value.isNotEmpty)
          Text(controller.accessError.value),
        FilledButton.icon(
          onPressed: controller.isChangingAccess.value
              ? null
              : controller.unlockRewards,
          icon: const Icon(Icons.fingerprint),
          label: const Text('Authenticate'),
        ),
        TextButton(
          onPressed: controller.isChangingAccess.value ? null : Get.back,
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
