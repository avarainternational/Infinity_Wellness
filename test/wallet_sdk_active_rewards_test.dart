import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_send_client.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_transfer_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_recipient_client.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/configuration_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_balance_client.dart';
import 'package:employee_wellness/wallet_sdk/src/activation/activation_finalization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/default_wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_submission_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WalletKeyPair key;
  late ActiveRewardsRecord record;
  late _ActiveStore active;
  late _SubmissionStore submission;
  late _Credentials credentials;
  late ActivationFinalizationService service;
  setUp(() async {
    key = await WalletKeyGenerator(random: Random(41)).generate();
    record = ActiveRewardsRecord(
      accountId: key.accountId,
      credentialKey: 'rewards.activation.secret.ACT-TEST',
      environment: ProviderEnvironment.test,
      assetCode: 'RWD',
      assetIssuer: key.accountId,
      activationTransactionHash: 'a' * 64,
      responseId: 'RES-TEST',
      verifiedAt: DateTime.utc(2026, 10, 3),
    );
    active = _ActiveStore();
    submission = _SubmissionStore(
      ActivationSubmissionRecord(
        responseId: record.responseId,
        transactionHash: record.activationTransactionHash,
        status: ActivationSubmissionStatus.uncertain,
      ),
    );
    credentials = _Credentials(key.secretSeed);
    service = ActivationFinalizationService(
      activeStore: active,
      submissionStore: submission,
      credentialStore: credentials,
    );
  });

  test(
    'stores protected identity before verified status and retries idempotently',
    () async {
      submission.beforeWrite = () => expect(active.record, isNotNull);
      await service.finalize(record);
      expect(submission.record!.status, ActivationSubmissionStatus.verified);
      expect(active.writes, 1);
      await service.finalize(record);
      expect(active.writes, 1);
    },
  );

  test('active storage failure does not publish verified status', () async {
    active.failWrite = true;
    await expectLater(service.finalize(record), throwsStateError);
    expect(submission.record!.status, ActivationSubmissionStatus.uncertain);
    expect(active.record, isNull);
  });

  test(
    'SDK removal guards reads and activation across restart; native restore retains account',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await service.finalize(record);
      final config = ProtectedConfigurationStore();
      await config.savePending(
        ProviderConfiguration(
          endpoint: Uri.parse('https://xlm.nownodes.io'),
          apiKey: 'private',
          environment: record.environment,
          version: 1,
        ),
      );
      await config.promotePending(DateTime.utc(2026));
      final auth = _TransferAuthenticator();
      DefaultWalletSdk compose() => DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        credentialStore: credentials,
        configurationStore: config,
        transferAuthenticator: auth,
      );
      final sdk = compose();
      final costs = _TransferClient()..gate = Completer<void>();
      final preparing = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        credentialStore: credentials,
        configurationStore: config,
        rewardsRecipientClient: _RecipientClient(),
        rewardsTransferClient: costs,
      );
      final recipient = (await WalletKeyGenerator(
        random: Random(49),
      ).generate()).accountId;
      final attempt = preparing.prepareRewardsTransfer(
        publicAccount: recipient,
        amount: '1',
      );
      final assertion = expectLater(
        attempt,
        throwsA(isA<WalletSdkException>()),
      );
      while (costs.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await preparing.lockRewards();
      costs.gate!.complete();
      await assertion;
      await sdk.removeRewardsAccess();
      expect(await sdk.getRewardsAccessState(), RewardsAccessState.removed);
      expect(credentials.secret, key.secretSeed);
      final restarted = compose();
      await expectLater(
        restarted.cancelActivation(),
        throwsA(isA<WalletSdkException>()),
      );
      expect(credentials.secret, key.secretSeed);
      expect(
        await restarted.getRewardsAccessState(),
        RewardsAccessState.removed,
      );
      await expectLater(
        restarted.getRewardsBalance(),
        throwsA(isA<WalletSdkException>()),
      );
      await expectLater(
        restarted.getRewardsReceiveIdentity(),
        throwsA(isA<WalletSdkException>()),
      );
      await expectLater(
        restarted.startActivation(
          const BuilderIdentity(displayName: 'Test', phone: '123456789'),
        ),
        throwsA(isA<WalletSdkException>()),
      );
      await restarted.unlockRewards();
      expect(
        await restarted.getRewardsAccessState(),
        RewardsAccessState.unlocked,
      );
      expect(
        (await restarted.getRewardsReceiveIdentity()).publicAccount,
        record.accountId,
      );
      await restarted.lockRewards();
    },
  );

  test('SDK pending evidence blocks removal before native prompt', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await service.finalize(record);
    final config = ProtectedConfigurationStore();
    await config.savePending(
      ProviderConfiguration(
        endpoint: Uri.parse('https://xlm.nownodes.io'),
        apiKey: 'private',
        environment: record.environment,
        version: 1,
      ),
    );
    await config.promotePending(DateTime.utc(2026));
    final auth = _TransferAuthenticator();
    final store = ProtectedRewardsSendStore();
    final recipient = (await WalletKeyGenerator(
      random: Random(48),
    ).generate()).accountId;
    await store.write(
      RewardsSendRecord(
        reviewId: 'SEND-${'A' * 24}',
        hash: 'b' * 64,
        source: record.accountId,
        recipient: recipient,
        environment: record.environment,
        code: record.assetCode,
        issuer: record.assetIssuer,
        amount: '1',
        fee: 100,
        sequence: '2',
        maxTime: 1800000000,
        status: RewardsSendStatus.uncertain,
      ),
    );
    final sdk = DefaultWalletSdk(
      activeRewardsStore: active,
      activationSubmissionStore: submission,
      credentialStore: credentials,
      configurationStore: config,
      transferAuthenticator: auth,
      rewardsSendStore: store,
    );
    await expectLater(
      sdk.removeRewardsAccess(),
      throwsA(
        isA<WalletSdkException>().having(
          (e) => e.code,
          'code',
          WalletSdkFailureCode.rewardsTransferPending,
        ),
      ),
    );
    expect(auth.calls, 0);
    expect((await store.read())!.status, RewardsSendStatus.uncertain);
    expect(credentials.secret, key.secretSeed);
    await sdk.lockRewards();
  });

  test(
    'SDK approve authenticates and sends once, then returns durable status on repeat',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await service.finalize(record);
      final configuration = ProtectedConfigurationStore();
      await configuration.savePending(
        ProviderConfiguration(
          endpoint: Uri.parse('https://xlm.nownodes.io'),
          apiKey: 'private',
          environment: record.environment,
          version: 1,
        ),
      );
      await configuration.promotePending(DateTime.utc(2026));
      final auth = _TransferAuthenticator();
      final sends = _SendClient();
      final sdk = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        credentialStore: credentials,
        configurationStore: configuration,
        rewardsRecipientClient: _RecipientClient(),
        rewardsTransferClient: _TransferClient(),
        transferAuthenticator: auth,
        rewardsSendClient: sends,
      );
      final recipient = (await WalletKeyGenerator(
        random: Random(46),
      ).generate()).accountId;
      final review = await sdk.prepareRewardsTransfer(
        publicAccount: recipient,
        amount: '1',
      );
      final outcome = await sdk.approveRewardsTransfer(review.reviewId);
      expect(outcome.state, RewardsTransferState.confirmed);
      expect(auth.calls, 1);
      expect(sends.posts, 1);
      expect(
        (await sdk.approveRewardsTransfer(review.reviewId)).transactionHash,
        outcome.transactionHash,
      );
      expect(auth.calls, 1);
      expect(sends.posts, 1);
      final restored = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        configurationStore: configuration,
        rewardsSendClient: sends,
      );
      expect(
        (await restored.getRewardsTransferStatus(reconcile: true))!.state,
        RewardsTransferState.confirmed,
      );
      expect(sends.posts, 1);
    },
  );

  test(
    'authorization rereads exact intent before and after the native prompt',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await service.finalize(record);
      final configuration = ProtectedConfigurationStore();
      await configuration.savePending(
        ProviderConfiguration(
          endpoint: Uri.parse('https://xlm.nownodes.io'),
          apiKey: 'private',
          environment: record.environment,
          version: 1,
        ),
      );
      await configuration.promotePending(DateTime.utc(2026));
      final cost = _TransferClient();
      final auth = _TransferAuthenticator();
      final sdk = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        configurationStore: configuration,
        rewardsRecipientClient: _RecipientClient(),
        rewardsTransferClient: cost,
        transferAuthenticator: auth,
      );
      final recipient = (await WalletKeyGenerator(
        random: Random(45),
      ).generate()).accountId;
      var review = await sdk.prepareRewardsTransfer(
        publicAccount: recipient,
        amount: '1',
      );
      cost.sequence = '124';
      await expectLater(
        sdk.authorizeRewardsTransfer(review.reviewId),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.invalidRewardsTransferReview,
          ),
        ),
      );
      expect(auth.calls, 0);
      review = await sdk.prepareRewardsTransfer(
        publicAccount: recipient,
        amount: '1',
      );
      auth.onAuthenticate = () {
        cost.available = '0';
      };
      await expectLater(
        sdk.authorizeRewardsTransfer(review.reviewId),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.invalidRewardsTransferReview,
          ),
        ),
      );
      expect(auth.calls, 1);
      cost.available = '10';
      auth.onAuthenticate = null;
      review = await sdk.prepareRewardsTransfer(
        publicAccount: recipient,
        amount: '1',
      );
      final result = await sdk.authorizeRewardsTransfer(review.reviewId);
      expect(result.reviewId, review.reviewId);
      await sdk.cancelRewardsTransferAuthorization();
      await expectLater(
        sdk.getPreparedRewardsTransfer(review.reviewId),
        throwsA(isA<WalletSdkException>()),
      );
    },
  );

  test(
    'transfer preparation retains exact immutable intent and expires reviews',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await service.finalize(record);
      final configuration = ProtectedConfigurationStore();
      await configuration.savePending(
        ProviderConfiguration(
          endpoint: Uri.parse('https://xlm.nownodes.io'),
          apiKey: 'private',
          environment: record.environment,
          version: 1,
        ),
      );
      await configuration.promotePending(DateTime.utc(2026));
      DateTime now = DateTime.utc(2026, 10, 3);
      final client = _TransferClient();
      final sdk = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        configurationStore: configuration,
        rewardsRecipientClient: _RecipientClient(),
        rewardsTransferClient: client,
        now: () => now,
      );
      final recipient = (await WalletKeyGenerator(
        random: Random(44),
      ).generate()).accountId;
      final review = await sdk.prepareRewardsTransfer(
        publicAccount: recipient,
        amount: '1.2300000',
      );
      expect(review.amount, '1.23');
      expect(review.maximumFee, '0.00002');
      expect(review.assetIssuer, record.assetIssuer);
      expect(
        identical(
          await sdk.getPreparedRewardsTransfer(review.reviewId),
          review,
        ),
        isTrue,
      );
      now = review.expiresAt;
      await expectLater(
        sdk.getPreparedRewardsTransfer(review.reviewId),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.invalidRewardsTransferReview,
          ),
        ),
      );
    },
  );

  test(
    'transfer preparation fails on amount funds capacity and fee insufficiency',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await service.finalize(record);
      final configuration = ProtectedConfigurationStore();
      await configuration.savePending(
        ProviderConfiguration(
          endpoint: Uri.parse('https://xlm.nownodes.io'),
          apiKey: 'private',
          environment: record.environment,
          version: 1,
        ),
      );
      await configuration.promotePending(DateTime.utc(2026));
      final client = _TransferClient();
      final sdk = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        configurationStore: configuration,
        rewardsRecipientClient: _RecipientClient(),
        rewardsTransferClient: client,
      );
      final recipient = (await WalletKeyGenerator(
        random: Random(44),
      ).generate()).accountId;
      for (final amount in <String>[
        '0',
        '-1',
        '1e2',
        '1.00000001',
        'NaN',
        '922337203685.4775808',
      ]) {
        await expectLater(
          sdk.prepareRewardsTransfer(publicAccount: recipient, amount: amount),
          throwsA(
            isA<WalletSdkException>().having(
              (e) => e.code,
              'code',
              WalletSdkFailureCode.invalidRewardsAmount,
            ),
          ),
        );
      }
      expect(client.calls, 0);
      await expectLater(
        sdk.prepareRewardsTransfer(publicAccount: recipient, amount: '11'),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.insufficientRewardsFunds,
          ),
        ),
      );
      client.available = '200';
      await expectLater(
        sdk.prepareRewardsTransfer(publicAccount: recipient, amount: '101'),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.invalidRewardsAmount,
          ),
        ),
      );
      client.nativeSpendable = BigInt.from(199);
      await expectLater(
        sdk.prepareRewardsTransfer(publicAccount: recipient, amount: '1'),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.insufficientRewardsFeeFunds,
          ),
        ),
      );
    },
  );

  test(
    'duplicate preparation is rejected and replacements invalidate old reviews',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await service.finalize(record);
      final configuration = ProtectedConfigurationStore();
      await configuration.savePending(
        ProviderConfiguration(
          endpoint: Uri.parse('https://xlm.nownodes.io'),
          apiKey: 'private',
          environment: record.environment,
          version: 1,
        ),
      );
      await configuration.promotePending(DateTime.utc(2026));
      final client = _TransferClient();
      final sdk = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        configurationStore: configuration,
        rewardsRecipientClient: _RecipientClient(),
        rewardsTransferClient: client,
      );
      final recipient = (await WalletKeyGenerator(
        random: Random(44),
      ).generate()).accountId;
      client.gate = Completer<void>();
      final pending = sdk.prepareRewardsTransfer(
        publicAccount: recipient,
        amount: '1',
      );
      await expectLater(
        sdk.prepareRewardsTransfer(publicAccount: recipient, amount: '2'),
        throwsA(isA<WalletSdkException>()),
      );
      client.gate!.complete();
      final review = await pending;
      client.gate = null;
      await sdk.prepareRewardsTransfer(publicAccount: recipient, amount: '2');
      await expectLater(
        sdk.getPreparedRewardsTransfer(review.reviewId),
        throwsA(isA<WalletSdkException>()),
      );
    },
  );

  test(
    'recipient facade rejects invalid and self addresses, binds identity and redacts failures',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await service.finalize(record);
      final configuration = ProtectedConfigurationStore();
      await configuration.savePending(
        ProviderConfiguration(
          endpoint: Uri.parse('https://xlm.nownodes.io'),
          apiKey: 'private-test-key',
          environment: record.environment,
          version: 1,
        ),
      );
      await configuration.promotePending(DateTime.utc(2026));
      final client = _RecipientClient();
      final sdk = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
        configurationStore: configuration,
        rewardsRecipientClient: client,
      );
      final recipient = (await WalletKeyGenerator(
        random: Random(43),
      ).generate()).accountId;
      for (final input in <String>['invalid', key.accountId]) {
        await expectLater(
          sdk.inspectRewardsRecipient(input),
          throwsA(
            isA<WalletSdkException>().having(
              (e) => e.code,
              'code',
              WalletSdkFailureCode.invalidRewardsRecipient,
            ),
          ),
        );
      }
      expect(client.calls, 0);
      final view = await sdk.inspectRewardsRecipient(' $recipient ');
      expect(view.publicAccount, recipient);
      expect(view.assetCode, record.assetCode);
      expect(client.identity!.assetIssuer, record.assetIssuer);
      client.fail = true;
      await expectLater(
        sdk.inspectRewardsRecipient(recipient),
        throwsA(
          isA<WalletSdkException>()
              .having(
                (e) => e.code,
                'code',
                WalletSdkFailureCode.rewardsRecipientUnavailable,
              )
              .having(
                (e) => e.safeMessage,
                'safe message',
                isNot(contains('private-test-key')),
              ),
        ),
      );
      client.fail = false;
      client.onRead = () {
        active.record = null;
      };
      await expectLater(
        sdk.inspectRewardsRecipient(recipient),
        throwsA(isA<WalletSdkException>()),
      );
    },
  );

  test('balance facade binds network and asset and redacts failures', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await service.finalize(record);
    final ProtectedConfigurationStore configuration =
        ProtectedConfigurationStore();
    await configuration.savePending(
      ProviderConfiguration(
        endpoint: Uri.parse('https://xlm.nownodes.io'),
        apiKey: 'test-private-key',
        environment: record.environment,
        version: 1,
      ),
    );
    await configuration.promotePending(DateTime.utc(2026, 10, 3));
    final _BalanceClient client = _BalanceClient();
    final DefaultWalletSdk sdk = DefaultWalletSdk(
      activeRewardsStore: active,
      activationSubmissionStore: submission,
      configurationStore: configuration,
      rewardsBalanceClient: client,
      now: () => DateTime.utc(2026, 10, 3, 12),
    );
    final RewardsBalanceView view = await sdk.getRewardsBalance();
    expect(client.identity!.assetIssuer, record.assetIssuer);
    expect(view.available, '1.25');
    expect(view.observedAt, DateTime.utc(2026, 10, 3, 12));
    client.fail = true;
    await expectLater(
      sdk.getRewardsBalance(),
      throwsA(
        isA<WalletSdkException>()
            .having(
              (WalletSdkException e) => e.code,
              'code',
              WalletSdkFailureCode.rewardsBalanceUnavailable,
            )
            .having(
              (WalletSdkException e) => e.safeMessage,
              'message',
              isNot(contains('test-private-key')),
            ),
      ),
    );
    await configuration.savePending(
      ProviderConfiguration(
        endpoint: Uri.parse('https://xlm.nownodes.io'),
        apiKey: 'test-private-key',
        environment: ProviderEnvironment.production,
        version: 2,
      ),
    );
    await configuration.promotePending(DateTime.utc(2026, 10, 3));
    await expectLater(
      sdk.getRewardsBalance(),
      throwsA(
        isA<WalletSdkException>().having(
          (WalletSdkException e) => e.code,
          'code',
          WalletSdkFailureCode.rewardsIdentityUnavailable,
        ),
      ),
    );
  });

  test('final status failure keeps identity and recovers on retry', () async {
    submission.failWrite = true;
    await expectLater(service.finalize(record), throwsStateError);
    expect(active.record, isNotNull);
    expect(submission.record!.status, ActivationSubmissionStatus.uncertain);
    submission.failWrite = false;
    await service.finalize(record);
    expect(active.writes, 1);
    expect(submission.record!.status, ActivationSubmissionStatus.verified);
  });

  test('missing and wrong credentials cannot finalize', () async {
    credentials.secret = null;
    await expectLater(service.finalize(record), throwsFormatException);
    credentials.secret = (await WalletKeyGenerator(
      random: Random(42),
    ).generate()).secretSeed;
    await expectLater(service.finalize(record), throwsFormatException);
    expect(active.writes, 0);
  });

  test('mismatched or rejected submission evidence cannot finalize', () async {
    submission.record = ActivationSubmissionRecord(
      responseId: record.responseId,
      transactionHash: 'b' * 64,
      status: ActivationSubmissionStatus.submitted,
    );
    await expectLater(service.finalize(record), throwsFormatException);
    submission.record = ActivationSubmissionRecord(
      responseId: record.responseId,
      transactionHash: record.activationTransactionHash,
      status: ActivationSubmissionStatus.rejected,
    );
    await expectLater(service.finalize(record), throwsFormatException);
    expect(active.writes, 0);
  });

  test('conflicting active identity is preserved', () async {
    final Map<String, dynamic> json =
        jsonDecode(record.encode()) as Map<String, dynamic>;
    json['asset_code'] = 'OTHER';
    active.record = ActiveRewardsRecord.decode(jsonEncode(json));
    await expectLater(service.finalize(record), throwsFormatException);
    expect(active.record!.assetCode, 'OTHER');
    expect(submission.record!.status, ActivationSubmissionStatus.uncertain);
  });

  test(
    'protected identity round trip omits signing secret and provider key',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final ProtectedActiveRewardsStore store = ProtectedActiveRewardsStore();
      await store.write(record);
      expect((await store.read())!.encode(), record.encode());
      final String raw =
          (await const FlutterSecureStorage().readAll()).values.single;
      expect(raw, isNot(contains(key.secretSeed)));
      expect(raw, isNot(contains('api_key')));
    },
  );

  test('rejects unsupported versions and invalid persisted identity', () {
    for (final Map<String, Object> change in <Map<String, Object>>[
      <String, Object>{'version': 2},
      <String, Object>{'account': 'invalid'},
      <String, Object>{'activation_hash': 'short'},
      <String, Object>{'asset_code': 'bad asset'},
      <String, Object>{'credential_key': 'unrelated.key'},
    ]) {
      final Map<String, dynamic> json =
          jsonDecode(record.encode()) as Map<String, dynamic>;
      json.addAll(change);
      expect(
        () => ActiveRewardsRecord.decode(jsonEncode(json)),
        throwsFormatException,
      );
    }
  });

  test(
    'receive uses verified App Master asset and exact public account',
    () async {
      await service.finalize(record);
      final RewardsReceiveView view = await DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
      ).getRewardsReceiveIdentity();
      expect(view.publicAccount, key.accountId);
      expect(view.qrValue, key.accountId);
      expect(view.environment, record.environment);
      expect(view.assetCode, record.assetCode);
    },
  );

  test(
    'receive rejects absent legacy identity and unverified activation',
    () async {
      final DefaultWalletSdk sdk = DefaultWalletSdk(
        activeRewardsStore: active,
        activationSubmissionStore: submission,
      );
      await expectLater(
        sdk.getRewardsReceiveIdentity(),
        throwsA(isA<WalletSdkException>()),
      );
      active.record = record;
      await expectLater(
        sdk.getRewardsReceiveIdentity(),
        throwsA(isA<WalletSdkException>()),
      );
      expect(submission.record!.status, ActivationSubmissionStatus.uncertain);
    },
  );
}

