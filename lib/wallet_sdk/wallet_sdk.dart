library;

export 'rewards_recovery_page.dart' show RewardsRecoveryPage;

export 'app_master_roster.dart';
import 'app_master_roster.dart';

import 'package:employee_wellness/wallet_sdk/src/default_wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';

WalletSdk createWalletSdk({
  String Function(String)? authenticationMessageMapper,
}) => DefaultWalletSdk(
  transferAuthenticator: NativeTransferAuthenticator(
    messageMapper: authenticationMessageMapper,
  ),
);

final class BuilderIdentity {
  const BuilderIdentity({required this.displayName, required this.phone});

  final String displayName;
  final String phone;
}

final class ActivationRequestView {
  const ActivationRequestView({
    required this.requestId,
    required this.qrValue,
    required this.expiresAt,
    required this.builder,
  });

  final String requestId;
  final String qrValue;
  final DateTime expiresAt;
  final BuilderIdentity builder;
}

final class ActivationRequestReview {
  const ActivationRequestReview({
    required this.requestId,
    required this.builder,
    required this.expiresAt,
    required this.setupSteps,
  });

  final String requestId;
  final BuilderIdentity builder;
  final DateTime expiresAt;
  final List<String> setupSteps;
}

final class ActivationResponseView {
  const ActivationResponseView({
    required this.responseId,
    required this.requestId,
    required this.qrValue,
    required this.expiresAt,
  });

  final String responseId;
  final String requestId;
  final String qrValue;
  final DateTime expiresAt;
}

final class ActivationReview {
  const ActivationReview({
    required this.responseId,
    required this.requestId,
    required this.expiresAt,
    required this.preparedBy,
    required this.setupSteps,
  });

  final String responseId;
  final String requestId;
  final DateTime expiresAt;
  final String preparedBy;
  final List<String> setupSteps;
}

enum ActivationOutcomeState { submitted, rejected, uncertain }

final class ActivationOutcome {
  const ActivationOutcome({
    required this.responseId,
    required this.state,
    required this.message,
  });

  final String responseId;
  final ActivationOutcomeState state;
  final String message;
}

enum WalletActivationState { notActivated, pending, active, failed, uncertain }

final class WalletActivationStatus {
  const WalletActivationStatus({required this.state, required this.message});

  const WalletActivationStatus.notActivated()
    : state = WalletActivationState.notActivated,
      message = 'Rewards is not activated.';

  final WalletActivationState state;
  final String message;
}

enum ProviderEnvironment { test, production }

enum RewardsAccessState { locked, unlocked, removed }

enum ProviderConfigurationState { notConfigured, pendingVerification, ready }

enum DistributorAuthorityState { notConfigured, ready }

final class DistributorAuthorityStatus {
  const DistributorAuthorityStatus({
    required this.state,
    this.maskedAccountId,
    this.environment,
    this.verifiedAt,
  });

  const DistributorAuthorityStatus.notConfigured()
    : state = DistributorAuthorityState.notConfigured,
      maskedAccountId = null,
      environment = null,
      verifiedAt = null;

  final DistributorAuthorityState state;
  final String? maskedAccountId;
  final ProviderEnvironment? environment;
  final DateTime? verifiedAt;
}

final class AppMasterOverview {
  const AppMasterOverview({
    required this.activationCapacity,
    required this.rewardsAvailable,
    required this.serviceStatus,
    required this.updatedAt,
  });

  final int activationCapacity;
  final String rewardsAvailable;
  final String serviceStatus;
  final DateTime updatedAt;
}

final class ProviderConfigurationInput {
  const ProviderConfigurationInput({
    required this.endpoint,
    required this.apiKey,
    required this.environment,
    required this.version,
    this.activationFunding = '2.1',
    this.initialRewards = '1',
  });

  final String endpoint;
  final String apiKey;
  final ProviderEnvironment environment;
  final int version;
  final String activationFunding;
  final String initialRewards;
}

final class ProviderConfigurationOutcome {
  const ProviderConfigurationOutcome({required this.status});

  final ProviderConfigurationStatus status;
}

final class ConfigurationRequestView {
  const ConfigurationRequestView({
    required this.requestId,
    required this.qrValue,
    required this.expiresAt,
  });

  final String requestId;
  final String qrValue;
  final DateTime expiresAt;
}

final class ConfigurationRequestReview {
  const ConfigurationRequestReview({
    required this.requestId,
    required this.currentVersion,
    required this.environment,
    required this.expiresAt,
  });

  final String requestId;
  final int currentVersion;
  final ProviderEnvironment environment;
  final DateTime expiresAt;
}

final class ConfigurationUpdateView {
  const ConfigurationUpdateView({
    required this.updateId,
    required this.requestId,
    required this.qrValue,
    required this.expiresAt,
  });

