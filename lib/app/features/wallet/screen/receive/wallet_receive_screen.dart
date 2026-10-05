import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletReceiveScreen extends BaseView<WalletController> {
  const WalletReceiveScreen({super.key});
  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Receive Wellness Points',
    subtitle: 'Share your public Wellness Points account.',
    children: <Widget>[
      WalletCard(
        child: Obx(() {
          if (controller.isLoadingReceive.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final identity = controller.receiveIdentity.value;
          if (identity == null) {
            return Column(
              children: <Widget>[
                Text(
                  controller.receiveError.value.isEmpty
                      ? 'Load your Wellness Points receiving details.'
                      : controller.receiveError.value,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: controller.loadReceiveIdentity,
                  child: const Text('Load receiving details'),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: QrImageView(data: identity.qrValue, size: 196)),
              const SizedBox(height: 18),
              const Text(
                'Public Wellness Points account',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              SelectableText(
                identity.publicAccount,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: identity.publicAccount),
                  );
                  Get.snackbar(
                    'Copied',
                    'Public Wellness Points account copied.',
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy Wellness Points account'),
              ),
              FilledButton(onPressed: Get.back, child: const Text('Done')),
            ],
          );
        }),
      ),
    ],
  );
}