final class _BalanceClient implements RewardsBalanceClient {
  bool fail = false;
  ActiveRewardsRecord? identity;
  @override
  Future<RewardsLedgerBalance> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
  }) async {
    this.identity = identity;
    if (fail) throw StateError('test-private-key');
    return const RewardsLedgerBalance(total: '2', available: '1.25');
  }
}

final class _ActiveStore implements ActiveRewardsStore {
  ActiveRewardsRecord? record;
  int writes = 0;
  bool failWrite = false;
  @override
  Future<ActiveRewardsRecord?> read() async => record;
  @override
  Future<void> write(ActiveRewardsRecord value) async {
    if (failWrite) throw StateError('Simulated failure');
    record = value;
    writes++;
  }
}

final class _SubmissionStore implements ActivationSubmissionStore {
  _SubmissionStore(this.record);
  ActivationSubmissionRecord? record;
  bool failWrite = false;
  void Function()? beforeWrite;
  @override
  Future<ActivationSubmissionRecord?> read() async => record;
  @override
  Future<void> clear() async => record = null;
  @override
  Future<void> write(ActivationSubmissionRecord value) async {
    beforeWrite?.call();
    if (failWrite) throw StateError('Simulated failure');
    record = value;
  }
}

final class _TransferClient implements RewardsTransferClient {
  String sequence = '123';
  String available = '10';
  BigInt nativeSpendable = BigInt.from(1000);
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<RewardsTransferCost> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
  }) async {
    calls++;
    await gate?.future;
    return RewardsTransferCost(
      rewardsBalance: RewardsLedgerBalance(
        total: available,
        available: available,
      ),
      feeStroops: 200,
      sequence: sequence,
      nativeSpendable: nativeSpendable,
    );
  }
}

