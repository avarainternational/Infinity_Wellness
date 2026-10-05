import 'dart:math';
import 'package:employee_wellness/wallet_sdk/src/recovery/rewards_recovery_service.dart';
import 'package:employee_wellness/wallet_sdk/src/roster/app_master_roster_service.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/rewards_access_service.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_send_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transfers/rewards_send_service.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/rewards_amount.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_transfer_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_recipient_client.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';

import 'package:cryptography/cryptography.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_history_client.dart';
import 'package:employee_wellness/wallet_sdk/src/activation/active_rewards_migration_service.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_balance_client.dart';
import 'package:employee_wellness/wallet_sdk/src/activation/activation_finalization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:employee_wellness/wallet_sdk/src/activation/activation_token_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/activation/activation_response_service.dart';
import 'package:employee_wellness/wallet_sdk/src/authority/distributor_authority_service.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/configuration_policy.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/configuration_handshake_service.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/device_configuration_identity.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/qr/activation_qr_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/stellar_activation_protocol.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_submission_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_inspection_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/configuration_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/configuration_handshake_store.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_health_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/distributor_status_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/activation_submission_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/activation_reconciliation_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

final class DefaultWalletSdk implements WalletSdk {
  factory DefaultWalletSdk({
    FlutterSecureStorage? secureStorage,
    DateTime Function()? now,
    Random? random,
    WalletKeyGenerator? keyGenerator,
    ActivationQrCodec? qrCodec,
    ActivationStore? activationStore,
    CredentialStore? credentialStore,
    WalletClock? clock,
    ActivationTokenGenerator? tokenGenerator,
    ConfigurationPolicy configurationPolicy = const ConfigurationPolicy(),
    ConfigurationStore? configurationStore,
    HorizonHealthClient? horizonHealthClient,
    DeviceConfigurationIdentityService? deviceIdentityService,
    ActivationInspectionStore? activationInspectionStore,
    DistributorAuthorityService? distributorAuthorityService,
    DistributorStatusClient? distributorStatusClient,
    ActivationResponseService? activationResponseService,
    ActivationSubmissionStore? activationSubmissionStore,
    ActivationSubmissionClient? activationSubmissionClient,
    ActivationReconciliationClient? activationReconciliationClient,
    StellarActivationProtocol? stellarProtocol,
    ConfigurationHandshakeService? configurationHandshakeService,
    ConfigurationHandshakeStore? configurationHandshakeStore,
    HorizonHttpClient? horizonHttpClient,
    ActiveRewardsStore? activeRewardsStore,
    RewardsBalanceClient? rewardsBalanceClient,
    RewardsHistoryClient? rewardsHistoryClient,
    RewardsRecipientClient? rewardsRecipientClient,
    RewardsTransferClient? rewardsTransferClient,
    TransferAuthenticator? transferAuthenticator,
    RewardsSendStore? rewardsSendStore,
    RewardsSendClient? rewardsSendClient,
  }) => DefaultWalletSdk._(
    secureStorage: secureStorage,
    now: now,
    random: random,
    keyGenerator: keyGenerator,
    qrCodec: qrCodec,
    activationStore: activationStore,
    credentialStore: credentialStore,
    clock: clock,
    tokenGenerator: tokenGenerator,
    configurationPolicy: configurationPolicy,
    configurationStore: configurationStore,
    horizonHealthClient: horizonHealthClient,
    deviceIdentityService: deviceIdentityService,
    activationInspectionStore: activationInspectionStore,
    distributorAuthorityService: distributorAuthorityService,
    distributorStatusClient: distributorStatusClient,
    activationResponseService: activationResponseService,
    activationSubmissionStore: activationSubmissionStore,
    activationSubmissionClient: activationSubmissionClient,
    activationReconciliationClient: activationReconciliationClient,
    stellarProtocol: stellarProtocol,
    configurationHandshakeService: configurationHandshakeService,
    configurationHandshakeStore: configurationHandshakeStore,
    horizonHttpClient: horizonHttpClient ?? HorizonHttpClient(),
    activeRewardsStore: activeRewardsStore,
    rewardsBalanceClient: rewardsBalanceClient,
    rewardsHistoryClient: rewardsHistoryClient,
    rewardsRecipientClient: rewardsRecipientClient,
    rewardsTransferClient: rewardsTransferClient,
    transferAuthenticator: transferAuthenticator,
    rewardsSendStore: rewardsSendStore,
    rewardsSendClient: rewardsSendClient,
  );

  DefaultWalletSdk._({
    FlutterSecureStorage? secureStorage,
    DateTime Function()? now,
    Random? random,
    WalletKeyGenerator? keyGenerator,
    ActivationQrCodec? qrCodec,
    ActivationStore? activationStore,
    CredentialStore? credentialStore,
    WalletClock? clock,
    ActivationTokenGenerator? tokenGenerator,
    ConfigurationPolicy configurationPolicy = const ConfigurationPolicy(),
    ConfigurationStore? configurationStore,
    HorizonHealthClient? horizonHealthClient,
    DeviceConfigurationIdentityService? deviceIdentityService,
    ActivationInspectionStore? activationInspectionStore,
    DistributorAuthorityService? distributorAuthorityService,
    DistributorStatusClient? distributorStatusClient,
    ActivationResponseService? activationResponseService,
    ActivationSubmissionStore? activationSubmissionStore,
    ActivationSubmissionClient? activationSubmissionClient,
    ActivationReconciliationClient? activationReconciliationClient,
    StellarActivationProtocol? stellarProtocol,
    ConfigurationHandshakeService? configurationHandshakeService,
    ConfigurationHandshakeStore? configurationHandshakeStore,
    required HorizonHttpClient horizonHttpClient,
    ActiveRewardsStore? activeRewardsStore,
    RewardsBalanceClient? rewardsBalanceClient,
    RewardsHistoryClient? rewardsHistoryClient,
    RewardsRecipientClient? rewardsRecipientClient,
    RewardsTransferClient? rewardsTransferClient,
    TransferAuthenticator? transferAuthenticator,
    RewardsSendStore? rewardsSendStore,
    RewardsSendClient? rewardsSendClient,
  }) : _rosterService = AppMasterRosterService(horizonHttpClient),
       _rewardsSendStore =
           rewardsSendStore ??
           ProtectedRewardsSendStore(secureStorage: secureStorage),
       _rewardsSendClient =
           rewardsSendClient ??
           DirectRewardsSendClient(transport: horizonHttpClient),
       _transferAuthenticator =
           transferAuthenticator ?? NativeTransferAuthenticator(),
       _rewardsTransferClient =
           rewardsTransferClient ??
           DirectRewardsTransferClient(transport: horizonHttpClient),
       _rewardsRecipientClient =
           rewardsRecipientClient ??
           DirectRewardsRecipientClient(transport: horizonHttpClient),
       _rewardsHistoryClient =
           rewardsHistoryClient ??
           DirectRewardsHistoryClient(transport: horizonHttpClient),
       _rewardsBalanceClient =
           rewardsBalanceClient ??
           DirectRewardsBalanceClient(transport: horizonHttpClient),
       _activeRewardsStore =
           activeRewardsStore ??
           ProtectedActiveRewardsStore(secureStorage: secureStorage),
       _activationStore = activationStore ?? PreferencesActivationStore(),
       _credentialStore =
           credentialStore ?? SecureCredentialStore(storage: secureStorage),
       _clock =
           clock ??
           (now == null ? const SystemWalletClock() : CallbackWalletClock(now)),
       _tokenGenerator =
           tokenGenerator ?? ActivationTokenGenerator(random: random),
       _keyGenerator = keyGenerator ?? WalletKeyGenerator(random: random),
       _qrCodec = qrCodec ?? ActivationQrCodec(),
       _deviceIdentityService =
           deviceIdentityService ??
           DeviceConfigurationIdentityService(
             credentialStore:
                 credentialStore ??
                 SecureCredentialStore(storage: secureStorage),
             random: random,
           ),
       _configurationPolicy = configurationPolicy,
       _configurationStore =
           configurationStore ??
           ProtectedConfigurationStore(secureStorage: secureStorage),
       _horizonHealthClient =
           horizonHealthClient ??
           DirectHorizonHealthClient(transport: horizonHttpClient),
       _activationInspectionStore =
           activationInspectionStore ??
           ProtectedActivationInspectionStore(secureStorage: secureStorage),
       _distributorAuthorityService =
           distributorAuthorityService ??
           DistributorAuthorityService(
             store: ProtectedDistributorAuthorityStore(
               secureStorage: secureStorage,
             ),
             verifier: HorizonDistributorAccountVerifier(
               transport: horizonHttpClient,
             ),
           ),
       _distributorStatusClient =
           distributorStatusClient ??
           DirectDistributorStatusClient(transport: horizonHttpClient),
       _activationResponseService =
           activationResponseService ??
           ActivationResponseService(random: random),
       _activationSubmissionStore =
           activationSubmissionStore ?? PreferencesActivationSubmissionStore(),
       _activationSubmissionClient =
           activationSubmissionClient ??
           DirectActivationSubmissionClient(transport: horizonHttpClient),
       _activationReconciliationClient =
           activationReconciliationClient ??
           DirectActivationReconciliationClient(transport: horizonHttpClient),
       _stellarProtocol = stellarProtocol ?? StellarActivationProtocol(),
       _configurationHandshakeService =
           configurationHandshakeService ??
           ConfigurationHandshakeService(random: random),
       _configurationHandshakeStore =
           configurationHandshakeStore ??
           ConfigurationHandshakeStore(secureStorage: secureStorage);

