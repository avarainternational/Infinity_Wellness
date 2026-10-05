import 'package:employee_wellness/wallet_sdk/src/activation/activation_finalization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/activation/activation_response_service.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/device_configuration_identity.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/stellar_activation_protocol.dart';
import 'package:employee_wellness/wallet_sdk/src/qr/activation_qr_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_inspection_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_submission_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/configuration_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/activation_reconciliation_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

/// Reconstructs identity only from retained authorized activation and live ledger
/// evidence. Never submits, creates an account, or replaces provider settings.
final class ActiveRewardsMigrationService {
  ActiveRewardsMigrationService({
    required this.activeStore,
    required this.activationStore,
    required this.inspectionStore,
    required this.submissionStore,
    required this.configurationStore,
    required this.credentialStore,
    required this.deviceIdentity,
    required this.responseService,
    required this.qrCodec,
    required this.protocol,
    required this.reconciliationClient,
    required this.clock,
  });
  final ActiveRewardsStore activeStore;
  final ActivationStore activationStore;
  final ActivationInspectionStore inspectionStore;
  final ActivationSubmissionStore submissionStore;
  final ConfigurationStore configurationStore;
  final CredentialStore credentialStore;
  final DeviceConfigurationIdentityService deviceIdentity;
  final ActivationResponseService responseService;
  final ActivationQrCodec qrCodec;
  final StellarActivationProtocol protocol;
  final ActivationReconciliationClient reconciliationClient;
  final WalletClock clock;

  Future<ActiveRewardsRecord> migrate() async {
    final ActivationSubmissionRecord? submission = await submissionStore.read();
    if (submission == null ||
        submission.status != ActivationSubmissionStatus.verified) {
      throw const FormatException('Verified activation required.');
    }
    final PendingActivationRecord? pending = await activationStore.read();
    final String? encodedResponse = await inspectionStore.readPendingResponse();
    if (pending == null || encodedResponse == null) {
      throw const FormatException('Activation evidence unavailable.');
    }
    final DecodedActivationRequest request = await qrCodec.decodeAndValidate(
      pending.qrValue,
      now: pending.expiresAt.subtract(const Duration(microseconds: 1)),
    );
    if (request.requestId != pending.requestId ||
        request.expiresAt != pending.expiresAt ||
        pending.credentialKey !=
            'rewards.activation.secret.${request.requestId}') {
      throw const FormatException('Activation request binding mismatch.');
    }
    final InspectedActivationResponse response = await responseService
        .inspectDetails(
          encoded: encodedResponse,
          request: request,
          deviceKeyPair: await deviceIdentity.readPrivateKeyPair(),
          now: clock.nowUtc(),
          allowExpired: true,
        );
    final List<int> hash = await protocol.transactionHash(
      response.envelope,
      response.configuration.environment == ProviderEnvironment.test
          ? StellarActivationProtocol.testNetworkPassphrase
          : StellarActivationProtocol.publicNetworkPassphrase,
    );
    final String hashHex = hash
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (submission.responseId != response.review.responseId ||
        submission.transactionHash != hashHex) {
      throw const FormatException('Activation transaction binding mismatch.');
    }
    final ProviderConfiguration? configuration = await configurationStore
        .readActive();
    if (configuration == null ||
        configuration.environment != response.configuration.environment) {
      throw const FormatException('Active provider unavailable.');
    }
    final StellarChangeTrustOperation trust =
        response.envelope.operations[1] as StellarChangeTrustOperation;
    final ActivationReconciliationResult result = await reconciliationClient
        .reconcile(
          configuration: configuration,
          transactionHash: hashHex,
          builderAccount: request.activationAddress,
          assetCode: trust.asset.code!,
          assetIssuer: trust.asset.issuer!,
          minimumRewards: 0,
        );
    if (result != ActivationReconciliationResult.verified) {
      throw const FormatException('Ledger verification unavailable.');
    }
    final ActiveRewardsRecord record = ActiveRewardsRecord(
      accountId: request.activationAddress,
      credentialKey: pending.credentialKey,
      environment: configuration.environment,
      assetCode: trust.asset.code!,
      assetIssuer: trust.asset.issuer!,
      activationTransactionHash: hashHex,
      responseId: submission.responseId,
      verifiedAt: clock.nowUtc(),
    );
    await ActivationFinalizationService(
      activeStore: activeStore,
      submissionStore: submissionStore,
      credentialStore: credentialStore,
    ).finalize(record);
    return (await activeStore.read())!;
  }
}
