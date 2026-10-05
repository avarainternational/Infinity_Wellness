import 'package:get/get.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<WalletSdk>()) {
      Get.lazyPut<WalletSdk>(createWalletSdk, fenix: true);
    }
  }
}
