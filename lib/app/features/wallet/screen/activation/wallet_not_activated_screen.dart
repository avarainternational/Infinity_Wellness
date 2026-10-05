import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/constant/resources/app_colors.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/profile/widget/employee_identity_card.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_screen_components.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletNotActivatedScreen extends BaseView<WalletController> {
  const WalletNotActivatedScreen({super.key});

  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Employee Wallet',
    subtitle: 'Set up Wellness Points on this device.',
    trailing: IconButton.filledTonal(
      onPressed: controller.openAppMaster,
      tooltip: 'Open Wellness Admin',
      icon: const Icon(Icons.hub_outlined),
    ),
    children: <Widget>[
      Obx(
        () => EmployeeIdentityCard.editable(
          nameController: controller.builderNameController,
          phoneController: controller.phoneController,
          errorText: controller.activationError.value,
          enabled: !controller.isPreparingActivation.value,
        ),
      ),
      const SizedBox(height: 16),
      WalletCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 54,
              color: AppColors.violet,
            ),
            const SizedBox(height: 16),
            Text(
              'Employee Wallet is not activated',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Activate Wellness Points on this device to view your balance, receive Wellness Points, and send Wellness Points.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isPreparingActivation.value
                    ? null
                    : controller.startActivation,
                icon: controller.isPreparingActivation.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(
                  controller.isPreparingActivation.value
                      ? 'Preparing your activation request…'
                      : 'Start activation',
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const WalletPreviewNotice(),
    ],
  );
}