  static const String _credentialKeyPrefix = 'rewards.activation.secret.';
  static const Duration _requestLifetime = Duration(minutes: 15);

  final RewardsBalanceClient _rewardsBalanceClient;
  final RewardsRecipientClient _rewardsRecipientClient;
  final RewardsTransferClient _rewardsTransferClient;
  final RewardsSendStore _rewardsSendStore;
  final RewardsSendClient _rewardsSendClient;
  final AppMasterRosterService _rosterService;

  @override
  Future<AppMasterRosterPage> getAppMasterRoster({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final config = await _configurationStore.readActive();
      final account = await _distributorAuthorityService.readAccountId();
      if (config == null || account == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rosterAccessDenied,
          safeMessage:
              'Complete authorized App Master setup before loading Builder access.',
          canRetry: false,
        );
      }
      final ledger = await _distributorStatusClient.load(
        configuration: config,
        accountId: account,
      );
      if (ledger.nonNativeAssets.length != 1) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.activationPolicyUnavailable,
          safeMessage: 'Rewards asset settings need review.',
          canRetry: false,
        );
      }
      final asset = ledger.nonNativeAssets.single;
      final page = await _rosterService.load(
        configuration: config,
        assetCode: asset.code,
        assetIssuer: asset.issuer,
        authorityAccount: account,
        limit: limit,
        cursor: cursor,
      );
      if ((await _configurationStore.readActive())?.encodeProtected() !=
              config.encodeProtected() ||
          await _distributorAuthorityService.readAccountId() != account) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rosterAccessDenied,
          safeMessage:
              'App Master settings changed. Authorize and refresh Builder access.',
          canRetry: false,
        );
      }
      return page;
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rosterUnavailable,
        safeMessage:
            'Builder access is unavailable. Refresh or contact your administrator.',
        canRetry: true,
      );
    }
  }

  late final RewardsSendService _sendService = RewardsSendService(
    store: _rewardsSendStore,
    credentials: _credentialStore,
    client: _rewardsSendClient,
    clock: _clock,
    protocol: _stellarProtocol,
  );
  static bool _approvingSend = false;
  static bool _authorizingAccess = false;
  late final RewardsAccessService _access = RewardsAccessService(
    store: _credentialStore,
    authenticator: _transferAuthenticator,
    clock: _clock,
    revokeTransfer: () {
      _preparedTransfer = null;
      _authorization.invalidate();
    },
  );

  @override
  Future<RewardsAccessState> getRewardsAccessState() => _access.status();

  @override
  Future<void> lockRewards() async {
    _access.lock();
    await _authorization.cancel();
  }

  @override
  Future<void> unlockRewards() async {
    if (_approvingSend || _authorizingAccess) throw _accessBusy();
    _authorizingAccess = true;
    try {
      final identity = await _activeRewardsStore.read();
      if (identity == null) throw _accessBusy();
      identity.validate();
      if (await _credentialStore.read(identity.credentialKey) == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsAccessRemoved,
          safeMessage: 'Restore Rewards from your backup to use this account.',
          canRetry: false,
        );
      }
      await lockRewards();
      await _access.unlock(identity.accountId);
    } finally {
      _authorizingAccess = false;
    }
  }

  @override
  Future<void> removeRewardsAccess() async {
    if (_approvingSend || _authorizingAccess || _preparingTransfer) {
      throw _accessBusy();
    }
    _authorizingAccess = true;
    try {
      final identity = await _requireActiveRewards();
      Future<void> validate() async {
        final saved = await getRewardsTransferStatus();
        if (saved?.state == RewardsTransferState.uncertain) {
          throw const WalletSdkException(
            code: WalletSdkFailureCode.rewardsTransferPending,
            safeMessage: 'Verify the pending transfer before removing access.',
            canRetry: true,
          );
        }
        if ((await _requireActiveRewards()).encode() != identity.encode()) {
          throw _accessBusy();
        }
      }

      await validate();
      await lockRewards();
      await _access.remove(identity.accountId, validate);
    } finally {
      _authorizingAccess = false;
    }
  }

  WalletSdkException _accessBusy() => const WalletSdkException(
    code: WalletSdkFailureCode.rewardsAccessUnavailable,
    safeMessage:
        'Rewards access is unavailable or another protected operation is in progress.',
    canRetry: true,
  );

  late final RewardsRecoveryService _recovery = RewardsRecoveryService(
    _credentialStore,
    _activeRewardsStore,
    _rewardsSendStore,
  );

  Future<T> _recoveryAction<T>(
    String reason,
    Future<T> Function(void Function()) action,
  ) async {
    if (_approvingSend || _authorizingAccess || _preparingTransfer) {
      throw _accessBusy();
    }
    _authorizingAccess = true;
    late T result;
    try {
      await lockRewards();
      await _access.protect(reason, (check) async {
        result = await action(check);
      });
      return result;
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsAccessUnavailable,
        safeMessage:
            'Recovery could not complete. Check your backup and password, and preserve the backup before trying again.',
        canRetry: true,
      );
    } finally {
      _authorizingAccess = false;
    }
  }

  @override
  Future<String> createRewardsBackup(String password) => _recoveryAction(
    'Authenticate to create your encrypted Rewards backup.',
    (check) async {
      final identity = await _requireActiveRewards();
      final backup = await _recovery.create(password);
      check();
      if ((await _requireActiveRewards()).encode() != identity.encode()) {
        throw _accessBusy();
      }
      check();
      return backup;
    },
  );

  @override
  Future<void> confirmRewardsBackup(String backup, String password) =>
      _recoveryAction<void>(
        'Authenticate to verify your saved Rewards backup.',
        (check) async {
          await _requireActiveRewards();
          check();
          await _recovery.confirm(backup.trim(), password);
          check();
        },
      );

  @override
  Future<void> restoreRewardsBackup(
    String backup,
    String password,
  ) => _recoveryAction<void>('Authenticate to restore Rewards on this device.', (
    check,
  ) async {
    final imported = await _recovery.decode(backup.trim(), password);
    final existing = await _activeRewardsStore.read();
    final activation = await _activationSubmissionStore.read();
    if (existing == null &&
        (await _activationStore.read() != null || activation != null)) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsAccessUnavailable,
        safeMessage:
            'Resolve or cancel this device’s activation before restoring another account.',
        canRetry: false,
      );
    }
    if (existing != null && existing.encode() != imported.identity.encode()) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsAccessUnavailable,
        safeMessage:
            'This device already holds a different Rewards account. Use its own backup or a clean installation.',
        canRetry: false,
      );
    }
    final saved = await _rewardsSendStore.read();
    if (saved != null &&
        (saved.source != imported.identity.accountId ||
            saved.environment != imported.identity.environment ||
            saved.code != imported.identity.assetCode ||
            saved.issuer != imported.identity.assetIssuer)) {
      throw _accessBusy();
    }
    if (saved != null &&
        imported.transfer != null &&
        imported.transfer!.isPending &&
        saved.hash != imported.transfer!.hash) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsTransferPending,
        safeMessage:
            'The backup contains a different unresolved transfer. Preserve both records and ask App Master for help, or restore on a clean installation.',
        canRetry: false,
      );
    }
    check();
    await _access.saveMarker('erased:${imported.identity.accountId}');
    await _credentialStore.write(
      key: imported.identity.credentialKey,
      value: imported.secret,
    );
    if (await _credentialStore.read(imported.identity.credentialKey) !=
        imported.secret) {
      throw _accessBusy();
    }
    await _activeRewardsStore.write(imported.identity);
    if ((await _activeRewardsStore.read())?.encode() !=
        imported.identity.encode()) {
      throw _accessBusy();
    }
    if (saved == null && imported.transfer != null) {
      await _rewardsSendStore.write(imported.transfer!);
    }
    final restoredActivation = ActivationSubmissionRecord(
      responseId: imported.identity.responseId,
      transactionHash: imported.identity.activationTransactionHash,
      status: ActivationSubmissionStatus.verified,
    );
    await _activationSubmissionStore.write(restoredActivation);
    if ((await _activationSubmissionStore.read())?.encode() !=
        restoredActivation.encode()) {
      throw _accessBusy();
    }
    check();
    await _access.saveMarker('active');
  });

  @override
  Future<void> eraseRewardsFromDevice() => _recoveryAction<void>(
    'Permanently remove Rewards credentials from this device. Your saved backup will be required to restore access.',
    (check) async {
      final identity = await _activeRewardsStore.read();
      if (identity == null) throw _accessBusy();
      identity.validate();
      final saved = await _rewardsSendStore.read();
      if (saved?.isPending ?? false) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsTransferPending,
          safeMessage:
              'Resolve the pending transfer before removing this device.',
          canRetry: true,
        );
      }
      if (await _credentialStore.read(RewardsRecoveryService.confirmationKey) !=
          await _recovery.confirmation(identity, saved)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsAccessUnavailable,
          safeMessage:
              'Create and verify a current backup before removing this device.',
          canRetry: false,
        );
      }
      check();
      await _access.saveMarker('erasing:${identity.accountId}');
      await _credentialStore.delete(identity.credentialKey);
      if (await _credentialStore.read(identity.credentialKey) != null) {
        throw _accessBusy();
      }
      await _access.saveMarker('erased:${identity.accountId}');
      // Keep only protected public identity/evidence for same-account restoration.
      // App Master credentials and service configuration are independent and untouched.
    },
  );

  @override
  Future<RewardsTransferOutcome?> getRewardsTransferStatus({
    bool reconcile = false,
  }) async {
    final identity = await _requireActiveRewards();
    final configuration = await _configurationStore.readActive();
    if (configuration == null ||
        configuration.environment != identity.environment) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsSendUnavailable,
        safeMessage:
            'Your Rewards service settings need attention from App Master.',
        canRetry: true,
      );
    }
    return _sendService.restore(identity, configuration, reconcile: reconcile);
  }

  @override
  Future<RewardsTransferOutcome> approveRewardsTransfer(String reviewId) async {
    if (_approvingSend || _authorizingAccess) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsSendUnavailable,
        safeMessage: 'A send is already in progress. Check its status.',
        canRetry: true,
      );
    }
    _approvingSend = true;
    try {
      final saved = await getRewardsTransferStatus();
      if (saved?.reviewId == reviewId) return saved!;
      if (saved?.state == RewardsTransferState.uncertain) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsTransferPending,
          safeMessage: 'Verify the previous transfer before sending again.',
          canRetry: true,
        );
      }
      final review = await getPreparedRewardsTransfer(reviewId);
      final prepared = _preparedTransfer!;
      await authorizeRewardsTransfer(reviewId);
      return await _sendService.send(
        review: review,
        identity: prepared.identity,
        configuration: prepared.configuration,
        sourceSequence: prepared.cost.sequence,
        revalidate: () => _revalidateTransfer(prepared),
        approvalValid: () =>
            _access.isUnlocked && _authorization.isValid(review),
        consumeApproval: () =>
            _access.isUnlocked && _authorization.consume(review),
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsSendUnavailable,
        safeMessage:
            'We could not safely send this transfer. Check its saved status.',
        canRetry: true,
      );
    } finally {
      _authorization.invalidate();
      _preparedTransfer = null;
      _approvingSend = false;
    }
  }

  @override
  Future<RewardsTransferOutcome?> resolvePendingRewardsTransfer({
    String? competingTransactionHash,
  }) async {
    if (_authorizingAccess || _approvingSend) throw _accessBusy();
    final identity = await _requireActiveRewards();
    final config = await _configurationStore.readActive();
    if (config == null || config.environment != identity.environment) {
      throw _accessBusy();
    }
    return _sendService.resolve(
      identity,
      config,
      competingHash: competingTransactionHash?.trim().toLowerCase(),
    );
  }

  final TransferAuthenticator _transferAuthenticator;
  late final TransferAuthorizationService _authorization =
      TransferAuthorizationService(
        authenticator: _transferAuthenticator,
        clock: _clock,
      );
  _PreparedTransfer? _preparedTransfer;
  static bool _preparingTransfer = false;

  @override
  Future<RewardsTransferReview> prepareRewardsTransfer({
    required String publicAccount,
    required String amount,
  }) async {
    if (_authorizingAccess) throw _accessBusy();
    final int accessRevision = _access.revision;
    if (_preparingTransfer) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsTransferPreparationUnavailable,
        safeMessage:
            'A transfer is already being prepared. Wait and try again.',
        canRetry: true,
      );
    }
    _preparingTransfer = true;
    _authorization.invalidate();
    _preparedTransfer = null;
    try {
      final BigInt units;
      try {
        units = RewardsAmount.parse(amount.trim());
        if (units == BigInt.zero) throw const FormatException('Zero amount.');
      } catch (_) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidRewardsAmount,
          safeMessage:
              'Enter a positive Rewards amount with at most seven decimal places.',
          canRetry: false,
        );
      }
      final DateTime started = _clock.nowUtc();
      final ActiveRewardsRecord identity = await _requireActiveRewards();
      final saved = await getRewardsTransferStatus();
      if (saved?.state == RewardsTransferState.uncertain) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsTransferPending,
          safeMessage: 'Verify the previous transfer before preparing another.',
          canRetry: true,
        );
      }
      final ProviderConfiguration? configuration = await _configurationStore
          .readActive();
      if (configuration == null ||
          configuration.environment != identity.environment) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsIdentityUnavailable,
          safeMessage:
              'Your Rewards service settings need attention from App Master.',
          canRetry: true,
        );
      }
      final List<Object> reads = await Future.wait<Object>(<Future<Object>>[
        inspectRewardsRecipient(publicAccount),
        _rewardsTransferClient.load(
          configuration: configuration,
          identity: identity,
        ),
      ]).timeout(const Duration(seconds: 15));
      final RewardsRecipientView recipient = reads[0] as RewardsRecipientView;
      final RewardsTransferCost cost = reads[1] as RewardsTransferCost;
      final RewardsLedgerBalance balance = cost.rewardsBalance;
      if (units > RewardsAmount.parse(balance.available)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.insufficientRewardsFunds,
          safeMessage: 'The amount exceeds your available Rewards.',
          canRetry: false,
        );
      }
      if (units > RewardsAmount.parse(recipient.receivingCapacity)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidRewardsAmount,
          safeMessage: 'The amount exceeds the recipient’s receiving capacity.',
          canRetry: false,
        );
      }
      if (cost.feeStroops <= 0 ||
          cost.feeStroops > 0xffffffff ||
          cost.nativeSpendable < BigInt.from(cost.feeStroops)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.insufficientRewardsFeeFunds,
          safeMessage:
              'Your account needs more native fee funds before sending Rewards.',
          canRetry: false,
        );
      }
      if ((await _requireActiveRewards()).encode() != identity.encode() ||
          (await _configurationStore.readActive())?.encodeProtected() !=
              configuration.encodeProtected()) {
        throw const FormatException('Preparation settings changed.');
      }
      final DateTime expires = started.add(const Duration(minutes: 2));
      if (!_clock.nowUtc().isBefore(expires) ||
          accessRevision != _access.revision) {
        throw const FormatException('Preparation expired.');
      }
      final RewardsTransferReview review = RewardsTransferReview(
        reviewId: 'SEND-${_tokenGenerator.createToken(24)}',
        publicAccount: recipient.publicAccount,
        environment: identity.environment,
        assetCode: identity.assetCode,
        assetIssuer: identity.assetIssuer,
        amount: RewardsAmount.display(units),
        maximumFee: RewardsAmount.display(BigInt.from(cost.feeStroops)),
        expiresAt: expires,
      );
      _preparedTransfer = _PreparedTransfer(
        review: review,
        identity: identity,
        configuration: configuration,
        cost: cost,
      );
      return review;
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsTransferPreparationUnavailable,
        safeMessage:
            'We could not prepare this transfer. Refresh the details and try again.',
        canRetry: true,
      );
    } finally {
      _preparingTransfer = false;
    }
  }

  @override
  Future<RewardsTransferReview> getPreparedRewardsTransfer(
    String reviewId,
  ) async {
    final _PreparedTransfer? prepared = _preparedTransfer;
    try {
      if (prepared == null ||
          prepared.review.reviewId != reviewId ||
          !_clock.nowUtc().isBefore(prepared.review.expiresAt) ||
          (await _requireActiveRewards()).encode() !=
              prepared.identity.encode() ||
          (await _configurationStore.readActive())?.encodeProtected() !=
              prepared.configuration.encodeProtected() ||
          !identical(_preparedTransfer, prepared)) {
        throw const FormatException('Review unavailable.');
      }
      return prepared.review;
    } catch (_) {
      _authorization.invalidate();
      if (identical(_preparedTransfer, prepared)) _preparedTransfer = null;
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidRewardsTransferReview,
        safeMessage:
            'This transfer review is no longer valid. Prepare it again.',
        canRetry: false,
      );
    }
  }

  @override
  Future<RewardsTransferAuthorization> authorizeRewardsTransfer(
    String reviewId,
  ) async {
    if (_authorizingAccess || _access.isBusy) throw _accessBusy();
    final RewardsTransferReview review = await getPreparedRewardsTransfer(
      reviewId,
    );
    final _PreparedTransfer? prepared = _preparedTransfer;
    if (prepared == null || !identical(prepared.review, review)) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidRewardsTransferReview,
        safeMessage: 'Prepare and review the transfer again.',
        canRetry: false,
      );
    }
    final result = await _authorization.authorize(
      review,
      () => _revalidateTransfer(prepared),
    );
    _access.acceptTransferAuthentication();
    return result;
  }

  Future<void> _revalidateTransfer(_PreparedTransfer prepared) async {
    await getPreparedRewardsTransfer(prepared.review.reviewId);
    final List<Object> reads = await Future.wait<Object>(<Future<Object>>[
      inspectRewardsRecipient(prepared.review.publicAccount),
      _rewardsTransferClient.load(
        configuration: prepared.configuration,
        identity: prepared.identity,
      ),
    ]).timeout(const Duration(seconds: 15));
    final RewardsRecipientView recipient = reads[0] as RewardsRecipientView;
    final RewardsTransferCost cost = reads[1] as RewardsTransferCost;
    final BigInt amount = RewardsAmount.parse(prepared.review.amount);
    if (cost.sequence != prepared.cost.sequence ||
        cost.feeStroops > prepared.cost.feeStroops ||
        cost.nativeSpendable < BigInt.from(prepared.cost.feeStroops) ||
        amount > RewardsAmount.parse(cost.rewardsBalance.available) ||
        amount > RewardsAmount.parse(recipient.receivingCapacity)) {
      _preparedTransfer = null;
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidRewardsTransferReview,
        safeMessage:
            'Transfer details changed. Prepare and review the transfer again.',
        canRetry: false,
      );
    }
    await getPreparedRewardsTransfer(prepared.review.reviewId);
  }

  @override
  Future<void> cancelRewardsTransferAuthorization() async {
    _preparedTransfer = null;
    await _authorization.cancel();
  }

  @override
  Future<RewardsRecipientView> inspectRewardsRecipient(
    String publicAccount,
  ) async {
    final account = publicAccount.trim();
    try {
      const StrKeyCodec().decodeEd25519PublicKey(account);
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidRewardsRecipient,
        safeMessage: 'Enter a valid public receiving account address.',
        canRetry: false,
      );
    }
    final identity = await _requireActiveRewards();
    if (account == identity.accountId) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidRewardsRecipient,
        safeMessage: 'Choose a receiving account other than your own.',
        canRetry: false,
      );
    }
    try {
      final configuration = await _configurationStore.readActive();
      if (configuration == null ||
          configuration.environment != identity.environment) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsIdentityUnavailable,
          safeMessage:
              'Your Rewards service settings need attention from App Master.',
          canRetry: true,
        );
      }
      final capacity = await _rewardsRecipientClient.inspect(
        configuration: configuration,
        identity: identity,
        account: account,
      );
      final currentConfiguration = await _configurationStore.readActive();
      if ((await _requireActiveRewards()).encode() != identity.encode() ||
          currentConfiguration?.endpoint != configuration.endpoint ||
          currentConfiguration?.version != configuration.version ||
          currentConfiguration?.environment != configuration.environment ||
          currentConfiguration?.apiKey != configuration.apiKey) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsRecipientUnavailable,
          safeMessage:
              'Your Rewards settings changed. Check the recipient again.',
          canRetry: true,
        );
      }
      return RewardsRecipientView(
        publicAccount: account,
        environment: identity.environment,
        assetCode: identity.assetCode,
        receivingCapacity: capacity,
        observedAt: _clock.nowUtc(),
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsRecipientUnavailable,
        safeMessage:
            'We could not check this recipient. Check your connection and try again.',
        canRetry: true,
      );
    }
  }

  final RewardsHistoryClient _rewardsHistoryClient;

  @override
  Future<RewardsHistoryPage> getRewardsHistory({
    String? cursor,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit');
    }
    final ActiveRewardsRecord identity = await _requireActiveRewards();
    try {
      final ProviderConfiguration? configuration = await _configurationStore
          .readActive();
      if (configuration == null ||
          configuration.environment != identity.environment) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsIdentityUnavailable,
          safeMessage:
              'Your Rewards service settings need attention from App Master.',
          canRetry: true,
        );
      }
      final RewardsLedgerHistoryPage page = await _rewardsHistoryClient.load(
        configuration: configuration,
        identity: identity,
        cursor: cursor,
        limit: limit,
      );
      if ((await _requireActiveRewards()).encode() != identity.encode()) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsIdentityUnavailable,
          safeMessage: 'Your Rewards details changed. Refresh history.',
          canRetry: true,
        );
      }
      return RewardsHistoryPage(
        publicAccount: identity.accountId,
        environment: identity.environment,
        assetCode: identity.assetCode,
        items: page.items,
        nextCursor: page.nextCursor,
        observedAt: _clock.nowUtc(),
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsHistoryUnavailable,
        safeMessage:
            'We could not load Rewards history. Check your connection and try again.',
        canRetry: true,
      );
    }
  }

  Future<ActiveRewardsRecord>? _activeMigration;

  Future<ActiveRewardsRecord> _migrateActiveRewards() async {
    if (_activeMigration != null) return _activeMigration!;
    final Future<ActiveRewardsRecord> migration = ActiveRewardsMigrationService(
      activeStore: _activeRewardsStore,
      activationStore: _activationStore,
      inspectionStore: _activationInspectionStore,
      submissionStore: _activationSubmissionStore,
      configurationStore: _configurationStore,
      credentialStore: _credentialStore,
      deviceIdentity: _deviceIdentityService,
      responseService: _activationResponseService,
      qrCodec: _qrCodec,
      protocol: _stellarProtocol,
      reconciliationClient: _activationReconciliationClient,
      clock: _clock,
    ).migrate();
    _activeMigration = migration;
    try {
      return await migration;
    } finally {
      _activeMigration = null;
    }
  }

  Future<ActiveRewardsRecord> _requireActiveRewards() async {
    await _access.requireAvailable();
    try {
      final ActivationSubmissionRecord? submission =
          await _activationSubmissionStore.read();
      ActiveRewardsRecord? active = await _activeRewardsStore.read();
      if (active == null &&
          submission?.status == ActivationSubmissionStatus.verified) {
        active = await _migrateActiveRewards();
      }
      if (submission == null ||
          active == null ||
          submission.status != ActivationSubmissionStatus.verified ||
          submission.transactionHash != active.activationTransactionHash ||
          submission.responseId != active.responseId) {
        throw const FormatException('Active identity unavailable.');
      }
      active.validate();
      await _access.requireAvailable();
      return active;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsIdentityUnavailable,
        safeMessage:
            'Your Rewards details are unavailable. Contact App Master for help.',
        canRetry: true,
      );
    }
  }

  @override
  Future<RewardsBalanceView> getRewardsBalance() async {
    final ActiveRewardsRecord identity = await _requireActiveRewards();
    try {
      final ProviderConfiguration? configuration = await _configurationStore
          .readActive();
      if (configuration == null ||
          configuration.environment != identity.environment) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsIdentityUnavailable,
          safeMessage:
              'Your Rewards service settings need attention from App Master.',
          canRetry: true,
        );
      }
      final RewardsLedgerBalance balance = await _rewardsBalanceClient.load(
        configuration: configuration,
        identity: identity,
      );
      final ActiveRewardsRecord current = await _requireActiveRewards();
      if (current.encode() != identity.encode()) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsIdentityUnavailable,
          safeMessage: 'Your Rewards details changed. Refresh again.',
          canRetry: true,
        );
      }
      return RewardsBalanceView(
        publicAccount: identity.accountId,
        environment: identity.environment,
        assetCode: identity.assetCode,
        total: balance.total,
        available: balance.available,
        observedAt: _clock.nowUtc(),
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsBalanceUnavailable,
        safeMessage:
            'We could not refresh your Rewards balance. Check your connection and try again.',
        canRetry: true,
      );
    }
  }

  @override
  Future<RewardsReceiveView> getRewardsReceiveIdentity() async {
    try {
      final ActiveRewardsRecord active = await _requireActiveRewards();
      return RewardsReceiveView(
        publicAccount: active.accountId,
        qrValue: active.accountId,
        environment: active.environment,
        assetCode: active.assetCode,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.unavailable,
        safeMessage:
            'Your Rewards receiving details are unavailable. Contact App Master for help.',
        canRetry: true,
      );
    }
  }

  final ActivationStore _activationStore;
  final ActiveRewardsStore _activeRewardsStore;
  final CredentialStore _credentialStore;
  final WalletClock _clock;
  final ActivationTokenGenerator _tokenGenerator;
  final WalletKeyGenerator _keyGenerator;
  final ActivationQrCodec _qrCodec;
  final DeviceConfigurationIdentityService _deviceIdentityService;
  final ConfigurationPolicy _configurationPolicy;
  final ConfigurationStore _configurationStore;
  final HorizonHealthClient _horizonHealthClient;
  final ActivationInspectionStore _activationInspectionStore;
  final DistributorAuthorityService _distributorAuthorityService;
  final DistributorStatusClient _distributorStatusClient;
  final ActivationResponseService _activationResponseService;
  final ActivationSubmissionStore _activationSubmissionStore;
  final ActivationSubmissionClient _activationSubmissionClient;
  final ActivationReconciliationClient _activationReconciliationClient;
  final StellarActivationProtocol _stellarProtocol;
  final ConfigurationHandshakeService _configurationHandshakeService;
  final ConfigurationHandshakeStore _configurationHandshakeStore;

  @override
  Future<ActivationRequestView> startActivation(BuilderIdentity builder) async {
    if (_authorizingAccess) throw _accessBusy();
    await _access.requireAvailable();
    final existingSubmission = await _activationSubmissionStore.read();
    if (await _activeRewardsStore.read() != null ||
        (existingSubmission != null &&
            existingSubmission.status != ActivationSubmissionStatus.rejected)) {
      throw _accessBusy();
    }
    final ActivationRequestView? existing = await restoreActivationRequest();
    if (existing != null) {
      return existing;
    }

    final String name = builder.displayName.trim();
    final String phone = builder.phone.trim();
    if (name.isEmpty || !phone.startsWith('+') || phone.length < 8) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidBuilder,
        safeMessage: 'Check your Builder name and phone number.',
        canRetry: true,
      );
    }

    final DateTime createdAt = _clock.nowUtc();
    final DateTime expiresAt = createdAt.add(_requestLifetime);
    final String requestId = _tokenGenerator.createRequestId();
    final String credentialKey = '$_credentialKeyPrefix$requestId';

    try {
      final WalletKeyPair keyPair = await _keyGenerator.generate();
      final DeviceConfigurationIdentity deviceIdentity =
          await _deviceIdentityService.getOrCreate();
      await _credentialStore.write(
        key: credentialKey,
        value: keyPair.secretSeed,
      );

      final BuilderIdentity normalizedBuilder = BuilderIdentity(
        displayName: name,
        phone: phone,
      );
      final String qrValue = await _qrCodec.encodeRequest(
        requestId: requestId,
        challenge: _tokenGenerator.createToken(24),
        createdAt: createdAt,
        expiresAt: expiresAt,
        builder: normalizedBuilder,
        activationAddress: keyPair.accountId,
        deviceId: deviceIdentity.deviceId,
        devicePublicKey: deviceIdentity.publicKey,
      );
      await _activationStore.write(
        PendingActivationRecord(
          requestId: requestId,
          qrValue: qrValue,
          expiresAt: expiresAt,
          credentialKey: credentialKey,
          builderName: name,
          builderPhone: phone,
        ),
      );

      return ActivationRequestView(
        requestId: requestId,
        qrValue: qrValue,
        expiresAt: expiresAt,
        builder: normalizedBuilder,
      );
    } catch (_) {
      await _credentialStore.delete(credentialKey);
      await _activationStore.clear();
      throw const WalletSdkException(
        code: WalletSdkFailureCode.requestCreationFailed,
        safeMessage: "We couldn't prepare your activation request. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ActivationRequestView?> restoreActivationRequest() async {
    try {
      if ((await getActivationStatus()).state == WalletActivationState.active) {
        return null;
      }
      final PendingActivationRecord? stored = await _activationStore.read();
      if (stored == null) {
        return null;
      }

      late final DecodedActivationRequest decoded;
      try {
        decoded = await _qrCodec.decodeAndValidate(
          stored.qrValue,
          now: _clock.nowUtc(),
        );
      } on FormatException {
        await _clearAttempt(stored.credentialKey);
        return null;
      }
      if (decoded.requestId != stored.requestId ||
          decoded.expiresAt != stored.expiresAt) {
        await _clearAttempt(stored.credentialKey);
        return null;
      }

      final bool hasProtectedSetup = await _credentialStore.contains(
        stored.credentialKey,
      );
      if (!hasProtectedSetup || !_clock.nowUtc().isBefore(stored.expiresAt)) {
        await _clearAttempt(stored.credentialKey);
        return null;
      }

      return ActivationRequestView(
        requestId: stored.requestId,
        qrValue: stored.qrValue,
        expiresAt: stored.expiresAt,
        builder: BuilderIdentity(
          displayName: stored.builderName,
          phone: stored.builderPhone,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancelActivation() async {
    await _access.requireAvailable();
    try {
      final PendingActivationRecord? stored = await _activationStore.read();
      if (stored == null) {
        return;
      }
      await _clearAttempt(stored.credentialKey);
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.cancellationFailed,
        safeMessage: "We couldn't cancel this activation. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ActivationRequestReview> inspectBuilderRequest(String qrValue) async {
    try {
      final DecodedActivationRequest decoded = await _qrCodec.decodeAndValidate(
        qrValue,
        now: _clock.nowUtc(),
      );
      if (await _activationInspectionStore.isConsumed(decoded.requestId)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.activationRequestAlreadyUsed,
          safeMessage: 'This activation request has already been used.',
          canRetry: false,
        );
      }
      await _activationInspectionStore.savePendingRequest(qrValue);
      return _toReview(decoded);
    } on WalletSdkException {
      rethrow;
    } on ExpiredActivationRequestException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.activationRequestExpired,
        safeMessage:
            'This activation request has expired. Ask the Builder for a new one.',
        canRetry: false,
      );
    } on FormatException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidActivationRequest,
        safeMessage: "We couldn't verify this activation request.",
        canRetry: false,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.unavailable,
        safeMessage: "We couldn't inspect this activation request. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ActivationRequestReview?> restoreInspectedBuilderRequest() async {
    try {
      final String? qrValue = await _activationInspectionStore
          .readPendingRequest();
      if (qrValue == null) {
        return null;
      }
      return await inspectBuilderRequest(qrValue);
    } catch (_) {
      try {
        await _activationInspectionStore.clearPendingRequest();
      } catch (_) {
        // Restoration remains fail-closed even if stale-state cleanup fails.
      }
      return null;
    }
  }

  @override
  Future<ActivationResponseView> approveBuilderRequest(String requestId) async {
    try {
      final String? qrValue = await _activationInspectionStore
          .readPendingRequest();
      final ProviderConfiguration? configuration = await _configurationStore
          .readActive();
      final String? distributorSecret = await _distributorAuthorityService
          .readSecret();
      if (configuration == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.providerConfigurationRequired,
          safeMessage: 'Verify the activation service settings first.',
          canRetry: false,
        );
      }
      if (qrValue == null || distributorSecret == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.activationApprovalFailed,
          safeMessage: 'Complete App Master setup and scan the request again.',
          canRetry: false,
        );
      }
      final DecodedActivationRequest request = await _qrCodec.decodeAndValidate(
        qrValue,
        now: _clock.nowUtc(),
      );
      if (request.requestId != requestId ||
          await _activationInspectionStore.isConsumed(requestId)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidActivationRequest,
          safeMessage: "We couldn't verify this activation request.",
          canRetry: false,
        );
      }
      final String distributorAccount = await _distributorAuthorityService
          .deriveAccountId(distributorSecret);
      final DistributorLedgerStatus ledger = await _distributorStatusClient
          .load(configuration: configuration, accountId: distributorAccount);
      return _activationResponseService.create(
        request: request,
        configuration: configuration,
        ledger: ledger,
        distributorAccount: distributorAccount,
        distributorSecret: distributorSecret,
        now: _clock.nowUtc(),
        responseId: _tokenGenerator.createRequestId().replaceFirst(
          'ACT-',
          'RES-',
        ),
      );
    } on WalletSdkException {
      rethrow;
    } on ExpiredActivationRequestException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.activationRequestExpired,
        safeMessage: 'This activation request has expired.',
        canRetry: false,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.activationApprovalFailed,
        safeMessage: "We couldn't create the activation package. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ActivationReview> inspectActivationResponse(String qrValue) async {
    try {
      final PendingActivationRecord? pending = await _activationStore.read();
      if (pending == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidActivationResponse,
          safeMessage: 'Start activation on this device first.',
          canRetry: false,
        );
      }
      final DecodedActivationRequest request = await _qrCodec.decodeAndValidate(
        pending.qrValue,
        now: _clock.nowUtc(),
      );
      final ActivationReview review = await _activationResponseService.inspect(
        encoded: qrValue,
        request: request,
        deviceKeyPair: await _deviceIdentityService.readPrivateKeyPair(),
        now: _clock.nowUtc(),
      );
      if (await _activationInspectionStore.isConsumed(review.responseId)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidActivationResponse,
          safeMessage: 'This activation package has already been reviewed.',
          canRetry: false,
        );
      }
      await _activationInspectionStore.savePendingResponse(qrValue);
      await _activationInspectionStore.markConsumed(review.responseId);
      return review;
    } on WalletSdkException {
      rethrow;
    } on ExpiredActivationResponseException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.activationResponseExpired,
        safeMessage: 'This activation has expired. Request a new one.',
        canRetry: false,
      );
    } on SecretBoxAuthenticationError {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidActivationResponse,
        safeMessage: "This activation wasn't prepared for this device.",
        canRetry: false,
      );
    } on FormatException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidActivationResponse,
        safeMessage: "We couldn't verify this activation package.",
        canRetry: false,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.unavailable,
        safeMessage: "We couldn't inspect this activation. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ActivationOutcome> approveActivation(String responseId) async {
    await _access.requireAvailable();
    final ActivationSubmissionRecord? existing =
        await _activationSubmissionStore.read();
    if (existing != null && existing.responseId == responseId) {
      return _toActivationOutcome(existing);
    }
    try {
      final PendingActivationRecord? pending = await _activationStore.read();
      final String? response = await _activationInspectionStore
          .readPendingResponse();
      if (pending == null ||
          response == null ||
          !await _activationInspectionStore.isConsumed(responseId)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidActivationResponse,
          safeMessage: 'Review this activation package before approving it.',
          canRetry: false,
        );
      }
      final DecodedActivationRequest request = await _qrCodec.decodeAndValidate(
        pending.qrValue,
        now: _clock.nowUtc(),
      );
      final InspectedActivationResponse inspected =
          await _activationResponseService.inspectDetails(
            encoded: response,
            request: request,
            deviceKeyPair: await _deviceIdentityService.readPrivateKeyPair(),
            now: _clock.nowUtc(),
          );
      if (inspected.review.responseId != responseId) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidActivationResponse,
          safeMessage: 'The reviewed activation package does not match.',
          canRetry: false,
        );
      }
      final String? builderSecret = await _credentialStore.read(
        pending.credentialKey,
      );
      if (builderSecret == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.activationSubmissionFailed,
          safeMessage: 'The protected activation key is unavailable.',
          canRetry: false,
        );
      }
      final String passphrase =
          inspected.configuration.environment == ProviderEnvironment.test
          ? StellarActivationProtocol.testNetworkPassphrase
          : StellarActivationProtocol.publicNetworkPassphrase;
      final List<int> hash = await _stellarProtocol.transactionHash(
        inspected.envelope,
        passphrase,
      );
      final String transactionHash = hash
          .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      await _activationSubmissionStore.write(
        ActivationSubmissionRecord(
          responseId: responseId,
          transactionHash: transactionHash,
          status: ActivationSubmissionStatus.submitting,
        ),
      );
      final StellarActivationEnvelope signed = await _stellarProtocol.sign(
        inspected.envelope,
        secretSeed: builderSecret,
        networkPassphrase: passphrase,
      );
      final ActivationSubmissionResult result =
          await _activationSubmissionClient.submit(
            configuration: inspected.configuration,
            envelopeXdr: _stellarProtocol.encodeEnvelopeBase64(signed),
          );
      final ActivationSubmissionStatus status = switch (result) {
        ActivationSubmissionResult.accepted =>
          ActivationSubmissionStatus.submitted,
        ActivationSubmissionResult.rejected =>
          ActivationSubmissionStatus.rejected,
        ActivationSubmissionResult.uncertain =>
          ActivationSubmissionStatus.uncertain,
      };
      final ActivationSubmissionRecord record = ActivationSubmissionRecord(
        responseId: responseId,
        transactionHash: transactionHash,
        status: status,
      );
      await _activationSubmissionStore.write(record);
      return _toActivationOutcome(record);
    } on WalletSdkException {
      rethrow;
    } on FormatException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidActivationResponse,
        safeMessage: "We couldn't verify this activation package.",
        canRetry: false,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.activationSubmissionFailed,
        safeMessage:
            "We couldn't submit this activation. Check its status later.",
        canRetry: false,
      );
    }
  }

  @override
  Future<WalletActivationStatus> getActivationStatus() async {
    try {
      final ActivationSubmissionRecord? record =
          await _activationSubmissionStore.read();
      return record == null
          ? const WalletActivationStatus.notActivated()
          : _toWalletActivationStatus(record.status);
    } catch (_) {
      return const WalletActivationStatus.notActivated();
    }
  }

  @override
  Future<WalletActivationStatus> reconcileActivation() async {
    final ActivationSubmissionRecord? record = await _activationSubmissionStore
        .read();
    if (record == null) return const WalletActivationStatus.notActivated();
    if (record.status == ActivationSubmissionStatus.verified ||
        record.status == ActivationSubmissionStatus.rejected) {
      return _toWalletActivationStatus(record.status);
    }
    try {
      final PendingActivationRecord? pending = await _activationStore.read();
      final String? response = await _activationInspectionStore
          .readPendingResponse();
      if (pending == null || response == null) {
        return _toWalletActivationStatus(ActivationSubmissionStatus.uncertain);
      }
      final DecodedActivationRequest request = await _qrCodec.decodeAndValidate(
        pending.qrValue,
        now: pending.expiresAt.subtract(const Duration(microseconds: 1)),
      );
      final InspectedActivationResponse inspected =
          await _activationResponseService.inspectDetails(
            encoded: response,
            request: request,
            deviceKeyPair: await _deviceIdentityService.readPrivateKeyPair(),
            now: _clock.nowUtc(),
            allowExpired: true,
          );
      final StellarChangeTrustOperation trust =
          inspected.envelope.operations[1] as StellarChangeTrustOperation;
      final List<int> expectedHash = await _stellarProtocol.transactionHash(
        inspected.envelope,
        inspected.configuration.environment == ProviderEnvironment.test
            ? StellarActivationProtocol.testNetworkPassphrase
            : StellarActivationProtocol.publicNetworkPassphrase,
      );
      final String expectedHashHex = expectedHash
          .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      if (record.responseId != inspected.review.responseId ||
          record.transactionHash != expectedHashHex) {
        return _toWalletActivationStatus(ActivationSubmissionStatus.uncertain);
      }
      ActivationReconciliationResult result =
          ActivationReconciliationResult.pending;
      for (int attempt = 0; attempt < 3; attempt++) {
        result = await _activationReconciliationClient.reconcile(
          configuration: inspected.configuration,
          transactionHash: record.transactionHash,
          builderAccount: request.activationAddress,
          assetCode: trust.asset.code!,
          assetIssuer: trust.asset.issuer!,
          minimumRewards: 1,
        );
        if (result != ActivationReconciliationResult.pending) break;
      }
      if (result == ActivationReconciliationResult.verified) {
        await _configurationStore.savePending(inspected.configuration);
        try {
          await _horizonHealthClient.check(inspected.configuration);
          await _configurationStore.promotePending(_clock.nowUtc());
        } catch (_) {
          await _discardPendingSafely();
          return _toWalletActivationStatus(
            ActivationSubmissionStatus.uncertain,
          );
        }
        await ActivationFinalizationService(
          activeStore: _activeRewardsStore,
          submissionStore: _activationSubmissionStore,
          credentialStore: _credentialStore,
        ).finalize(
          ActiveRewardsRecord(
            accountId: request.activationAddress,
            credentialKey: pending.credentialKey,
            environment: inspected.configuration.environment,
            assetCode: trust.asset.code!,
            assetIssuer: trust.asset.issuer!,
            activationTransactionHash: record.transactionHash,
            responseId: record.responseId,
            verifiedAt: _clock.nowUtc(),
          ),
        );
        return _toWalletActivationStatus(ActivationSubmissionStatus.verified);
      }
      if (result == ActivationReconciliationResult.failed) {
        await _activationSubmissionStore.write(
          ActivationSubmissionRecord(
            responseId: record.responseId,
            transactionHash: record.transactionHash,
            status: ActivationSubmissionStatus.rejected,
          ),
        );
        return _toWalletActivationStatus(ActivationSubmissionStatus.rejected);
      }
      await _activationSubmissionStore.write(
        ActivationSubmissionRecord(
          responseId: record.responseId,
          transactionHash: record.transactionHash,
          status: ActivationSubmissionStatus.uncertain,
        ),
      );
      return _toWalletActivationStatus(ActivationSubmissionStatus.uncertain);
    } catch (_) {
      return _toWalletActivationStatus(ActivationSubmissionStatus.uncertain);
    }
  }

  @override
  Future<ConfigurationRequestView> createConfigurationRequest() async {
    try {
      final ProviderConfiguration? active = await _configurationStore
          .readActive();
      final restored = await _activeRewardsStore.read();
      if (active == null && restored == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.providerConfigurationRequired,
          safeMessage: 'Activate Rewards before updating service settings.',
          canRetry: false,
        );
      }
      final DeviceConfigurationIdentity device = await _deviceIdentityService
          .getOrCreate();
      final DateTime now = _clock.nowUtc();
      final String requestId = _tokenGenerator.createRequestId().replaceFirst(
        'ACT-',
        'CFG-',
      );
      final String qrValue = await _configurationHandshakeService.createRequest(
        requestId: requestId,
        deviceId: device.deviceId,
        devicePublicKey: device.publicKey,
        currentVersion: active?.version ?? 0,
        environment: active?.environment ?? restored!.environment,
        challenge: _tokenGenerator.createToken(24),
        now: now,
      );
      await _configurationHandshakeStore.saveRequest(qrValue);
      return ConfigurationRequestView(
        requestId: requestId,
        qrValue: qrValue,
        expiresAt: now.add(ConfigurationHandshakeService.lifetime),
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidConfigurationRequest,
        safeMessage: "We couldn't create the settings request.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ConfigurationRequestReview> inspectConfigurationRequest(
    String qrValue,
  ) async {
    try {
      final DecodedConfigurationRequest request =
          await _configurationHandshakeService.inspectRequest(
            qrValue,
            _clock.nowUtc(),
          );
      await _configurationHandshakeStore.saveRequest(qrValue);
      return ConfigurationRequestReview(
        requestId: request.requestId,
        currentVersion: request.currentVersion,
        environment: request.environment,
        expiresAt: request.expiresAt,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidConfigurationRequest,
        safeMessage: "We couldn't verify this settings request.",
        canRetry: false,
      );
    }
  }

  @override
  Future<ConfigurationUpdateView> createConfigurationUpdate(
    String requestId,
  ) async {
    try {
      final String? rawRequest = await _configurationHandshakeStore
          .readRequest();
      final ProviderConfiguration? configuration = await _configurationStore
          .readActive();
      final String? secret = await _distributorAuthorityService.readSecret();
      if (rawRequest == null || configuration == null || secret == null) {
        throw const FormatException(
          'Configuration update setup is incomplete.',
        );
      }
      final DecodedConfigurationRequest request =
          await _configurationHandshakeService.inspectRequest(
            rawRequest,
            _clock.nowUtc(),
          );
      if (request.requestId != requestId) {
        throw const FormatException('Configuration request mismatch.');
      }
      final DateTime now = _clock.nowUtc();
      final String updateId = _tokenGenerator.createRequestId().replaceFirst(
        'ACT-',
        'UPD-',
      );
      final String qrValue = await _configurationHandshakeService.createUpdate(
        updateId: updateId,
        request: request,
        configuration: configuration,
        signingSecret: secret,
        signerAccount: await _distributorAuthorityService.deriveAccountId(
          secret,
        ),
        now: now,
      );
      return ConfigurationUpdateView(
        updateId: updateId,
        requestId: requestId,
        qrValue: qrValue,
        expiresAt:
            now
                .add(ConfigurationHandshakeService.lifetime)
                .isBefore(request.expiresAt)
            ? now.add(ConfigurationHandshakeService.lifetime)
            : request.expiresAt,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidConfigurationUpdate,
        safeMessage: "We couldn't create the settings update.",
        canRetry: false,
      );
    }
  }

  @override
  Future<ConfigurationReview> inspectConfigurationUpdate(String qrValue) async {
    try {
      final String? rawRequest = await _configurationHandshakeStore
          .readRequest();
      final ProviderConfiguration? active = await _configurationStore
          .readActive();
      final restored = await _activeRewardsStore.read();
      if (rawRequest == null || (active == null && restored == null)) {
        throw const FormatException('Configuration request is unavailable.');
      }
      final DecodedConfigurationRequest request =
          await _configurationHandshakeService.inspectRequest(
            rawRequest,
            _clock.nowUtc(),
          );
      final InspectedConfigurationUpdate inspected =
          await _configurationHandshakeService.inspectUpdate(
            encoded: qrValue,
            request: request,
            deviceKeyPair: await _deviceIdentityService.readPrivateKeyPair(),
            installedVersion: active?.version ?? 0,
            now: _clock.nowUtc(),
          );
      if (await _configurationHandshakeStore.isConsumed(
        inspected.review.updateId,
      )) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.configurationUpdateAlreadyUsed,
          safeMessage: 'This settings update has already been used.',
          canRetry: false,
        );
      }
      await _configurationStore.savePending(inspected.configuration);
      await _configurationHandshakeStore.saveUpdate(
        qrValue,
        inspected.review.updateId,
      );
      return inspected.review;
    } on ExpiredConfigurationUpdateException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.configurationUpdateExpired,
        safeMessage: 'This settings update has expired.',
        canRetry: false,
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      await _discardPendingSafely();
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidConfigurationUpdate,
        safeMessage: "We couldn't verify this settings update.",
        canRetry: false,
      );
    }
  }

  @override
  Future<ConfigurationOutcome> applyConfigurationUpdate(String updateId) async {
    try {
      if (await _configurationHandshakeStore.isConsumed(updateId)) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.configurationUpdateAlreadyUsed,
          safeMessage: 'This settings update has already been used.',
          canRetry: false,
        );
      }
      final String? reviewedId = await _configurationHandshakeStore
          .readReviewedUpdateId();
      final ProviderConfiguration? candidate = await _configurationStore
          .readPending();
      if (reviewedId != updateId || candidate == null) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidConfigurationUpdate,
          safeMessage: 'Review the matching settings update first.',
          canRetry: false,
        );
      }
      await _horizonHealthClient.check(candidate);
      await _configurationStore.promotePending(_clock.nowUtc());
      await _configurationHandshakeStore.markConsumed(updateId);
      return ConfigurationOutcome(
        status: await _configurationStore.readStatus(),
      );
    } on WalletSdkException {
      await _discardPendingSafely();
      rethrow;
    } catch (_) {
      await _discardPendingSafely();
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidConfigurationUpdate,
        safeMessage: "We couldn't apply this settings update.",
        canRetry: true,
      );
    }
  }

  @override
  Future<DistributorAuthorityStatus> importDistributorSecret(
    String secret,
  ) async {
    final String candidate = secret.trim();
    final ProviderConfiguration? configuration = await _configurationStore
        .readActive();
    if (configuration == null) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerConfigurationRequired,
        safeMessage: 'Verify the activation service settings first.',
        canRetry: false,
      );
    }
    try {
      await _distributorAuthorityService.verifyAndStore(
        secret: candidate,
        configuration: configuration,
      );
      final String accountId = await _distributorAuthorityService
          .deriveAccountId(candidate);
      return DistributorAuthorityStatus(
        state: DistributorAuthorityState.ready,
        maskedAccountId: _maskAccountId(accountId),
        environment: configuration.environment,
        verifiedAt: _clock.nowUtc(),
      );
    } on FormatException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidDistributorSecret,
        safeMessage: 'The distributor secret is not valid.',
        canRetry: true,
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.distributorAuthoritySaveFailed,
        safeMessage: "We couldn't protect the distributor account. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<DistributorAuthorityStatus> getDistributorAuthorityStatus() async {
    try {
      final String? accountId = await _distributorAuthorityService
          .readAccountId();
      if (accountId == null) {
        return const DistributorAuthorityStatus.notConfigured();
      }
      final ProviderConfiguration? configuration = await _configurationStore
          .readActive();
      return DistributorAuthorityStatus(
        state: DistributorAuthorityState.ready,
        maskedAccountId: _maskAccountId(accountId),
        environment: configuration?.environment,
      );
    } catch (_) {
      return const DistributorAuthorityStatus.notConfigured();
    }
  }

  @override
  Future<void> removeDistributorAuthority() async {
    try {
      await _distributorAuthorityService.clear();
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.distributorAuthoritySaveFailed,
        safeMessage: "We couldn't remove the distributor account. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<AppMasterOverview> getAppMasterOverview() async {
    final ProviderConfiguration? configuration = await _configurationStore
        .readActive();
    final String? accountId = await _distributorAuthorityService
        .readAccountId();
    if (configuration == null || accountId == null) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerConfigurationRequired,
        safeMessage: 'Complete the App Master setup in Advanced first.',
        canRetry: false,
      );
    }
    final DistributorLedgerStatus status = await _distributorStatusClient.load(
      configuration: configuration,
      accountId: accountId,
    );
    const double baseReserve = 0.5;
    final double activationFundingPolicy =
        configuration.activationFundingUnits / 10000000;
    final double retainedReserve =
        (2 + status.subentryCount) * baseReserve +
        status.nativeSellingLiabilities +
        (status.feeP95Stroops * 3 / 10000000) +
        0.5;
    final double spendable = (status.nativeBalance - retainedReserve).clamp(
      0,
      double.infinity,
    );
    final int fundingCapacity = (spendable / activationFundingPolicy).floor();
    final int rewardCapacity = status.nonNativeAssets.length == 1
        ? (status.nonNativeAssets.single.spendable /
                  (configuration.initialRewardsUnits / 10000000))
              .floor()
        : 0;
    final int capacity = min(fundingCapacity, rewardCapacity);
    final String rewardsAvailable =
        status.nonNativeSpendableBalances.length == 1
        ? _formatRewards(status.nonNativeSpendableBalances.single)
        : status.nonNativeSpendableBalances.isEmpty
        ? 'Not available'
        : 'Needs review';
    return AppMasterOverview(
      activationCapacity: capacity,
      rewardsAvailable: rewardsAvailable,
      serviceStatus: capacity > 0 ? 'Ready for activations' : 'Needs funding',
      updatedAt: _clock.nowUtc(),
    );
  }

  @override
  Future<ProviderConfigurationOutcome> saveAppMasterProviderConfiguration(
    ProviderConfigurationInput input,
  ) async {
    final configuration = _configurationPolicy.validate(input);
    try {
      await _configurationStore.savePending(configuration);
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerConfigurationSaveFailed,
        safeMessage: "We couldn't protect these settings. Try again.",
        canRetry: true,
      );
    }

    try {
      await _horizonHealthClient.check(configuration);
    } on WalletSdkException {
      await _discardPendingSafely();
      rethrow;
    } catch (_) {
      await _discardPendingSafely();
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerServiceUnavailable,
        safeMessage: 'The activation service is unavailable. Try again.',
        canRetry: true,
      );
    }

    try {
      await _configurationStore.promotePending(_clock.nowUtc());
      return ProviderConfigurationOutcome(
        status: await _configurationStore.readStatus(),
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerConfigurationSaveFailed,
        safeMessage: "We couldn't protect these settings. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ProviderConfigurationStatus> getProviderConfigurationStatus() async {
    try {
      final status = await _configurationStore.readStatus();
      final config = await _configurationStore.readActive();
      return ProviderConfigurationStatus(
        state: status.state,
        environment: status.environment,
        version: status.version,
        endpointHost: status.endpointHost,
        lastCheckedAt: status.lastCheckedAt,
        activationFunding: config == null
            ? '2.1'
            : RewardsAmount.display(BigInt.from(config.activationFundingUnits)),
        initialRewards: config == null
            ? '1'
            : RewardsAmount.display(BigInt.from(config.initialRewardsUnits)),
      );
    } catch (_) {
      return const ProviderConfigurationStatus.notConfigured();
    }
  }

  Future<void> _discardPendingSafely() async {
    try {
      await _configurationStore.discardPending();
    } catch (_) {
      // The original safe health-check error remains authoritative.
    }
  }

  Future<void> _clearAttempt(String credentialKey) async {
    await _access.requireAvailable();
    final active = await _activeRewardsStore.read();
    final submission = await _activationSubmissionStore.read();
    if (active?.credentialKey == credentialKey ||
        (submission != null &&
            submission.status != ActivationSubmissionStatus.rejected)) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.cancellationFailed,
        safeMessage:
            'Preserve this account until its activation is resolved. Contact App Master.',
        canRetry: false,
      );
    }
    await _credentialStore.delete(credentialKey);
    await _activationStore.clear();
  }

  ActivationRequestReview _toReview(DecodedActivationRequest decoded) =>
      ActivationRequestReview(
        requestId: decoded.requestId,
        builder: decoded.builder,
        expiresAt: decoded.expiresAt,
        setupSteps: const <String>[
          'Set up Rewards',
          'Enable Rewards access',
          'Add starting Rewards',
        ],
      );

  ActivationOutcome _toActivationOutcome(ActivationSubmissionRecord record) {
    final ActivationOutcomeState state = switch (record.status) {
      ActivationSubmissionStatus.submitted => ActivationOutcomeState.submitted,
      ActivationSubmissionStatus.rejected => ActivationOutcomeState.rejected,
      ActivationSubmissionStatus.verified => ActivationOutcomeState.submitted,
      ActivationSubmissionStatus.submitting ||
      ActivationSubmissionStatus.uncertain => ActivationOutcomeState.uncertain,
    };
    final String message = switch (state) {
      ActivationOutcomeState.submitted =>
        'Activation submitted. Verifying Rewards setup…',
      ActivationOutcomeState.rejected =>
        'Activation was not accepted. Request a new activation.',
      ActivationOutcomeState.uncertain =>
        'Activation status is being checked. Do not submit it again.',
    };
    return ActivationOutcome(
      responseId: record.responseId,
      state: state,
      message: message,
    );
  }

  WalletActivationStatus _toWalletActivationStatus(
    ActivationSubmissionStatus status,
  ) => switch (status) {
    ActivationSubmissionStatus.verified => const WalletActivationStatus(
      state: WalletActivationState.active,
      message: 'Rewards is active.',
    ),
    ActivationSubmissionStatus.rejected => const WalletActivationStatus(
      state: WalletActivationState.failed,
      message: 'Activation was not accepted. Request a new activation.',
    ),
    ActivationSubmissionStatus.uncertain => const WalletActivationStatus(
      state: WalletActivationState.uncertain,
      message: 'Activation status is still being checked.',
    ),
    ActivationSubmissionStatus.submitting ||
    ActivationSubmissionStatus.submitted => const WalletActivationStatus(
      state: WalletActivationState.pending,
      message: 'Activation is being verified.',
    ),
  };

  String _maskAccountId(String accountId) =>
      '${accountId.substring(0, 6)}…${accountId.substring(accountId.length - 6)}';

  String _formatRewards(double value) {
    final String fixed = value.toStringAsFixed(7);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

/// Private exact intent retained only in this SDK instance; never submitted here.
final class _PreparedTransfer {
  const _PreparedTransfer({
    required this.review,
    required this.identity,
    required this.configuration,
    required this.cost,
  });
  final RewardsTransferReview review;
  final ActiveRewardsRecord identity;
  final ProviderConfiguration configuration;
  final RewardsTransferCost cost;
}