  final String updateId;
  final String requestId;
  final String qrValue;
  final DateTime expiresAt;
}

final class ConfigurationReview {
  const ConfigurationReview({
    required this.updateId,
    required this.version,
    required this.environment,
    required this.endpointHost,
    required this.expiresAt,
  });

  final String updateId;
  final int version;
  final ProviderEnvironment environment;
  final String endpointHost;
  final DateTime expiresAt;
}

final class ConfigurationOutcome {
  const ConfigurationOutcome({required this.status});

  final ProviderConfigurationStatus status;
}

final class ProviderConfigurationStatus {
  const ProviderConfigurationStatus({
    required this.state,
    this.environment,
    this.version,
    this.endpointHost,
    this.lastCheckedAt,
    this.activationFunding = '2.1',
    this.initialRewards = '1',
  });

  const ProviderConfigurationStatus.notConfigured()
    : state = ProviderConfigurationState.notConfigured,
      environment = null,
      version = null,
      endpointHost = null,
      lastCheckedAt = null,
      activationFunding = '2.1',
      initialRewards = '1';

  final ProviderConfigurationState state;
  final ProviderEnvironment? environment;
  final int? version;
  final String? endpointHost;
  final DateTime? lastCheckedAt;
  final String activationFunding;
  final String initialRewards;
}

enum WalletSdkFailureCode {
  rosterNotConfigured,
  rosterAccessDenied,
  rosterUnavailable,
  rewardsAccessRemoved,
  rewardsAccessUnavailable,
  rewardsSendUnavailable,
  rewardsTransferPending,
  rewardsAuthorizationUnavailable,
  rewardsAuthorizationDenied,
  invalidRewardsTransferReview,
  invalidRewardsAmount,
  insufficientRewardsFunds,
  insufficientRewardsFeeFunds,
  rewardsTransferPreparationUnavailable,
  invalidRewardsRecipient,
  rewardsRecipientUnavailable,
  rewardsIdentityUnavailable,
  rewardsBalanceUnavailable,
  rewardsHistoryUnavailable,
  invalidRewardsHistoryCursor,
  invalidBuilder,
  secureSetupFailed,
  requestCreationFailed,
  cancellationFailed,
  invalidProviderConfiguration,
  providerConfigurationSaveFailed,
  providerUnauthorized,
  providerRateLimited,
  providerServiceUnavailable,
  providerNetworkMismatch,
  providerInvalidResponse,
  providerTimeout,
  unavailable,
  invalidActivationRequest,
  activationRequestExpired,
  activationRequestAlreadyUsed,
  invalidDistributorSecret,
  distributorAccountUnavailable,
  distributorAuthoritySaveFailed,
  providerConfigurationRequired,
  activationApprovalFailed,
  activationPolicyUnavailable,
  invalidActivationResponse,
  activationResponseExpired,
  activationSubmissionFailed,
  invalidConfigurationRequest,
  invalidConfigurationUpdate,
  configurationUpdateExpired,
  configurationUpdateAlreadyUsed,
}

final class WalletSdkException implements Exception {
  const WalletSdkException({
    required this.code,
    required this.safeMessage,
    required this.canRetry,
  });

  final WalletSdkFailureCode code;
  final String safeMessage;
  final bool canRetry;
}

abstract interface class WalletSdk {
  Future<AppMasterRosterPage> getAppMasterRoster({
    String? cursor,
    int limit = 20,
  });
  Future<RewardsAccessState> getRewardsAccessState();
  Future<void> lockRewards();
  Future<void> unlockRewards();
  Future<void> removeRewardsAccess();
  Future<String> createRewardsBackup(String password);
  Future<void> confirmRewardsBackup(String backup, String password);
  Future<void> restoreRewardsBackup(String backup, String password);
  Future<void> eraseRewardsFromDevice();
  Future<RewardsTransferOutcome?> resolvePendingRewardsTransfer({
    String? competingTransactionHash,
  });
  Future<RewardsTransferOutcome> approveRewardsTransfer(String reviewId);
  Future<RewardsTransferOutcome?> getRewardsTransferStatus({
    bool reconcile = false,
  });
  Future<RewardsTransferAuthorization> authorizeRewardsTransfer(
    String reviewId,
  );
  Future<void> cancelRewardsTransferAuthorization();
  Future<RewardsTransferReview> getPreparedRewardsTransfer(String reviewId);
  Future<RewardsTransferReview> prepareRewardsTransfer({
    required String publicAccount,
    required String amount,
  });
  Future<RewardsRecipientView> inspectRewardsRecipient(String publicAccount);
  Future<RewardsHistoryPage> getRewardsHistory({
    String? cursor,
    int limit = 20,
  });
  Future<RewardsBalanceView> getRewardsBalance();
  Future<RewardsReceiveView> getRewardsReceiveIdentity();
  Future<ActivationRequestView> startActivation(BuilderIdentity builder);

