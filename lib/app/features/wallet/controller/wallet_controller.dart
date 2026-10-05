import 'package:employee_wellness/app/constant/resources/wellness_copy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:employee_wellness/app/constant/routing/app_route.dart';
import 'package:employee_wellness/app/core/base/base_controller.dart';
import 'package:employee_wellness/app/features/app_master/service/qr_input_adapter.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

class WalletController extends BaseController {
  WalletController(this._walletSdk, {QrInputAdapter? qrInputAdapter})
    : qrInputAdapter = qrInputAdapter ?? QrInputAdapter();

  final WalletSdk _walletSdk;
  final QrInputAdapter qrInputAdapter;
  final Rx<RewardsAccessState> accessState = RewardsAccessState.locked.obs;
  final RxBool isChangingAccess = false.obs;
  final RxString accessError = ''.obs;

  void openRewardsRecovery() {
    Get.to<void>(
      () => RewardsRecoveryPage(
        sdk: _walletSdk,
        messageMapper: employeeFacingText,
        onChanged: () async {
          rewardsBalance.value = null;
          receiveIdentity.value = null;
          rewardsRecipient.value = null;
          transferReview.value = null;
          transferOutcome.value = null;
          historyItems.clear();
          historyPage.value = null;
          amountController.clear();
          recipientController.clear();
          await refreshAccessState();
          Get.offAllNamed(
            accessState.value == RewardsAccessState.removed
                ? Routes.walletLocked
                : Routes.walletOverview,
          );
        },
      ),
    );
  }

  Future<void> resolvePendingTransfer({String? competingHash}) async {
    if (isCheckingTransfer.value) return;
    isCheckingTransfer.value = true;
    transferStatusError.value = '';
    try {
      transferOutcome.value = await _walletSdk.resolvePendingRewardsTransfer(
        competingTransactionHash: competingHash,
      );
      if (transferOutcome.value?.state == RewardsTransferState.uncertain) {
        transferStatusError.value =
            'Not enough verified evidence yet. Keep this transfer saved, retry later, or ask Wellness Admin for a conflicting transaction reference.';
      }
    } on WalletSdkException catch (error) {
      transferStatusError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      transferStatusError.value =
          'Resolution is unavailable. Keep the saved transfer.';
    } finally {
      isCheckingTransfer.value = false;
    }
  }

  Future<void> refreshAccessState() async {
    try {
      accessState.value = await _walletSdk.getRewardsAccessState();
    } on WalletSdkException catch (error) {
      accessError.value = employeeFacingText(error.safeMessage);
    }
  }

  Future<void> unlockRewards() async {
    if (isChangingAccess.value) return;
    isChangingAccess.value = true;
    accessError.value = '';
    try {
      await _walletSdk.unlockRewards();
      await refreshAccessState();
      if (accessState.value == RewardsAccessState.unlocked) {
        Get.offAllNamed(Routes.walletOverview);
      }
    } on WalletSdkException catch (error) {
      accessError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      accessError.value = 'Wellness Points access could not be restored.';
    } finally {
      isChangingAccess.value = false;
    }
  }

  Future<void> removeRewardsAccess() async {
    if (isChangingAccess.value) return;
    isChangingAccess.value = true;
    accessError.value = '';
    try {
      await _walletSdk.removeRewardsAccess();
      await refreshAccessState();
      rewardsBalance.value = null;
      receiveIdentity.value = null;
      rewardsRecipient.value = null;
      transferReview.value = null;
      transferOutcome.value = null;
      historyItems.clear();
      historyPage.value = null;
      amountController.clear();
      recipientController.clear();
      Get.offAllNamed(Routes.walletLocked);
    } on WalletSdkException catch (error) {
      accessError.value = employeeFacingText(error.safeMessage);
      await refreshAccessState();
    } catch (_) {
      accessError.value =
          'Check saved Wellness Points access before continuing.';
    } finally {
      isChangingAccess.value = false;
    }
  }

