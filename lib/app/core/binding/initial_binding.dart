import 'package:get/get.dart';
import 'package:employee_wellness/app/constant/resources/wellness_copy.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<WalletSdk>()) {
      // Wallet and admin controllers outlive route replacement and must share
      // the same authorization, transfer and recovery state for this session.
      Get.put<WalletSdk>(
        createWalletSdk(authenticationMessageMapper: employeeFacingText),
        permanent: true,
      );
    }
  }
}
