import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/constant/resources/app_colors.dart';
import 'package:employee_wellness/app/constant/routing/app_route.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletRemoveScreen extends BaseView<WalletController> {
  const WalletRemoveScreen({super.key});
  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Remove Wellness Points Access',
    subtitle: 'Preview removal from this device.',
    children: <Widget>[
      WalletCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              size: 58,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Remove Wellness Points access from this device?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              'This preview returns Wellness Points to the not-activated screen. No real account or balance is changed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => controller.requestAuthentication(
                purpose: 'Authorize Wellness Points access removal',
                nextRoute: Routes.wallet,
              ),
              icon: const Icon(Icons.phonelink_erase_outlined),
              label: const Text('Continue removal'),
            ),
            OutlinedButton(
              onPressed: Get.back,
              child: const Text('Keep Wellness Points access'),
            ),
          ],
        ),
      ),
    ],
  );
}