  final TextEditingController builderNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController recipientController = TextEditingController();
  final Rxn<RewardsRecipientView> rewardsRecipient =
      Rxn<RewardsRecipientView>();
  final RxBool isInspectingRecipient = false.obs;
  final RxBool isImportingRecipient = false.obs;
  final RxString recipientError = ''.obs;
  final Rxn<RewardsTransferReview> transferReview =
      Rxn<RewardsTransferReview>();
  final RxBool isPreparingTransfer = false.obs;
  final Rxn<RewardsTransferOutcome> transferOutcome =
      Rxn<RewardsTransferOutcome>();
  final RxBool isSendingTransfer = false.obs;
  final RxBool isCheckingTransfer = false.obs;
  final RxString transferStatusError = ''.obs;

  Future<void> approveRewardsTransfer() async {
    if (isSendingTransfer.value || transferReview.value == null) return;
    isSendingTransfer.value = true;
    transferError.value = '';
    try {
      transferOutcome.value = await _walletSdk.approveRewardsTransfer(
        transferReview.value!.reviewId,
      );
      Get.offNamed(Routes.walletSendOutcome);
      await refreshRewardsBalance();
    } on WalletSdkException catch (error) {
      transferError.value = employeeFacingText(error.safeMessage);
      try {
        final saved = await _walletSdk.getRewardsTransferStatus();
        if (saved != null) {
          transferOutcome.value = saved;
          Get.offNamed(Routes.walletSendOutcome);
        }
      } catch (_) {
        /* Preserve the safe error and never retry submission. */
      }
    } catch (_) {
      transferError.value =
          'Check the saved transfer status before trying again.';
    } finally {
      isSendingTransfer.value = false;
    }
  }

  Future<void> checkRewardsTransfer({bool reconcile = false}) async {
    if (isCheckingTransfer.value) return;
    isCheckingTransfer.value = true;
    transferStatusError.value = '';
    try {
      transferOutcome.value = await _walletSdk.getRewardsTransferStatus(
        reconcile: reconcile,
      );
    } on WalletSdkException catch (error) {
      transferStatusError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      transferStatusError.value =
          'Saved transfer status is unavailable. Contact Wellness Admin.';
    } finally {
      isCheckingTransfer.value = false;
    }
  }

  Future<void> openTransferStatus() async {
    await checkRewardsTransfer();
    Get.toNamed(Routes.walletSendOutcome);
  }

  final RxString transferError = ''.obs;
  final RxBool isAuthorizingTransfer = false.obs;
  final RxString authorizationMessage = ''.obs;
  int _authorizationRequest = 0;

  Future<void> authorizeRewardsTransfer() async {
    if (isAuthorizingTransfer.value) return;
    final RewardsTransferReview? review = transferReview.value;
    if (review == null) return;
    final int request = ++_authorizationRequest;
    isAuthorizingTransfer.value = true;
    authorizationMessage.value = '';
    try {
      await _walletSdk.authorizeRewardsTransfer(review.reviewId);
      if (request != _authorizationRequest) return;
      authorizationMessage.value =
          'Device authentication completed for this review. Confirm to send before the review expires.';
    } on WalletSdkException catch (error) {
      if (request != _authorizationRequest) return;
      authorizationMessage.value = employeeFacingText(error.safeMessage);
      if (error.code == WalletSdkFailureCode.invalidRewardsTransferReview) {
        transferReview.value = null;
      }
    } catch (_) {
      if (request == _authorizationRequest) {
        authorizationMessage.value =
            'Device authentication was unavailable. No payment was sent.';
      }
    } finally {
      isAuthorizingTransfer.value = false;
    }
  }

  Future<void> cancelTransferAuthorization() async {
    _authorizationRequest++;
    authorizationMessage.value = '';
    transferReview.value = null;
    await _walletSdk.cancelRewardsTransferAuthorization();
  }

  void openRewardsAmount() {
    if (rewardsRecipient.value == null) return;
    transferReview.value = null;
    transferError.value = '';
    amountController.clear();
    Get.toNamed(Routes.walletSendAmount);
  }

