import 'package:cryptography/cryptography.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_submission_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';

/// Called only after ledger verification and healthy provider promotion.
/// Failed final status writes retain durable identity for idempotent retry.
final class ActivationFinalizationService {
  ActivationFinalizationService({
    required ActiveRewardsStore activeStore,
    required ActivationSubmissionStore submissionStore,
    required CredentialStore credentialStore,
  }) : _activeStore = activeStore,
       _submissionStore = submissionStore,
       _credentialStore = credentialStore;

  final ActiveRewardsStore _activeStore;
  final ActivationSubmissionStore _submissionStore;
  final CredentialStore _credentialStore;

  Future<void> finalize(ActiveRewardsRecord record) async {
    record.validate();
    final ActivationSubmissionRecord? submission = await _submissionStore
        .read();
    if (submission == null ||
        submission.responseId != record.responseId ||
        submission.transactionHash != record.activationTransactionHash ||
        submission.status == ActivationSubmissionStatus.rejected) {
      throw const FormatException('Activation evidence does not match.');
    }
    final String? secret = await _credentialStore.read(record.credentialKey);
    if (secret == null) {
      throw const FormatException('Activation credential is unavailable.');
    }
    const StrKeyCodec codec = StrKeyCodec();
    final SimpleKeyPair key = await Ed25519().newKeyPairFromSeed(
      codec.decodeEd25519SecretSeed(secret),
    );
    final String account = codec.encodeEd25519PublicKey(
      (await key.extractPublicKey()).bytes,
    );
    if (account != record.accountId) {
      throw const FormatException('Activation credential does not match.');
    }
    final ActiveRewardsRecord? existing = await _activeStore.read();
    if (existing != null &&
        (existing.accountId != record.accountId ||
            existing.credentialKey != record.credentialKey ||
            existing.environment != record.environment ||
            existing.assetCode != record.assetCode ||
            existing.assetIssuer != record.assetIssuer ||
            existing.activationTransactionHash !=
                record.activationTransactionHash ||
            existing.responseId != record.responseId)) {
      throw const FormatException('Active Rewards identity conflict.');
    }
    if (existing == null) {
      await _activeStore.write(record);
    }
    await _submissionStore.write(
      ActivationSubmissionRecord(
        responseId: record.responseId,
        transactionHash: record.activationTransactionHash,
        status: ActivationSubmissionStatus.verified,
      ),
    );
  }
}