  Future<ActivationRequestView?> restoreActivationRequest();

  Future<void> cancelActivation();

  Future<ActivationRequestReview> inspectBuilderRequest(String qrValue);

  Future<ActivationRequestReview?> restoreInspectedBuilderRequest();

  Future<ActivationResponseView> approveBuilderRequest(String requestId);

  Future<ActivationReview> inspectActivationResponse(String qrValue);

  Future<ActivationOutcome> approveActivation(String responseId);

  Future<WalletActivationStatus> reconcileActivation();

  Future<WalletActivationStatus> getActivationStatus();

  Future<ConfigurationRequestView> createConfigurationRequest();

  Future<ConfigurationRequestReview> inspectConfigurationRequest(
    String qrValue,
  );

  Future<ConfigurationUpdateView> createConfigurationUpdate(String requestId);

  Future<ConfigurationReview> inspectConfigurationUpdate(String qrValue);

  Future<ConfigurationOutcome> applyConfigurationUpdate(String updateId);

  Future<DistributorAuthorityStatus> importDistributorSecret(String secret);

  Future<DistributorAuthorityStatus> getDistributorAuthorityStatus();

  Future<void> removeDistributorAuthority();

  Future<AppMasterOverview> getAppMasterOverview();

  Future<ProviderConfigurationOutcome> saveAppMasterProviderConfiguration(
    ProviderConfigurationInput input,
  );

  Future<ProviderConfigurationStatus> getProviderConfigurationStatus();
}

/// Informational only; this object cannot be used as signing evidence.
enum RewardsTransferState { confirmed, failed, cancelled, uncertain }

final class RewardsTransferOutcome {
  const RewardsTransferOutcome({
    required this.reviewId,
    required this.transactionHash,
    required this.publicAccount,
    required this.assetCode,
    required this.amount,
    required this.state,
    this.resolution,
  });
  final String reviewId, transactionHash, publicAccount, assetCode, amount;
  final RewardsTransferState state;
  final String? resolution;
}

/// Informational only; this object cannot be used as signing evidence.
final class RewardsTransferAuthorization {
  const RewardsTransferAuthorization({
    required this.reviewId,
    required this.expiresAt,
  });
  final String reviewId;
  final DateTime expiresAt;
}

/// An immutable preparation. It does not sign, authorize, or submit a payment.
final class RewardsTransferReview {
  const RewardsTransferReview({
    required this.reviewId,
    required this.publicAccount,
    required this.environment,
    required this.assetCode,
    required this.assetIssuer,
    required this.amount,
    required this.maximumFee,
    required this.expiresAt,
  });
  final String reviewId;
  final String publicAccount;
  final ProviderEnvironment environment;
  final String assetCode;
  final String assetIssuer;
  final String amount;

  /// Maximum native XLM fee bid for a single direct payment operation.
  final String maximumFee;
  final DateTime expiresAt;
}

/// A read-only observation, not authorization or a prepared transaction.
final class RewardsRecipientView {
  const RewardsRecipientView({
    required this.publicAccount,
    required this.environment,
    required this.assetCode,
    required this.receivingCapacity,
    required this.observedAt,
  });
  final String publicAccount;
  final ProviderEnvironment environment;
  final String assetCode;
  final String receivingCapacity;
  final DateTime observedAt;
}

final class RewardsReceiveView {
  const RewardsReceiveView({
    required this.publicAccount,
    required this.qrValue,
    required this.environment,
    required this.assetCode,
  });

  final String publicAccount;
  final String qrValue;
  final ProviderEnvironment environment;
  final String assetCode;
}

final class RewardsBalanceView {
  const RewardsBalanceView({
    required this.publicAccount,
    required this.environment,
    required this.assetCode,
    required this.total,
    required this.available,
    required this.observedAt,
  });
  final String publicAccount;
  final ProviderEnvironment environment;
  final String assetCode;
  final String total;
  final String available;
  final DateTime observedAt;
}

enum RewardsHistoryDirection { received, sent, self }

final class RewardsHistoryItem {
  const RewardsHistoryItem({
    required this.id,
    required this.direction,
    required this.amount,
    required this.counterparty,
    required this.createdAt,
  });
  final String id;
  final RewardsHistoryDirection direction;
  final String amount;
  final String counterparty;
  final DateTime createdAt;
}

final class RewardsHistoryPage {
  RewardsHistoryPage({
    required this.publicAccount,
    required this.environment,
    required this.assetCode,
    required List<RewardsHistoryItem> items,
    required this.observedAt,
    this.nextCursor,
  }) : items = List<RewardsHistoryItem>.unmodifiable(items);
  final String publicAccount;
  final ProviderEnvironment environment;
  final String assetCode;
  final List<RewardsHistoryItem> items;
  final DateTime observedAt;
  final String? nextCursor;
}
