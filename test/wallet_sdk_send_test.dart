import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/stellar_activation_protocol.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/src/transfers/rewards_send_service.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_send_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WalletKeyPair key, recipient;
  late ActiveRewardsRecord identity;
  late RewardsTransferReview review;
  late ProviderConfiguration configuration;
  late _Store store;
  late _Credentials credentials;
  late _Client client;
  late RewardsSendService service;
  final protocol = StellarActivationProtocol();
  final now = DateTime.utc(2026, 10, 3);
  setUp(() async {
    key = await WalletKeyGenerator(random: Random(61)).generate();
    recipient = await WalletKeyGenerator(random: Random(62)).generate();
    identity = ActiveRewardsRecord(
      accountId: key.accountId,
      credentialKey: 'rewards.activation.secret.ACT-SEND',
      environment: ProviderEnvironment.test,
      assetCode: 'ALT',
      assetIssuer: recipient.accountId,
      activationTransactionHash: 'a' * 64,
      responseId: 'RES-SEND',
      verifiedAt: now,
    );
    review = RewardsTransferReview(
      reviewId: 'SEND-${'A' * 24}',
      publicAccount: recipient.accountId,
      environment: identity.environment,
      assetCode: 'ALT',
      assetIssuer: identity.assetIssuer,
      amount: '1.2345678',
      maximumFee: '0.00002',
      expiresAt: now.add(const Duration(minutes: 2)),
    );
    configuration = ProviderConfiguration(
      endpoint: Uri.parse('https://xlm.nownodes.io'),
      apiKey: 'private-test',
      environment: identity.environment,
      version: 1,
    );
    store = _Store();
    credentials = _Credentials(key.secretSeed);
    client = _Client(store);
    service = RewardsSendService(
      store: store,
      credentials: credentials,
      client: client,
      clock: CallbackWalletClock(() => now),
      protocol: protocol,
    );
  });
  Future<RewardsTransferOutcome> send({
    bool valid = true,
    bool consume = true,
    Future<void> Function()? revalidate,
  }) => service.send(
    review: review,
    identity: identity,
    configuration: configuration,
    sourceSequence: '123',
    revalidate: revalidate ?? () async {},
    approvalValid: () => valid,
    consumeApproval: () => consume,
  );

  test(
    'signs exact one-payment intent and persists hash before a single POST',
    () async {
      final result = await send();
      expect(result.state, RewardsTransferState.confirmed);
      expect(client.posts, 1);
      final envelope = protocol.decodeEnvelopeBase64(client.envelope!);
      expect(envelope.sourceAccount, key.accountId);
      expect(envelope.fee, 200);
      expect(envelope.sequenceNumber, 124);
      expect(envelope.maxTime, review.expiresAt.millisecondsSinceEpoch ~/ 1000);
      expect(envelope.operations.length, 1);
      final payment = envelope.operations.single as StellarPaymentOperation;
      expect(payment.amount, 12345678);
      expect(payment.destination, recipient.accountId);
      expect(payment.asset.code, 'ALT');
      expect(
        await protocol.verifySignature(
          envelope,
          signature: envelope.signatures.single,
          publicAccount: key.accountId,
          networkPassphrase: StellarActivationProtocol.testNetworkPassphrase,
        ),
        isTrue,
      );
      expect(store.record!.encode(), isNot(contains(key.secretSeed)));
      expect(store.record!.encode(), isNot(contains(client.envelope!)));
    },
  );
  test('persistence credential and approval failures never POST', () async {
    store.failAt = 1;
    await expectLater(send(), throwsA(isA<WalletSdkException>()));
    expect(client.posts, 0);
    store.failAt = null;
    credentials.secret = recipient.secretSeed;
    await expectLater(send(), throwsA(isA<WalletSdkException>()));
    expect(client.posts, 0);
    credentials.secret = key.secretSeed;
    await expectLater(send(valid: false), throwsA(isA<WalletSdkException>()));
    expect(client.posts, 0);
    expect((await send(consume: false)).state, RewardsTransferState.cancelled);
    expect(client.posts, 0);
  });
  test(
    'network uncertainty and restart recover by hash only and block new sends',
    () async {
      client.throwPost = true;
      client.result = RewardsSendLedgerResult.pending;
      final result = await send();
      expect(result.state, RewardsTransferState.uncertain);
      expect(store.record!.isPending, isTrue);
      final restarted = RewardsSendService(
        store: store,
        credentials: credentials,
        client: client,
        clock: CallbackWalletClock(() => now),
        protocol: protocol,
      );
      await restarted.restore(identity, configuration, reconcile: true);
      expect(client.posts, 1);
      await expectLater(
        send(),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.rewardsTransferPending,
          ),
        ),
      );
      client.result = RewardsSendLedgerResult.confirmed;
      expect(
        (await restarted.restore(
          identity,
          configuration,
          reconcile: true,
        ))!.state,
        RewardsTransferState.confirmed,
      );
      expect(client.posts, 1);
    },
  );
  test(
    'terminal storage failure retains durable submitting evidence',
    () async {
      store.failAt = 2;
      expect((await send()).state, RewardsTransferState.uncertain);
      expect(store.record!.status, RewardsSendStatus.submitting);
      store.failAt = null;
      expect(
        (await service.restore(
          identity,
          configuration,
          reconcile: true,
        ))!.state,
        RewardsTransferState.confirmed,
      );
      expect(client.posts, 1);
    },
  );
  test('changed review after durable write cancels without POST', () async {
    int checks = 0;
    final result = await send(
      revalidate: () async {
        if (++checks == 2) throw StateError('changed');
      },
    );
    expect(result.state, RewardsTransferState.cancelled);
    expect(client.posts, 0);
  });
  test('concurrent service instances cannot submit twice', () async {
    client.gate = Completer<void>();
    final pending = send();
    await client.started.future;
    await expectLater(send(), throwsA(isA<WalletSdkException>()));
    client.gate!.complete();
    await pending;
    expect(client.posts, 1);
  });
  test('mismatched network prevents signing and submission', () async {
    final data = jsonDecode(identity.encode()) as Map<String, dynamic>;
    data['environment'] = 'production';
    identity = ActiveRewardsRecord.decode(jsonEncode(data));
    await expectLater(send(), throwsA(isA<WalletSdkException>()));
    expect(client.posts, 0);
    expect(store.record, isNull);
  });
  test(
    'configured production network signs with its network passphrase',
    () async {
      final data = jsonDecode(identity.encode()) as Map<String, dynamic>;
      data['environment'] = 'production';
      identity = ActiveRewardsRecord.decode(jsonEncode(data));
      configuration = ProviderConfiguration(
        endpoint: configuration.endpoint,
        apiKey: configuration.apiKey,
        environment: ProviderEnvironment.production,
        version: configuration.version,
      );
      review = RewardsTransferReview(
        reviewId: review.reviewId,
        publicAccount: review.publicAccount,
        environment: ProviderEnvironment.production,
        assetCode: review.assetCode,
        assetIssuer: review.assetIssuer,
        amount: review.amount,
        maximumFee: review.maximumFee,
        expiresAt: review.expiresAt,
      );
      await send();
      expect(client.posts, 1);
      final envelope = protocol.decodeEnvelopeBase64(client.envelope!);
      expect(
        await protocol.verifySignature(
          envelope,
          signature: envelope.signatures.single,
          publicAccount: key.accountId,
          networkPassphrase: StellarActivationProtocol.publicNetworkPassphrase,
        ),
        isTrue,
      );
      expect(
        await protocol.verifySignature(
          envelope,
          signature: envelope.signatures.single,
          publicAccount: key.accountId,
          networkPassphrase: StellarActivationProtocol.testNetworkPassphrase,
        ),
        isFalse,
      );
      final hash = (await protocol.transactionHash(
        envelope,
        StellarActivationProtocol.publicNetworkPassphrase,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(store.record!.hash, hash);
    },
  );
  test(
    'reconciliation verifies exact envelope hash and intent, not HTTP success',
    () async {
      await send();
      final record = store.record!;
      Map<String, dynamic> changes = <String, dynamic>{};
      int status = 200;
      final transport = HorizonHttpClient(
        client: MockClient((request) async {
          expect(request.url.path, '/transactions/${record.hash}');
          return http.Response(
            jsonEncode(<String, Object>{
              'hash': record.hash,
              'successful': true,
              'envelope_xdr': client.envelope!,
              'source_account': key.accountId,
              'source_account_sequence': record.sequence,
              ...changes,
            }),
            status,
          );
        }),
      );
      final direct = DirectRewardsSendClient(transport: transport);
      expect(
        await direct.reconcile(configuration, record),
        RewardsSendLedgerResult.confirmed,
      );
      changes = <String, dynamic>{'successful': false};
      expect(
        await direct.reconcile(configuration, record),
        RewardsSendLedgerResult.failed,
      );
      for (final change in <Map<String, dynamic>>[
        <String, dynamic>{'hash': 'b' * 64},
        <String, dynamic>{'envelope_xdr': 'invalid'},
        <String, dynamic>{'source_account': recipient.accountId},
        <String, dynamic>{'source_account_sequence': '125'},
      ]) {
        changes = change;
        expect(
          await direct.reconcile(configuration, record),
          RewardsSendLedgerResult.pending,
        );
      }
      status = 404;
      expect(
        await direct.reconcile(configuration, record),
        RewardsSendLedgerResult.pending,
      );
      transport.close();
    },
  );
  test(
    'protected store round trip excludes secrets and rejects invalid evidence',
    () async {
      await send();
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final protected = ProtectedRewardsSendStore();
      await protected.write(store.record!);
      expect((await protected.read())!.hash, store.record!.hash);
      final data = jsonDecode(store.record!.encode()) as Map<String, dynamic>;
      data['version'] = 2;
      expect(
        () => RewardsSendRecord.decode(jsonEncode(data)),
        throwsFormatException,
      );
      data['version'] = 1;
      data['hash'] = 'bad';
      expect(
        () => RewardsSendRecord.decode(jsonEncode(data)),
        throwsFormatException,
      );
    },
  );
}

final class _Store implements RewardsSendStore {
  RewardsSendRecord? record;
  int writes = 0;
  int? failAt;
  @override
  Future<RewardsSendRecord?> read() async => record;
  @override
  Future<void> write(RewardsSendRecord value) async {
    if (++writes == failAt) throw StateError('storage');
    record = value;
  }
}

final class _Client implements RewardsSendClient {
  _Client(this.store);
  final _Store store;
  int posts = 0;
  String? envelope;
  bool throwPost = false;
  RewardsSendLedgerResult result = RewardsSendLedgerResult.confirmed;
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<void> submit(
    ProviderConfiguration configuration,
    String envelope,
  ) async {
    expect(store.record!.status, RewardsSendStatus.submitting);
    posts++;
    this.envelope = envelope;
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (throwPost) throw TimeoutException('network');
  }

  @override
  Future<RewardsSendLedgerResult> reconcile(
    ProviderConfiguration configuration,
    RewardsSendRecord record,
  ) async => result;
}

final class _Credentials implements CredentialStore {
  _Credentials(this.secret);
  String? secret;
  @override
  Future<String?> read(String key) async => secret;
  @override
  Future<bool> contains(String key) async => secret != null;
  @override
  Future<void> delete(String key) async => secret = null;
  @override
  Future<void> write({required String key, required String value}) async =>
      secret = value;
}