final class _SendClient implements RewardsSendClient {
  int posts = 0;
  @override
  Future<void> submit(
    ProviderConfiguration configuration,
    String envelope,
  ) async {
    posts++;
  }

  @override
  Future<RewardsSendLedgerResult> reconcile(
    ProviderConfiguration configuration,
    RewardsSendRecord record,
  ) async => RewardsSendLedgerResult.confirmed;
}

final class _TransferAuthenticator implements TransferAuthenticator {
  int calls = 0;
  void Function()? onAuthenticate;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    onAuthenticate?.call();
    return true;
  }

  @override
  Future<void> cancel() async {}
}

final class _RecipientClient implements RewardsRecipientClient {
  int calls = 0;
  bool fail = false;
  ActiveRewardsRecord? identity;
  void Function()? onRead;
  @override
  Future<String> inspect({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
    required String account,
  }) async {
    calls++;
    this.identity = identity;
    if (fail) throw StateError('private-test-key');
    onRead?.call();
    return '100';
  }
}

final class _Credentials implements CredentialStore {
  _Credentials(this.secret);
  String? secret;
  final Map<String, String> accessValues = <String, String>{};
  @override
  Future<String?> read(String key) async =>
      key.startsWith('rewards.activation.secret.') ? secret : accessValues[key];
  @override
  Future<bool> contains(String key) async => secret != null;
  @override
  Future<void> delete(String key) async => secret = null;
  @override
  Future<void> write({required String key, required String value}) async =>
      key.startsWith('rewards.activation.secret.')
      ? secret = value
      : accessValues[key] = value;
}