  Future<void> prepareRewardsTransfer() async {
    if (isPreparingTransfer.value) return;
    final RewardsRecipientView? recipient = rewardsRecipient.value;
    if (recipient == null) {
      transferError.value = 'Check a receiving account first.';
      return;
    }
    isPreparingTransfer.value = true;
    authorizationMessage.value = '';
    transferError.value = '';
    transferReview.value = null;
    try {
      final RewardsTransferReview review = await _walletSdk
          .prepareRewardsTransfer(
            publicAccount: recipient.publicAccount,
            amount: amountController.text,
          );
      transferReview.value = await _walletSdk.getPreparedRewardsTransfer(
        review.reviewId,
      );
      Get.toNamed(Routes.walletSendReview);
    } on WalletSdkException catch (error) {
      transferError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      transferError.value = 'We could not prepare this transfer. Try again.';
    } finally {
      isPreparingTransfer.value = false;
    }
  }

  void clearRecipientObservation() {
    transferReview.value = null;
    rewardsRecipient.value = null;
    recipientError.value = '';
  }

  Future<void> inspectRewardsRecipient(String value) async {
    if (isInspectingRecipient.value) return;
    isInspectingRecipient.value = true;
    clearRecipientObservation();
    try {
      final result = await _walletSdk.inspectRewardsRecipient(value);
      recipientController.text = result.publicAccount;
      rewardsRecipient.value = result;
    } on WalletSdkException catch (error) {
      recipientError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      recipientError.value = 'We could not check this recipient. Try again.';
    } finally {
      isInspectingRecipient.value = false;
    }
  }

  Future<void> importRecipientQr() async {
    if (isInspectingRecipient.value || isImportingRecipient.value) return;
    isImportingRecipient.value = true;
    clearRecipientObservation();
    try {
      final result = await qrInputAdapter.importFromGallery();
      if (result.isSuccess) {
        await inspectRewardsRecipient(result.value!);
      } else if (result.failure != QrInputFailure.cancelled) {
        recipientError.value =
            'Choose an image with one public-account QR code.';
      }
    } catch (_) {
      recipientError.value = 'We could not open the QR image. Try again.';
    } finally {
      isImportingRecipient.value = false;
    }
  }

  final RxString activationError = ''.obs;
  final RxBool isPreparingActivation = false.obs;
  final RxBool isCancellingActivation = false.obs;
  final RxString activationCancellationError = ''.obs;
  final Rx<ActivationRequestView?> activationRequest =
      Rx<ActivationRequestView?>(null);
  final Rxn<ActivationReview> activationReview = Rxn<ActivationReview>();
  final RxBool isInspectingActivationResponse = false.obs;
  final RxString activationResponseError = ''.obs;
  final RxBool isApprovingActivation = false.obs;
  final Rxn<ActivationOutcome> activationOutcome = Rxn<ActivationOutcome>();
  final Rx<WalletActivationStatus> activationStatus =
      const WalletActivationStatus.notActivated().obs;
  final Rxn<ConfigurationRequestView> configurationRequest =
      Rxn<ConfigurationRequestView>();
  final Rxn<ConfigurationReview> configurationReview =
      Rxn<ConfigurationReview>();
  final Rxn<ConfigurationOutcome> configurationOutcome =
      Rxn<ConfigurationOutcome>();
  final RxBool isCreatingConfigurationRequest = false.obs;
  final RxBool isInspectingConfigurationUpdate = false.obs;
  final RxBool isApplyingConfigurationUpdate = false.obs;
  final RxString configurationError = ''.obs;
  final Rxn<RewardsBalanceView> rewardsBalance = Rxn<RewardsBalanceView>();
  final RxBool isRefreshingBalance = false.obs;
  final RxBool isBalanceStale = false.obs;
  final RxString balanceError = ''.obs;

  Future<void> refreshRewardsBalance() async {
    if (isRefreshingBalance.value) return;
    isRefreshingBalance.value = true;
    balanceError.value = '';
    try {
      rewardsBalance.value = await _walletSdk.getRewardsBalance();
      isBalanceStale.value = false;
    } on WalletSdkException catch (error) {
      if (error.code == WalletSdkFailureCode.rewardsIdentityUnavailable) {
        rewardsBalance.value = null;
      }
      balanceError.value = employeeFacingText(error.safeMessage);
      isBalanceStale.value = rewardsBalance.value != null;
    } catch (_) {
      balanceError.value = 'We could not refresh your Wellness Points balance.';
      isBalanceStale.value = rewardsBalance.value != null;
    } finally {
      isRefreshingBalance.value = false;
    }
  }

