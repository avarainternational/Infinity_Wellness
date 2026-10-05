import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/default_wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_submission_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';

const password = 'wellness fixture recovery password';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture f;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    f = await _Fixture.create();
  });
  tearDown(() async {
    for (final sdk in f.instances) {
      await sdk.lockRewards();
    }
  });

  test(
    'verified backup survives permanent removal and restores the same account',
    () async {
      final sdk = f.compose();
      await expectLater(
        sdk.eraseRewardsFromDevice(),
        throwsA(isA<WalletSdkException>()),
      );
      expect(f.credentials.values[f.identity.credentialKey], isNotNull);
      final backup = await sdk.createRewardsBackup(password);
      await sdk.confirmRewardsBackup(backup, password);
      await sdk.eraseRewardsFromDevice();
      expect(f.credentials.values[f.identity.credentialKey], isNull);
      final restarted = f.compose();
      expect(
        await restarted.getRewardsAccessState(),
        RewardsAccessState.removed,
      );
      await expectLater(
        restarted.unlockRewards(),
        throwsA(isA<WalletSdkException>()),
      );
      await expectLater(
        restarted.getRewardsReceiveIdentity(),
        throwsA(isA<WalletSdkException>()),
      );
      await restarted.restoreRewardsBackup(backup, password);
      expect(
        (await restarted.getRewardsReceiveIdentity()).publicAccount,
        f.identity.accountId,
      );
      expect(f.credentials.values[f.identity.credentialKey], isNotNull);
      expect(
        await restarted.getRewardsAccessState(),
        RewardsAccessState.locked,
      );
    },
  );

  test(
    'interrupted key deletion stays disabled across restart and can be restored',
    () async {
      final sdk = f.compose();
      final backup = await sdk.createRewardsBackup(password);
      await sdk.confirmRewardsBackup(backup, password);
      f.credentials.failAfterDelete = true;
      await expectLater(
        sdk.eraseRewardsFromDevice(),
        throwsA(isA<WalletSdkException>()),
      );
      expect(f.credentials.values[f.identity.credentialKey], isNull);
      final restarted = f.compose();
      expect(
        await restarted.getRewardsAccessState(),
        RewardsAccessState.removed,
      );
      await expectLater(
        restarted.unlockRewards(),
        throwsA(isA<WalletSdkException>()),
      );
      f.credentials.failAfterDelete = false;
      await restarted.restoreRewardsBackup(backup, password);
      expect(
        (await restarted.getRewardsReceiveIdentity()).publicAccount,
        f.identity.accountId,
      );
    },
  );

  test('fresh restore retains pending evidence and blocks removal', () async {
    f.transfers.record = f.pending('b');
    final backup = await f.compose().createRewardsBackup(password);
    f.credentials.values.clear();
    f.active.record = null;
    f.submission.record = null;
    f.transfers.record = null;
    final restored = f.compose();
    await restored.restoreRewardsBackup(backup, password);
    expect(
      (await restored.getRewardsReceiveIdentity()).publicAccount,
      f.identity.accountId,
    );
    expect(f.transfers.record?.hash, 'b' * 64);
    expect(f.transfers.record?.isPending, isTrue);
    await expectLater(
      restored.eraseRewardsFromDevice(),
      throwsA(
        isA<WalletSdkException>().having(
          (e) => e.code,
          'code',
          WalletSdkFailureCode.rewardsTransferPending,
        ),
      ),
    );
    expect(f.credentials.values[f.identity.credentialKey], isNotNull);
  });

  test(
    'restore cannot silently discard a different pending transfer from backup',
    () async {
      f.transfers.record = f.pending('b');
      final sdk = f.compose();
      final backup = await sdk.createRewardsBackup(password);
      f.transfers.record = f
          .pending('c')
          .withStatus(RewardsSendStatus.confirmed);
      await expectLater(
        sdk.restoreRewardsBackup(backup, password),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.rewardsTransferPending,
          ),
        ),
      );
      expect(f.transfers.record?.hash, 'c' * 64);
      expect(f.credentials.values[f.identity.credentialKey], isNotNull);
    },
  );
}

class _Fixture {
  late ActiveRewardsRecord identity;
  final credentials = _Credentials();
  final active = _Active();
  final submission = _Submission();
  final transfers = _Transfers();
  final instances = <DefaultWalletSdk>[];

  static Future<_Fixture> create() async {
    final f = _Fixture();
    final key = await WalletKeyGenerator(random: Random(502)).generate();
    f.identity = ActiveRewardsRecord(
      accountId: key.accountId,
      credentialKey: 'rewards.activation.secret.ACT-RECOVERY',
      environment: ProviderEnvironment.test,
      assetCode: 'PTS',
      assetIssuer: key.accountId,
      activationTransactionHash: 'a' * 64,
      responseId: 'RES-RECOVERY',
      verifiedAt: DateTime.utc(2026, 10, 5),
    );
    f.active.record = f.identity;
    f.credentials.values[f.identity.credentialKey] = key.secretSeed;
    f.submission.record = ActivationSubmissionRecord(
      responseId: f.identity.responseId,
      transactionHash: f.identity.activationTransactionHash,
      status: ActivationSubmissionStatus.verified,
    );
    return f;
  }

  DefaultWalletSdk compose() {
    final sdk = DefaultWalletSdk(
      credentialStore: credentials,
      activeRewardsStore: active,
      activationSubmissionStore: submission,
      rewardsSendStore: transfers,
      transferAuthenticator: _Auth(),
    );
    instances.add(sdk);
    return sdk;
  }

  RewardsSendRecord pending(String hashCharacter) => RewardsSendRecord(
    reviewId: 'SEND-${'A' * 24}',
    hash: hashCharacter * 64,
    source: identity.accountId,
    recipient: identity.accountId,
    environment: identity.environment,
    code: identity.assetCode,
    issuer: identity.assetIssuer,
    amount: '1',
    fee: 100,
    sequence: '42',
    maxTime: 2000000000,
    status: RewardsSendStatus.uncertain,
  );
}

class _Auth implements TransferAuthenticator {
  @override
  Future<bool> authenticate(String reason) async => true;
  @override
  Future<void> cancel() async {}
}

class _Credentials implements CredentialStore {
  final values = <String, String>{};
  bool failAfterDelete = false;
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
    if (failAfterDelete) throw StateError('Interrupted deletion');
  }
}

class _Active implements ActiveRewardsStore {
  ActiveRewardsRecord? record;
  @override
  Future<ActiveRewardsRecord?> read() async => record;
  @override
  Future<void> write(ActiveRewardsRecord value) async {
    record = value;
  }
}

class _Submission implements ActivationSubmissionStore {
  ActivationSubmissionRecord? record;
  @override
  Future<ActivationSubmissionRecord?> read() async => record;
  @override
  Future<void> write(ActivationSubmissionRecord value) async {
    record = value;
  }

  @override
  Future<void> clear() async {
    record = null;
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
