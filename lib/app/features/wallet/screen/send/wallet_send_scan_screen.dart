import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:employee_wellness/app/core/base/base_view.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/wallet/widget/wallet_ui.dart';

class WalletSendScanScreen extends BaseView<WalletController> {
  const WalletSendScanScreen({super.key});
  @override
  Widget buildView(BuildContext context) => WalletPage(
    title: 'Scan Recipient',
    subtitle: 'Check a public account for your Wellness Points asset.',
    children: <Widget>[_RecipientInput(controller: controller)],
  );
}

class _RecipientInput extends StatefulWidget {
  const _RecipientInput({required this.controller});
  final WalletController controller;
  @override
  State<_RecipientInput> createState() => _RecipientInputState();
}

class _RecipientInputState extends State<_RecipientInput> {
  MobileScannerController? _scanner;
  bool _handled = false;
  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  Future<void> _capture(BarcodeCapture capture) async {
    if (_handled || widget.controller.isInspectingRecipient.value) return;
    final result = widget.controller.qrInputAdapter.fromCapture(capture);
    if (!result.isSuccess) return;
    _handled = true;
    await _scanner?.stop();
    await widget.controller.inspectRewardsRecipient(result.value!);
    if (!mounted) return;
    final scanner = _scanner;
    setState(() => _scanner = null);
    await scanner?.dispose();
  }

  void _startCamera() {
    widget.controller.clearRecipientObservation();
    _handled = false;
    setState(
      () => _scanner = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      ),
    );
  }

  Future<void> _closeCamera() async {
    _handled = true;
    final scanner = _scanner;
    setState(() => _scanner = null);
    await scanner?.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final controller = widget.controller;
    final busy =
        controller.isInspectingRecipient.value ||
        controller.isImportingRecipient.value;
    final recipient = controller.rewardsRecipient.value;
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_scanner != null)
            SizedBox(
              height: 250,
              child: MobileScanner(
                controller: _scanner!,
                onDetect: _capture,
                errorBuilder: (_, error) => const Center(
                  child: Text(
                    'Camera unavailable. Use gallery or enter the address.',
                  ),
                ),
              ),
            ),
          if (_scanner != null)
            OutlinedButton(
              onPressed: busy ? null : _closeCamera,
              child: const Text('Close camera'),
            ),
          if (_scanner == null)
            OutlinedButton.icon(
              onPressed: busy ? null : _startCamera,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan receiving QR'),
            ),
          OutlinedButton.icon(
            onPressed: busy || _scanner != null
                ? null
                : controller.importRecipientQr,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Import QR image'),
          ),
          TextField(
            controller: controller.recipientController,
            enabled: !busy && _scanner == null,
            onChanged: (_) => controller.clearRecipientObservation(),
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Public receiving account',
              hintText: 'G…',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy || _scanner != null
                ? null
                : () => controller.inspectRewardsRecipient(
                    controller.recipientController.text,
                  ),
            child: Text(busy ? 'Checking recipient…' : 'Check recipient'),
          ),
          if (controller.recipientError.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(controller.recipientError.value),
            ),
          if (recipient != null) ...<Widget>[
            const SizedBox(height: 16),
            const Text('Receiving account checked'),
            SelectableText(recipient.publicAccount),
            Text(
              'Can receive up to ${recipient.receivingCapacity} ${recipient.assetCode}',
            ),
            Text('Network: ${recipient.environment.name}'),
            const SizedBox(height: 12),
            const Text(
              'Recipient and funds will be checked again when preparing the transfer.',
            ),
            FilledButton(
              onPressed: busy ? null : controller.openRewardsAmount,
              child: const Text('Enter amount'),
            ),
          ],
        ],
      ),
    );
  });
}
