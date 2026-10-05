import 'package:get/get.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/features/app_master/service/qr_input_adapter.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<WalletController>()) {
      Get.put<WalletController>(
        WalletController(
          Get.find<WalletSdk>(),
          qrInputAdapter: Get.isRegistered<QrInputAdapter>()
              ? Get.find<QrInputAdapter>()
              : null,
        ),
        permanent: true,
      );
    }
  }
}
