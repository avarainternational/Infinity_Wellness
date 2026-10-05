import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/recovery/rewards_recovery_service.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  test(
    'encrypted backup restores the original key and rejects wrong passwords and changed evidence',
    () async {
      final key = await WalletKeyGenerator(random: Random(101)).generate();
      final issuer = await WalletKeyGenerator(random: Random(102)).generate();
      final identity = ActiveRewardsRecord(
        accountId: key.accountId,
        credentialKey: 'rewards.activation.secret.ACT-RECOVERY',
        environment: ProviderEnvironment.test,
        assetCode: 'PTS',
        assetIssuer: issuer.accountId,
        activationTransactionHash: 'a' * 64,
        responseId: 'RES-RECOVERY',
        verifiedAt: DateTime.utc(2026, 10, 3),
      );
      final credentials = _Credentials();
      await credentials.write(
        key: identity.credentialKey,
        value: key.secretSeed,
      );
      final identities = _Identities(identity);
      final transfers = _Transfers();
      final recovery = RewardsRecoveryService(
        credentials,
        identities,
        transfers,
      );
      const password = 'fixture recovery password';
      final backup = await recovery.create(password);
      expect(backup, startsWith('BRB1.'));
      expect(backup, isNot(contains(key.secretSeed)));
      final imported = await recovery.decode(backup, password);
      expect(imported.identity.encode(), identity.encode());
      expect(imported.secret, key.secretSeed);
      await expectLater(
        recovery.decode(backup, 'different fixture password'),
        throwsA(anything),
      );
      await recovery.confirm(backup, password);
      expect(
        await credentials.read(RewardsRecoveryService.confirmationKey),
        await recovery.confirmation(identity, null),
      );
      transfers.record = RewardsSendRecord(
        reviewId: 'SEND-${'A' * 24}',
        hash: 'b' * 64,
        source: key.accountId,
        recipient: issuer.accountId,
        environment: identity.environment,
        code: identity.assetCode,
        issuer: identity.assetIssuer,
        amount: '1',
        fee: 100,
        sequence: '42',
        maxTime: 2000000000,
        status: RewardsSendStatus.uncertain,
      );
      expect(
        await credentials.read(RewardsRecoveryService.confirmationKey),
        isNot(await recovery.confirmation(identity, transfers.record)),
      );
      await expectLater(
        recovery.confirm(backup, password),
        throwsA(isA<FormatException>()),
      );
      final pendingBackup = await recovery.create(password);
      expect(
        (await recovery.decode(pendingBackup, password)).transfer!.hash,
        transfers.record!.hash,
      );
    },
  );
}

class _Credentials implements CredentialStore {
  final values = <String, String>{};
  @override
  Future<bool> contains(String key) async => values.containsKey(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Identities implements ActiveRewardsStore {
  _Identities(this.record);
  ActiveRewardsRecord? record;
  @override
  Future<ActiveRewardsRecord?> read() async => record;
  @override
  Future<void> write(ActiveRewardsRecord value) async {
    record = value;
  }
}

class _Transfers implements RewardsSendStore {
  RewardsSendRecord? record;
  @override
  Future<RewardsSendRecord?> read() async => record;
  @override
  Future<void> write(RewardsSendRecord value) async {
    record = value;
  }
}
