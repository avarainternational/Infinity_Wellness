import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/rewards_amount.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/stellar_activation_protocol.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

enum RewardsSendLedgerResult { pending, confirmed, failed }

enum RewardsRecoveryResult { pending, expiredUnused, superseded }

final class RewardsSendResolution {
  const RewardsSendResolution(this.result, this.proof);
  final RewardsRecoveryResult result;
  final String? proof;
}

abstract interface class RewardsSendRecoveryClient {
  Future<RewardsSendResolution> resolve(
    ProviderConfiguration configuration,
    RewardsSendRecord record, {
    String? competingHash,
  });
}

abstract interface class RewardsSendClient {
  Future<void> submit(ProviderConfiguration configuration, String envelope);
  Future<RewardsSendLedgerResult> reconcile(
    ProviderConfiguration configuration,
    RewardsSendRecord record,
  );
}

final class DirectRewardsSendClient
    implements RewardsSendClient, RewardsSendRecoveryClient {
  DirectRewardsSendClient({required HorizonHttpClient transport})
    : _transport = transport;
  final HorizonHttpClient _transport;
  final StellarActivationProtocol _protocol = StellarActivationProtocol();

  @override
  Future<RewardsSendResolution> resolve(
    ProviderConfiguration configuration,
    RewardsSendRecord record, {
    String? competingHash,
  }) async {
    const pending = RewardsSendResolution(RewardsRecoveryResult.pending, null);
    try {
      if (configuration.environment != record.environment) return pending;
      if (competingHash != null) {
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(competingHash) ||
            competingHash == record.hash) {
          return pending;
        }
        final response = await _transport.request(
          configuration: configuration,
          pathSegments: ['transactions', competingHash],
          maximumResponseBytes: 128 * 1024,
        );
        if (response.statusCode != 200) return pending;
        final data = response.decodeJson();
        if (data['hash'] != competingHash ||
            data['ledger'] is! int ||
            (data['ledger'] as int) <= 0 ||
            data['successful'] is! bool ||
            data['source_account'] != record.source ||
            data['source_account_sequence'] != record.sequence) {
          return pending;
        }
        final envelope = _protocol.decodeEnvelopeBase64(
          data['envelope_xdr'] as String,
        );
        final passphrase = record.environment == ProviderEnvironment.test
            ? StellarActivationProtocol.testNetworkPassphrase
            : StellarActivationProtocol.publicNetworkPassphrase;
        final actualHash = (await _protocol.transactionHash(
          envelope,
          passphrase,
        )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (actualHash != competingHash ||
            envelope.sourceAccount != record.source ||
            envelope.sequenceNumber.toString() != record.sequence) {
          return pending;
        }
        bool verified = false;
        for (final signature in envelope.signatures) {
          if (await _protocol.verifySignature(
            envelope,
            signature: signature,
            publicAccount: record.source,
            networkPassphrase: passphrase,
          )) {
            verified = true;
          }
        }
        if (!verified) return pending;
        return RewardsSendResolution(
          RewardsRecoveryResult.superseded,
          'A different verified transaction used this transfer sequence: $competingHash',
        );
      }
      // An unchanged source sequence at a consistent ledger whose close time
      // exceeds maxTime proves this envelope was never applied and cannot apply.
      // A 404 or the phone clock alone is insufficient.
      final accountResponse = await _transport.request(
        configuration: configuration,
        pathSegments: ['accounts', record.source],
        maximumResponseBytes: 128 * 1024,
      );
      if (accountResponse.statusCode != 200) return pending;
      String? header;
      for (final entry in accountResponse.headers.entries) {
        if (entry.key.toLowerCase() == 'latest-ledger') header = entry.value;
      }
      final head = int.tryParse(header ?? '');
      if (head == null || head <= 0) return pending;
      final account = accountResponse.decodeJson();
      if (account['account_id'] != record.source) return pending;
      final sequence = BigInt.parse(account['sequence'] as String);
      if (sequence != BigInt.parse(record.sequence) - BigInt.one) {
        return pending;
      }
      final ledgerResponse = await _transport.request(
        configuration: configuration,
        pathSegments: ['ledgers', '$head'],
        maximumResponseBytes: 128 * 1024,
      );
      if (ledgerResponse.statusCode != 200) return pending;
      final ledger = ledgerResponse.decodeJson();
      if (ledger['sequence'] != head ||
          ledger['hash'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(ledger['hash'] as String)) {
        return pending;
      }
      final closed = DateTime.parse(ledger['closed_at'] as String);
      if (!closed.isUtc ||
          closed.millisecondsSinceEpoch ~/ 1000 <= record.maxTime) {
        return pending;
      }
      return RewardsSendResolution(
        RewardsRecoveryResult.expiredUnused,
        'Expired without consuming the account sequence at ledger $head (${ledger['hash']}).',
      );
    } catch (_) {
      return pending;
    }
  }

  @override
  Future<void> submit(
    ProviderConfiguration configuration,
    String envelope,
  ) async {
    // HTTP status alone is never ledger confirmation. No retry in this operation.
    await _transport
        .request(
          configuration: configuration,
          method: 'POST',
          pathSegments: const <String>['transactions'],
          headers: const <String, String>{
            'content-type': 'application/x-www-form-urlencoded',
          },
          formFields: <String, String>{'tx': envelope},
          maximumResponseBytes: 128 * 1024,
        )
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<RewardsSendLedgerResult> reconcile(
    ProviderConfiguration configuration,
    RewardsSendRecord record,
  ) async {
    try {
      return await _lookup(
        configuration,
        record,
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return RewardsSendLedgerResult.pending;
    }
  }

  Future<RewardsSendLedgerResult> _lookup(
    ProviderConfiguration configuration,
    RewardsSendRecord record,
  ) async {
    final result = await _transport.request(
      configuration: configuration,
      pathSegments: <String>['transactions', record.hash],
      maximumResponseBytes: 128 * 1024,
    );
    if (result.statusCode != 200) return RewardsSendLedgerResult.pending;
    final data = result.decodeJson();
    if (data['hash'] != record.hash ||
        data['successful'] is! bool ||
        data['envelope_xdr'] is! String ||
        data['source_account'] != record.source ||
        data['source_account_sequence'] != record.sequence) {
      return RewardsSendLedgerResult.pending;
    }
    final envelope = _protocol.decodeEnvelopeBase64(
      data['envelope_xdr'] as String,
    );
    final passphrase = record.environment == ProviderEnvironment.test
        ? StellarActivationProtocol.testNetworkPassphrase
        : StellarActivationProtocol.publicNetworkPassphrase;
    final hash = (await _protocol.transactionHash(
      envelope,
      passphrase,
    )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (hash != record.hash ||
        envelope.sourceAccount != record.source ||
        envelope.sequenceNumber.toString() != record.sequence ||
        envelope.fee != record.fee ||
        envelope.minTime != 0 ||
        envelope.maxTime != record.maxTime ||
        envelope.operations.length != 1) {
      return RewardsSendLedgerResult.pending;
    }
    final operation = envelope.operations.single;
    if (envelope.signatures.length != 1 ||
        !await _protocol.verifySignature(
          envelope,
          signature: envelope.signatures.single,
          publicAccount: record.source,
          networkPassphrase: passphrase,
        )) {
      return RewardsSendLedgerResult.pending;
    }
    if (operation is! StellarPaymentOperation ||
        operation.sourceAccount != null ||
        operation.destination != record.recipient ||
        operation.asset.code != record.code ||
        operation.asset.issuer != record.issuer ||
        BigInt.from(operation.amount) != RewardsAmount.parse(record.amount)) {
      return RewardsSendLedgerResult.pending;
    }
    return data['successful'] == true
        ? RewardsSendLedgerResult.confirmed
        : RewardsSendLedgerResult.failed;
  }
}