  String get builderName => builderNameController.text.trim();

  String get phoneNumber => phoneController.text.trim();

  @override
  void onReady() {
    super.onReady();
    _restoreActivationRequest();
  }

  Future<void> _restoreActivationRequest() async {
    if (Get.currentRoute != Routes.wallet || isPreparingActivation.value) {
      return;
    }
    try {
      await refreshAccessState();
      if (accessState.value == RewardsAccessState.removed) {
        Get.offAllNamed(Routes.walletLocked);
        return;
      }
      WalletActivationStatus status = await _walletSdk.getActivationStatus();
      if (status.state == WalletActivationState.pending ||
          status.state == WalletActivationState.uncertain) {
        status = await _walletSdk.reconcileActivation();
      }
      activationStatus.value = status;
      if (status.state == WalletActivationState.active) {
        Get.offAllNamed(Routes.walletOverview);
        return;
      }
      final ActivationRequestView? restored = await _walletSdk
          .restoreActivationRequest();
      if (restored == null || Get.currentRoute != Routes.wallet) {
        return;
      }
      activationRequest.value = restored;
      builderNameController.text = restored.builder.displayName;
      phoneController.text = restored.builder.phone;
      Get.toNamed(Routes.walletActivation);
    } catch (_) {
      // Restoration failures leave the user on the safe not-activated screen.
    }
  }

  Future<void> startActivation() async {
    if (isPreparingActivation.value) {
      return;
    }

    final String name = builderName;
    final String phone = phoneNumber;
    final String? validationMessage = _validateIdentity(name, phone);
    if (validationMessage != null) {
      activationError.value = validationMessage;
      return;
    }

    activationError.value = '';
    isPreparingActivation.value = true;
    try {
      activationRequest.value = await _walletSdk.startActivation(
        BuilderIdentity(displayName: name, phone: phone),
      );
      Get.toNamed(Routes.walletActivation);
    } on WalletSdkException catch (error) {
      activationError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      activationError.value =
          "We couldn't prepare your activation request. Try again.";
    } finally {
      isPreparingActivation.value = false;
    }
  }

  Future<void> cancelActivation() async {
    if (isCancellingActivation.value) {
      return;
    }

    activationCancellationError.value = '';
    isCancellingActivation.value = true;
    try {
      await _walletSdk.cancelActivation();
      activationRequest.value = null;
      builderNameController.clear();
      phoneController.clear();
      Get.offAllNamed(Routes.wallet);
    } on WalletSdkException catch (error) {
      activationCancellationError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      activationCancellationError.value =
          "We couldn't cancel this activation. Try again.";
    } finally {
      isCancellingActivation.value = false;
    }
  }

  String? _validateIdentity(String name, String phone) {
    if (name.isEmpty || phone.isEmpty) {
      return 'Enter your Employee name and phone number.';
    }
    if (!phone.startsWith('+') || phone.length < 8) {
      return 'Enter a phone number with its country code.';
    }
    return null;
  }

  void openActivationScanner() {
    activationResponseError.value = '';
    Get.toNamed(Routes.walletActivationScan);
  }

  Future<void> importActivationResponse() async {
    if (isInspectingActivationResponse.value) return;
    final QrInputResult result = await qrInputAdapter.importFromGallery();
    if (result.isSuccess) {
      await inspectActivationResponse(result.value!);
    } else if (result.failure != QrInputFailure.cancelled) {
      activationResponseError.value =
          "We couldn't read an activation QR from that image.";
    }
  }

  Future<void> inspectActivationResponse(String value) async {
    if (isInspectingActivationResponse.value) return;
    isInspectingActivationResponse.value = true;
    activationResponseError.value = '';
    try {
      activationReview.value = await _walletSdk.inspectActivationResponse(
        value,
      );
      Get.offNamed(Routes.walletActivationReview);
    } on WalletSdkException catch (error) {
      activationResponseError.value = employeeFacingText(error.safeMessage);
      if (Get.currentRoute == Routes.walletActivationScan) Get.back<void>();
    } finally {
      isInspectingActivationResponse.value = false;
    }
  }

