import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletLockedScreen extends BaseView<WalletController> {
  const WalletLockedScreen({super.key});
  @override
  Widget buildView(BuildContext context) => Obx(() {
    final bool removed =
        controller.accessState.value == RewardsAccessState.removed;
    return WalletPage(
      title: removed
          ? 'Wellness Points Access Disabled'
          : 'Wellness Points Locked',
      subtitle: 'Device authentication protects local access.',
      children: <Widget>[
        WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 58),
              const SizedBox(height: 16),
              Text(
                removed
                    ? 'Access is disabled on this device'
                    : 'Protected actions are locked',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                removed
                    ? 'Your account and Wellness Points are unchanged. If access was only disabled, authenticate to return. If credentials were removed, restore your saved backup.'
                    : 'Locking cancels prepared transfers and approvals. Public balance and receiving details remain available. Every send still requires its own authentication.',
                textAlign: TextAlign.center,
              ),
              if (controller.accessError.value.isNotEmpty)
                Text(controller.accessError.value),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.isChangingAccess.value
                    ? null
                    : controller.unlockRewards,
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(
                  controller.isChangingAccess.value
                      ? 'Authenticating…'
                      : removed
                      ? 'Restore Wellness Points access'
                      : 'Unlock Wellness Points',
                ),
              ),
              OutlinedButton(
                onPressed: controller.isChangingAccess.value
                    ? null
                    : controller.openRewardsRecovery,
                child: const Text('Restore from backup'),
              ),
            ],
          ),
        ),
      ],
    );
  });
}
