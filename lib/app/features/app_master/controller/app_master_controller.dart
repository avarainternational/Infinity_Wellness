import 'package:employee_wellness/app/constant/resources/wellness_copy.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/constant/routing/app_route.dart';
import 'package:employee_wellness/app/core/base/base_controller.dart';
import 'package:employee_wellness/app/features/app_master/service/qr_input_adapter.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class AppMasterController extends BaseController {
  AppMasterController(this._walletSdk, {QrInputAdapter? qrInputAdapter})
    : qrInputAdapter = qrInputAdapter ?? QrInputAdapter();

  final WalletSdk _walletSdk;
  final QrInputAdapter qrInputAdapter;

  final RxList<BuilderAccessEntry> rosterEntries = <BuilderAccessEntry>[].obs;
  final Rxn<AppMasterRosterPage> rosterPage = Rxn<AppMasterRosterPage>();
  final RxBool isLoadingRoster = false.obs;
  final RxString rosterError = ''.obs;

  Future<void> loadRoster({bool more = false}) async {
    if (isLoadingRoster.value ||
        (more && rosterPage.value?.nextCursor == null)) {
      return;
    }
    isLoadingRoster.value = true;
    rosterError.value = '';
    final previous = rosterPage.value;
    if (!more) {
      rosterEntries.clear();
      rosterPage.value = null;
    }
    try {
      final page = await _walletSdk.getAppMasterRoster(
        cursor: more ? previous?.nextCursor : null,
      );
      if (isClosed) return;
      if (more &&
          (page.environment != previous?.environment ||
              page.authorityAccount != previous?.authorityAccount)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rosterAccessDenied,
          safeMessage:
              'Refresh Employee access after changing Wellness Admin settings.',
          canRetry: false,
        );
      }
      final ids = rosterEntries.map((entry) => entry.id).toSet();
      if (page.entries.any((entry) => ids.contains(entry.id))) {
        throw StateError('Non-progressing roster.');
      }
      rosterEntries.addAll(page.entries);
      rosterPage.value = page;
    } on WalletSdkException catch (error) {
      rosterEntries.clear();
      rosterPage.value = null;
      rosterError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      rosterEntries.clear();
      rosterPage.value = null;
      rosterError.value =
          'Employee access is unavailable. Refresh or contact your administrator.';
    } finally {
      isLoadingRoster.value = false;
    }
  }

  String nowNodesEndpoint = 'https://xlm.nownodes.io';
  String nowNodesApiKey = '';
  final Rx<ProviderEnvironment> providerEnvironment =
      ProviderEnvironment.production.obs;
  final Rx<ProviderConfigurationStatus> providerConfigurationStatus =
      const ProviderConfigurationStatus.notConfigured().obs;
  final RxBool isSavingProviderConfiguration = false.obs;
  final RxString providerConfigurationError = ''.obs;
  final RxInt providerKeyFieldRevision = 0.obs;
  String distributorSecret = '';
  final Rx<DistributorAuthorityStatus> distributorAuthorityStatus =
      const DistributorAuthorityStatus.notConfigured().obs;
  final RxBool isSavingDistributorAuthority = false.obs;
  final RxString distributorAuthorityError = ''.obs;
  final RxInt distributorSecretFieldRevision = 0.obs;
  final Rxn<AppMasterOverview> appMasterOverview = Rxn<AppMasterOverview>();
  final RxBool isRefreshingOverview = false.obs;
  final RxString overviewError = ''.obs;
  final RxBool isImportingActivationRequest = false.obs;
  final RxString qrInputError = ''.obs;
  final RxBool isInspectingActivationRequest = false.obs;
  final Rxn<ActivationRequestReview> activationRequestReview =
      Rxn<ActivationRequestReview>();
  final Rxn<ActivationResponseView> activationResponse =
      Rxn<ActivationResponseView>();
  final RxBool isCreatingActivationResponse = false.obs;
  final RxString activationResponseError = ''.obs;
  String? _pendingActivationRequestValue;
  final Rxn<ConfigurationRequestReview> configurationRequestReview =
      Rxn<ConfigurationRequestReview>();
  final Rxn<ConfigurationUpdateView> configurationUpdate =
      Rxn<ConfigurationUpdateView>();
  final RxBool isImportingConfigurationRequest = false.obs;
  final RxBool isInspectingConfigurationRequest = false.obs;
  final RxBool isCreatingConfigurationUpdate = false.obs;
  final RxString configurationRotationError = ''.obs;

  String? get pendingActivationRequestValue => _pendingActivationRequestValue;

  @override
  void onReady() {
    super.onReady();
    restoreProviderConfigurationStatus();
    restoreDistributorAuthorityStatus();
    restoreActivationRequestReview();
    refreshOverview();
    loadRoster();
  }

  Future<void> restoreProviderConfigurationStatus() async {
    try {
      final ProviderConfigurationStatus status = await _walletSdk
          .getProviderConfigurationStatus();
      providerConfigurationStatus.value = status;
      activationFunding = status.activationFunding;
      initialRewards = status.initialRewards;
      if (status.environment != null) {
        providerEnvironment.value = status.environment!;
      }
    } catch (_) {
      providerConfigurationError.value =
          "We couldn't load the service status. Try again.";
    }
  }

  String activationFunding = '2.1';
  String initialRewards = '1';

  Future<void> saveProviderConfiguration() async {
    if (isSavingProviderConfiguration.value) {
      return;
    }

    providerConfigurationError.value = '';
    isSavingProviderConfiguration.value = true;
    try {
      final ProviderConfigurationOutcome outcome = await _walletSdk
          .saveAppMasterProviderConfiguration(
            ProviderConfigurationInput(
              endpoint: nowNodesEndpoint.trim(),
              apiKey: nowNodesApiKey.trim(),
              environment: providerEnvironment.value,
              version: (providerConfigurationStatus.value.version ?? 0) + 1,
              activationFunding: activationFunding,
              initialRewards: initialRewards,
            ),
          );
      providerConfigurationStatus.value = outcome.status;
    } on WalletSdkException catch (error) {
      providerConfigurationError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      providerConfigurationError.value =
          "We couldn't save these settings. Try again.";
    } finally {
      nowNodesApiKey = '';
      providerKeyFieldRevision.value++;
      isSavingProviderConfiguration.value = false;
    }
  }

  Future<void> restoreDistributorAuthorityStatus() async {
    distributorAuthorityStatus.value = await _walletSdk
        .getDistributorAuthorityStatus();
  }

  Future<void> importDistributorAuthority() async {
    if (isSavingDistributorAuthority.value) {
      return;
    }
    distributorAuthorityError.value = '';
    isSavingDistributorAuthority.value = true;
    try {
      distributorAuthorityStatus.value = await _walletSdk
          .importDistributorSecret(distributorSecret);
    } on WalletSdkException catch (error) {
      distributorAuthorityError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      distributorAuthorityError.value =
          "We couldn't import the distributor account. Try again.";
    } finally {
      distributorSecret = '';
      distributorSecretFieldRevision.value++;
      isSavingDistributorAuthority.value = false;
    }
  }

  Future<void> removeDistributorAuthority() async {
    try {
      await _walletSdk.removeDistributorAuthority();
      distributorAuthorityStatus.value =
          const DistributorAuthorityStatus.notConfigured();
      distributorAuthorityError.value = '';
    } on WalletSdkException catch (error) {
      distributorAuthorityError.value = employeeFacingText(error.safeMessage);
    }
  }

  Future<void> refreshOverview() async {
    if (isRefreshingOverview.value) {
      return;
    }
    isRefreshingOverview.value = true;
    overviewError.value = '';
    try {
      appMasterOverview.value = await _walletSdk.getAppMasterOverview();
    } on WalletSdkException catch (error) {
      overviewError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      overviewError.value =
          "We couldn't refresh Wellness Admin status. Try again.";
    } finally {
      isRefreshingOverview.value = false;
    }
  }

  void openBuilderWallet() => Get.offAllNamed(Routes.wallet);

  void openAdvanced() => Get.offAllNamed(Routes.appMasterAdvanced);

  void openActivationReview() => Get.toNamed(Routes.appMasterActivationReview);

  void openActivationScanner() {
    qrInputError.value = '';
    Get.toNamed(Routes.appMasterActivationScan);
  }

  void openConfigurationScanner() {
    configurationRotationError.value = '';
    Get.toNamed(Routes.appMasterConfigurationScan);
  }

  Future<void> importConfigurationRequest() async {
    if (isImportingConfigurationRequest.value) return;
    configurationRotationError.value = '';
    isImportingConfigurationRequest.value = true;
    try {
      final QrInputResult result = await qrInputAdapter.importFromGallery();
      if (result.isSuccess) {
        await acceptConfigurationRequest(result.value!);
      } else if (result.failure != QrInputFailure.cancelled) {
        configurationRotationError.value = switch (result.failure!) {
          QrInputFailure.permissionDenied =>
            'Photo access was denied. Scan the request QR instead.',
          QrInputFailure.unreadable =>
            "We couldn't find a readable configuration QR in that image.",
          QrInputFailure.multipleCodes =>
            'Use an image containing only one configuration QR.',
          QrInputFailure.cancelled => '',
        };
      }
    } finally {
      isImportingConfigurationRequest.value = false;
    }
  }

  Future<void> acceptConfigurationRequest(String value) async {
    if (isInspectingConfigurationRequest.value) return;
    configurationRotationError.value = '';
    isInspectingConfigurationRequest.value = true;
    try {
      configurationRequestReview.value = await _walletSdk
          .inspectConfigurationRequest(value);
      Get.offNamed(Routes.appMasterConfigurationReview);
    } on WalletSdkException catch (error) {
      configurationRotationError.value = employeeFacingText(error.safeMessage);
      if (Get.currentRoute == Routes.appMasterConfigurationScan) {
        Get.back<void>();
      }
    } catch (_) {
      configurationRotationError.value =
          "We couldn't inspect this configuration request. Try again.";
      if (Get.currentRoute == Routes.appMasterConfigurationScan) {
        Get.back<void>();
      }
    } finally {
      isInspectingConfigurationRequest.value = false;
    }
  }

  Future<void> createConfigurationUpdate() async {
    final ConfigurationRequestReview? review = configurationRequestReview.value;
    if (review == null || isCreatingConfigurationUpdate.value) return;
    configurationRotationError.value = '';
    isCreatingConfigurationUpdate.value = true;
    try {
      configurationUpdate.value = await _walletSdk.createConfigurationUpdate(
        review.requestId,
      );
      Get.toNamed(Routes.appMasterConfigurationQr);
    } on WalletSdkException catch (error) {
      configurationRotationError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      configurationRotationError.value =
          "We couldn't create the configuration update. Try again.";
    } finally {
      isCreatingConfigurationUpdate.value = false;
    }
  }

  void finishConfigurationUpdate() => Get.offAllNamed(Routes.appMasterAdvanced);

  Future<void> importActivationRequest() async {
    if (isImportingActivationRequest.value) {
      return;
    }
    qrInputError.value = '';
    isImportingActivationRequest.value = true;
    try {
      final QrInputResult result = await qrInputAdapter.importFromGallery();
      if (result.isSuccess) {
        await acceptActivationRequest(result.value!);
      } else {
        handleQrFailure(result.failure!);
      }
    } finally {
      isImportingActivationRequest.value = false;
    }
  }

  Future<void> acceptActivationRequest(String opaqueValue) async {
    if (isInspectingActivationRequest.value) {
      return;
    }
    _pendingActivationRequestValue = opaqueValue;
    qrInputError.value = '';
    isInspectingActivationRequest.value = true;
    try {
      activationRequestReview.value = await _walletSdk.inspectBuilderRequest(
        opaqueValue,
      );
      Get.offNamed(Routes.appMasterActivationReview);
    } on WalletSdkException catch (error) {
      qrInputError.value = employeeFacingText(error.safeMessage);
      if (Get.currentRoute == Routes.appMasterActivationScan) {
        Get.back<void>();
      }
    } catch (_) {
      qrInputError.value =
          "We couldn't inspect this activation request. Try again.";
      if (Get.currentRoute == Routes.appMasterActivationScan) {
        Get.back<void>();
      }
    } finally {
      _pendingActivationRequestValue = null;
      isInspectingActivationRequest.value = false;
    }
  }

  Future<void> restoreActivationRequestReview() async {
    activationRequestReview.value = await _walletSdk
        .restoreInspectedBuilderRequest();
  }

  void handleQrFailure(QrInputFailure failure) {
    qrInputError.value = switch (failure) {
      QrInputFailure.cancelled => '',
      QrInputFailure.permissionDenied =>
        'Camera access was denied. Import a QR image instead.',
      QrInputFailure.unreadable =>
        "We couldn't find a readable activation QR in that image.",
      QrInputFailure.multipleCodes =>
        'Use an image or camera view containing only one QR code.',
    };
  }

  Future<void> openActivationQr() async {
    final ActivationRequestReview? review = activationRequestReview.value;
    if (review == null || isCreatingActivationResponse.value) return;
    isCreatingActivationResponse.value = true;
    activationResponseError.value = '';
    try {
      activationResponse.value = await _walletSdk.approveBuilderRequest(
        review.requestId,
      );
      Get.toNamed(Routes.appMasterActivationQr);
    } on WalletSdkException catch (error) {
      activationResponseError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      activationResponseError.value =
          "We couldn't create the activation package. Try again.";
    } finally {
      isCreatingActivationResponse.value = false;
    }
  }

  void finishActivation() => Get.offAllNamed(Routes.appMaster);
}