  Future<void> approveActivation() async {
    final ActivationReview? review = activationReview.value;
    if (review == null || isApprovingActivation.value) return;
    isApprovingActivation.value = true;
    activationResponseError.value = '';
    try {
      activationOutcome.value = await _walletSdk.approveActivation(
        review.responseId,
      );
      if (activationOutcome.value!.state != ActivationOutcomeState.rejected) {
        final WalletActivationStatus status = await _walletSdk
            .reconcileActivation();
        activationStatus.value = status;
        if (status.state == WalletActivationState.active) {
          Get.offAllNamed(Routes.walletOverview);
        } else {
          activationOutcome.value = ActivationOutcome(
            responseId: review.responseId,
            state: status.state == WalletActivationState.failed
                ? ActivationOutcomeState.rejected
                : ActivationOutcomeState.uncertain,
            message: status.message,
          );
        }
      }
    } on WalletSdkException catch (error) {
      activationResponseError.value = employeeFacingText(error.safeMessage);
    } finally {
      isApprovingActivation.value = false;
    }
  }

  void completeQrActivation() => Get.offAllNamed(Routes.walletOverview);

  void openWalletOverview() => Get.offAllNamed(Routes.walletOverview);

  void openAppMaster() => Get.offAllNamed(Routes.appMaster);

  final Rxn<RewardsReceiveView> receiveIdentity = Rxn<RewardsReceiveView>();
  final RxBool isLoadingReceive = false.obs;
  final RxString receiveError = ''.obs;

  void openReceive() {
    Get.toNamed(Routes.walletReceive);
    loadReceiveIdentity();
  }

  Future<void> loadReceiveIdentity() async {
    if (isLoadingReceive.value) return;
    isLoadingReceive.value = true;
    receiveIdentity.value = null;
    receiveError.value = '';
    try {
      receiveIdentity.value = await _walletSdk.getRewardsReceiveIdentity();
    } on WalletSdkException catch (error) {
      receiveError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      receiveError.value =
          'Your Wellness Points receiving details are unavailable.';
    } finally {
      isLoadingReceive.value = false;
    }
  }

  void openSend() {
    clearRecipientObservation();
    recipientController.clear();
    Get.toNamed(Routes.walletSendScan);
  }

  final RxList<RewardsHistoryItem> historyItems = <RewardsHistoryItem>[].obs;
  final Rxn<RewardsHistoryPage> historyPage = Rxn<RewardsHistoryPage>();
  final RxBool isLoadingHistory = false.obs;
  final RxBool isHistoryStale = false.obs;
  final RxString historyError = ''.obs;

  void openHistory() => Get.toNamed(Routes.walletHistory);

