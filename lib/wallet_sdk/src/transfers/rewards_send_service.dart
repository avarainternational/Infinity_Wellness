import 'package:cryptography/cryptography.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/rewards_amount.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/stellar_activation_protocol.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_send_client.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

final class RewardsSendService {
  RewardsSendService({
    required RewardsSendStore store,
    required CredentialStore credentials,
    required RewardsSendClient client,
    required WalletClock clock,
    required StellarActivationProtocol protocol,
  }) : _store = store,
       _credentials = credentials,
       _client = client,
       _clock = clock,
       _protocol = protocol;
  final RewardsSendStore _store;
  final CredentialStore _credentials;
  final RewardsSendClient _client;
  final WalletClock _clock;
  final StellarActivationProtocol _protocol;
  // Serialize send and reconciliation across SDK instances in this app process.
  static bool _busy = false;

  Future<RewardsTransferOutcome> send({
    required RewardsTransferReview review,
    required ActiveRewardsRecord identity,
    required ProviderConfiguration configuration,
    required String sourceSequence,
    required Future<void> Function() revalidate,
    required bool Function() approvalValid,
    required bool Function() consumeApproval,
  }) async {
    if (_busy) {
      throw _unavailable('A transfer operation is already in progress.');
    }
    _busy = true;
    try {
      if (configuration.environment != identity.environment ||
          review.environment != identity.environment) {
        throw _unavailable(
          'Rewards settings changed. Prepare the transfer again.',
        );
      }
      final RewardsSendRecord? previous = await _store.read();
      if (previous?.isPending ?? false) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsTransferPending,
          safeMessage:
              'A previous transfer needs verification. Check its status before sending again.',
          canRetry: true,
        );
      }
      if (previous?.reviewId == review.reviewId) return outcome(previous!);
      await revalidate();
      if (!approvalValid()) {
        throw _unavailable('Authenticate the exact transfer review again.');
      }
      final String? secret = await _credentials.read(identity.credentialKey);
      if (secret == null) {
        throw _unavailable('Your protected signing account is unavailable.');
      }
      const StrKeyCodec codec = StrKeyCodec();
      final key = await Ed25519().newKeyPairFromSeed(
        codec.decodeEd25519SecretSeed(secret),
      );
      if (codec.encodeEd25519PublicKey((await key.extractPublicKey()).bytes) !=
          identity.accountId) {
        throw _unavailable(
          'Your protected signing account does not match Rewards.',
        );
      }
      final int sequence = (BigInt.parse(sourceSequence) + BigInt.one).toInt();
      final int maxTime = review.expiresAt.millisecondsSinceEpoch ~/ 1000;
      if (_clock.nowUtc().millisecondsSinceEpoch ~/ 1000 >= maxTime ||
          !approvalValid()) {
        throw _unavailable(
          'Transfer approval expired. Prepare the transfer again.',
        );
      }
      final envelope = StellarActivationEnvelope(
        sourceAccount: identity.accountId,
        fee: RewardsAmount.parse(review.maximumFee).toInt(),
        sequenceNumber: sequence,
        minTime: 0,
        maxTime: maxTime,
        operations: <StellarActivationOperation>[
          StellarPaymentOperation(
            destination: review.publicAccount,
            asset: StellarAsset.credit(
              code: identity.assetCode,
              issuer: identity.assetIssuer,
            ),
            amount: RewardsAmount.parse(review.amount).toInt(),
          ),
        ],
      );
      final passphrase = configuration.environment == ProviderEnvironment.test
          ? StellarActivationProtocol.testNetworkPassphrase
          : StellarActivationProtocol.publicNetworkPassphrase;
      final signed = await _protocol.sign(
        envelope,
        secretSeed: secret,
        networkPassphrase: passphrase,
      );
      final String hash = (await _protocol.transactionHash(
        signed,
        passphrase,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final record = RewardsSendRecord(
        reviewId: review.reviewId,
        hash: hash,
        source: identity.accountId,
        recipient: review.publicAccount,
        environment: identity.environment,
        code: identity.assetCode,
        issuer: identity.assetIssuer,
        amount: review.amount,
        fee: envelope.fee,
        sequence: sequence.toString(),
        maxTime: maxTime,
        status: RewardsSendStatus.submitting,
      );
      await _store.write(
        record,
      ); // No POST is permitted before this durable boundary.
      try {
        await revalidate();
      } catch (_) {
        try {
          await _store.write(record.withStatus(RewardsSendStatus.cancelled));
        } catch (_) {
          return outcome(record);
        }
        return outcome(record.withStatus(RewardsSendStatus.cancelled));
      }
      if (!consumeApproval()) {
        try {
          await _store.write(record.withStatus(RewardsSendStatus.cancelled));
        } catch (_) {
          return outcome(record);
        }
        return outcome(record.withStatus(RewardsSendStatus.cancelled));
      }
      try {
        await _client.submit(
          configuration,
          _protocol.encodeEnvelopeBase64(signed),
        );
      } catch (_) {
        /* The transaction may have reached the provider. Reconcile only. */
      }
      return await _reconcile(configuration, record);
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw _unavailable(
        'We could not safely send this transfer. Check its status before trying again.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<RewardsTransferOutcome?> restore(
    ActiveRewardsRecord identity,
    ProviderConfiguration configuration, {
    bool reconcile = false,
  }) async {
    if (_busy) {
      throw _unavailable('A transfer operation is already in progress.');
    }
    _busy = true;
    try {
      final record = await _store.read();
      if (record == null) return null;
      record.validate();
      if (record.source != identity.accountId ||
          record.environment != identity.environment ||
          record.code != identity.assetCode ||
          record.issuer != identity.assetIssuer ||
          configuration.environment != identity.environment) {
        throw _unavailable(
          'Transfer evidence does not match your active Rewards account.',
        );
      }
      return reconcile && record.isPending
          ? await _reconcile(configuration, record)
          : outcome(record);
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw _unavailable(
        'Your saved transfer status is unavailable. Preserve this device and contact App Master.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<RewardsTransferOutcome> _reconcile(
    ProviderConfiguration configuration,
    RewardsSendRecord record,
  ) async {
    RewardsSendLedgerResult result = RewardsSendLedgerResult.pending;
    try {
      result = await _client.reconcile(configuration, record);
    } catch (_) {
      /* Keep durable uncertainty. */
    }
    final status = switch (result) {
      RewardsSendLedgerResult.confirmed => RewardsSendStatus.confirmed,
      RewardsSendLedgerResult.failed => RewardsSendStatus.failed,
      RewardsSendLedgerResult.pending => RewardsSendStatus.uncertain,
    };
    final next = record.withStatus(status);
    try {
      await _store.write(next);
    } catch (_) {
      return outcome(record);
    }
    return outcome(next);
  }

  Future<RewardsTransferOutcome?> resolve(
    ActiveRewardsRecord identity,
    ProviderConfiguration configuration, {
    String? competingHash,
  }) async {
    if (_busy) {
      throw _unavailable('A transfer operation is already in progress.');
    }
    _busy = true;
    try {
      final record = await _store.read();
      if (record == null) return null;
      record.validate();
      if (record.source != identity.accountId ||
          record.environment != identity.environment ||
          configuration.environment != identity.environment ||
          record.code != identity.assetCode ||
          record.issuer != identity.assetIssuer) {
        throw _unavailable(
          'Transfer evidence does not match your Rewards account.',
        );
      }
      if (!record.isPending) return outcome(record);
      final checked = await _reconcile(configuration, record);
      if (checked.state != RewardsTransferState.uncertain) return checked;
      final client = _client;
      if (client is! RewardsSendRecoveryClient) return checked;
      final resolution = await (client as RewardsSendRecoveryClient)
          .resolve(configuration, record, competingHash: competingHash)
          .timeout(const Duration(seconds: 30));
      if (resolution.result == RewardsRecoveryResult.pending ||
          resolution.proof == null) {
        return checked;
      }
      final next = record.withStatus(
        resolution.result == RewardsRecoveryResult.expiredUnused
            ? RewardsSendStatus.cancelled
            : RewardsSendStatus.failed,
        proof: resolution.proof,
      );
      await _store.write(next);
      return outcome(next);
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw _unavailable(
        'Resolution is unavailable. Keep the saved transfer and try again.',
      );
    } finally {
      _busy = false;
    }
  }

  static RewardsTransferOutcome outcome(RewardsSendRecord record) =>
      RewardsTransferOutcome(
        reviewId: record.reviewId,
        transactionHash: record.hash,
        publicAccount: record.recipient,
        assetCode: record.code,
        amount: record.amount,
        resolution: record.resolution,
        state: switch (record.status) {
          RewardsSendStatus.confirmed => RewardsTransferState.confirmed,
          RewardsSendStatus.failed => RewardsTransferState.failed,
          RewardsSendStatus.cancelled => RewardsTransferState.cancelled,
          _ => RewardsTransferState.uncertain,
        },
      );
  static WalletSdkException _unavailable(String message) => WalletSdkException(
    code: WalletSdkFailureCode.rewardsSendUnavailable,
    safeMessage: message,
    canRetry: true,
  );
}
