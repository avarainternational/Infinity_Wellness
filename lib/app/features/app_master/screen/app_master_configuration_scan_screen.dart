import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:employee_wellness/app/features/app_master/controller/app_master_controller.dart';
import 'package:employee_wellness/app/features/app_master/service/qr_input_adapter.dart';

class AppMasterConfigurationScanScreen extends StatefulWidget {
  const AppMasterConfigurationScanScreen({super.key});

  @override
  State<AppMasterConfigurationScanScreen> createState() =>
      _AppMasterConfigurationScanScreenState();
}

class _AppMasterConfigurationScanScreenState
    extends State<AppMasterConfigurationScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final AppMasterController controller = Get.find<AppMasterController>();
    final QrInputResult result = controller.qrInputAdapter.fromCapture(capture);
    if (!result.isSuccess) return;
    _handled = true;
    await _scanner.stop();
    await controller.acceptConfigurationRequest(result.value!);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan configuration request')),
    body: MobileScanner(
      controller: _scanner,
      onDetect: _onDetect,
      errorBuilder: (_, MobileScannerException error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'Camera access was denied. Import a request QR image instead.'
                : 'The camera scanner is unavailable.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