  Future<void> loadRewardsHistory({bool more = false}) async {
    if (isLoadingHistory.value ||
        (more && historyPage.value?.nextCursor == null)) {
      return;
    }
    isLoadingHistory.value = true;
    historyError.value = '';
    final RewardsHistoryPage? previous = historyPage.value;
    try {
      final RewardsHistoryPage page = await _walletSdk.getRewardsHistory(
        cursor: more ? previous?.nextCursor : null,
      );
      if (more &&
          previous != null &&
          (page.publicAccount != previous.publicAccount ||
              page.environment != previous.environment ||
              page.assetCode != previous.assetCode)) {
        historyItems.clear();
        historyPage.value = null;
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsIdentityUnavailable,
          safeMessage: 'Your Wellness Points details changed. Refresh history.',
          canRetry: true,
        );
      }
      if (!more) historyItems.clear();
      final Set<String> ids = historyItems
          .map((RewardsHistoryItem item) => item.id)
          .toSet();
      historyItems.addAll(
        page.items.where((RewardsHistoryItem item) => ids.add(item.id)),
      );
      historyPage.value = page;
      isHistoryStale.value = false;
    } on WalletSdkException catch (error) {
      if (error.code == WalletSdkFailureCode.rewardsIdentityUnavailable) {
        historyItems.clear();
        historyPage.value = null;
      }
      historyError.value = employeeFacingText(error.safeMessage);
      isHistoryStale.value = historyPage.value != null;
    } catch (_) {
      historyError.value = 'We could not load Wellness Points history.';
      isHistoryStale.value = historyPage.value != null;
    } finally {
      isLoadingHistory.value = false;
    }
  }

  Future<void> openConfigurationRequest() async {
    if (isCreatingConfigurationRequest.value) return;
    configurationError.value = '';
    configurationReview.value = null;
    configurationOutcome.value = null;
    isCreatingConfigurationRequest.value = true;
    try {
      configurationRequest.value = await _walletSdk
          .createConfigurationRequest();
      Get.toNamed(Routes.walletConfigurationRequest);
    } on WalletSdkException catch (error) {
      configurationError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      configurationError.value =
          "We couldn't create a configuration request. Try again.";
    } finally {
      isCreatingConfigurationRequest.value = false;
    }
  }

  void openConfigurationScanner() {
    configurationError.value = '';
    Get.toNamed(Routes.walletConfigurationScan);
  }

  Future<void> importConfigurationUpdate() async {
    if (isInspectingConfigurationUpdate.value) return;
    final QrInputResult result = await qrInputAdapter.importFromGallery();
    if (result.isSuccess) {
      await inspectConfigurationUpdate(result.value!);
    } else if (result.failure != QrInputFailure.cancelled) {
      configurationError.value = switch (result.failure!) {
        QrInputFailure.permissionDenied =>
          'Photo access was denied. Scan the update QR instead.',
        QrInputFailure.unreadable =>
          "We couldn't find a readable configuration QR in that image.",
        QrInputFailure.multipleCodes =>
          'Use an image containing only one configuration QR.',
        QrInputFailure.cancelled => '',
      };
    }
  }

  Future<void> inspectConfigurationUpdate(String value) async {
    if (isInspectingConfigurationUpdate.value) return;
    configurationError.value = '';
    isInspectingConfigurationUpdate.value = true;
    try {
      configurationReview.value = await _walletSdk.inspectConfigurationUpdate(
        value,
      );
      Get.offNamed(Routes.walletConfigurationReview);
    } on WalletSdkException catch (error) {
      configurationError.value = employeeFacingText(error.safeMessage);
      if (Get.currentRoute == Routes.walletConfigurationScan) Get.back<void>();
    } catch (_) {
      configurationError.value =
          "We couldn't verify this configuration update. Try again.";
      if (Get.currentRoute == Routes.walletConfigurationScan) Get.back<void>();
    } finally {
      isInspectingConfigurationUpdate.value = false;
    }
  }

  Future<void> applyConfigurationUpdate() async {
    final ConfigurationReview? review = configurationReview.value;
    if (review == null || isApplyingConfigurationUpdate.value) return;
    configurationError.value = '';
    isApplyingConfigurationUpdate.value = true;
    try {
      configurationOutcome.value = await _walletSdk.applyConfigurationUpdate(
        review.updateId,
      );
      Get.offNamed(Routes.walletConfigurationOutcome);
    } on WalletSdkException catch (error) {
      configurationError.value = employeeFacingText(error.safeMessage);
    } catch (_) {
      configurationError.value =
          "We couldn't apply this configuration update. Try again.";
    } finally {
      isApplyingConfigurationUpdate.value = false;
    }
  }

  void finishConfigurationUpdate() => Get.offAllNamed(Routes.walletOverview);

  Future<void> openLocked() async {
    await _walletSdk.lockRewards();
    transferReview.value = null;
    authorizationMessage.value = '';
    await refreshAccessState();
    Get.toNamed(Routes.walletLocked);
  }

  void openRemoveWallet() => Get.toNamed(Routes.walletRemove);

  void requestAuthentication({
    required String purpose,
    required String nextRoute,
  }) {
    Get.toNamed(
      Routes.walletAuthentication,
      arguments: <String, String>{'purpose': purpose, 'nextRoute': nextRoute},
    );
  }

  void completeAuthentication() {
    unlockRewards();
  }

  @override
  void onClose() {
    _walletSdk.lockRewards();
    recipientController.dispose();
    builderNameController.dispose();
    phoneController.dispose();
    amountController.dispose();
    super.onClose();
  }
}
