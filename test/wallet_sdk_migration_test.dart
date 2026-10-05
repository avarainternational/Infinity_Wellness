import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee_wellness/wallet_sdk/src/activation/activation_response_service.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/default_wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/stellar_activation_protocol.dart';
import 'package:employee_wellness/wallet_sdk/src/qr/activation_qr_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_inspection_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_submission_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/configuration_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/activation_reconciliation_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/activation_submission_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/distributor_status_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture f;
  setUp(() async {
    f = await _Fixture.create();
  });

  test('missing signing credential cannot produce active identity', () async {
    final PendingActivationRecord pending = (await PreferencesActivationStore()
        .read())!;
    await const FlutterSecureStorage().delete(key: pending.credentialKey);
    await expectLater(
      f.sdk.getRewardsReceiveIdentity(),
      throwsA(isA<WalletSdkException>()),
    );
    expect(f.active.record, isNull);
    expect(f.submit.calls, 0);
    expect(
      (await f.submission.read())!.status,
      ActivationSubmissionStatus.verified,
    );
  });

  test('altered protected response is rejected before ledger read', () async {
    final ProtectedActivationInspectionStore store =
        ProtectedActivationInspectionStore();
    final Map<String, dynamic> json =
        jsonDecode((await store.readPendingResponse())!)
            as Map<String, dynamic>;
    json['request_id'] = 'ACT-ALTERED';
    await store.savePendingResponse(jsonEncode(json));
    await expectLater(
      f.sdk.getRewardsReceiveIdentity(),
      throwsA(isA<WalletSdkException>()),
    );
    expect(f.active.record, isNull);
    expect(f.reconcile.calls, 0);
  });

  test(
    'migrates expired retained evidence once and preserves rotated provider',
    () async {
      final List<RewardsReceiveView> views = await Future.wait(
        <Future<RewardsReceiveView>>[
          f.sdk.getRewardsReceiveIdentity(),
          f.sdk.getRewardsReceiveIdentity(),
        ],
      );
      expect(views.first.publicAccount, f.builder);
      expect(f.active.record!.assetCode, 'ALT');
      expect(f.reconcile.calls, 1);
      expect(f.reconcile.apiKey, 'new-test-key');
      expect(f.reconcile.minimumRewards, 0);
      expect((await f.configuration.readActive())!.version, 2);
      expect(
        (await f.submission.read())!.status,
        ActivationSubmissionStatus.verified,
      );
      expect(f.submit.calls, 0);
      await f.sdk.getRewardsReceiveIdentity();
      expect(f.reconcile.calls, 1);
    },
  );
  test(
    'missing legacy request stays safely unavailable without account creation',
    () async {
      await PreferencesActivationStore().clear();
      await expectLater(
        f.sdk.getRewardsReceiveIdentity(),
        throwsA(isA<WalletSdkException>()),
      );
      expect(f.active.record, isNull);
      expect(f.reconcile.calls, 0);
      expect(f.submit.calls, 0);
    },
  );
  test(
    'transaction identity mismatch is rejected before ledger read',
    () async {
      final ActivationSubmissionRecord existing = (await f.submission.read())!;
      await f.submission.write(
        ActivationSubmissionRecord(
          responseId: existing.responseId,
          transactionHash: 'b' * 64,
          status: ActivationSubmissionStatus.verified,
        ),
      );
      await expectLater(
        f.sdk.getRewardsReceiveIdentity(),
        throwsA(isA<WalletSdkException>()),
      );
      expect(f.reconcile.calls, 0);
      expect(f.active.record, isNull);
    },
  );
  test('offline migration retains all evidence and can retry', () async {
    f.reconcile.result = ActivationReconciliationResult.pending;
    await expectLater(
      f.sdk.getRewardsReceiveIdentity(),
      throwsA(isA<WalletSdkException>()),
    );
    expect(await PreferencesActivationStore().read(), isNotNull);
    expect(
      await ProtectedActivationInspectionStore().readPendingResponse(),
      isNotNull,
    );
    expect(
      (await f.submission.read())!.status,
      ActivationSubmissionStatus.verified,
    );
    expect(f.active.record, isNull);
    f.reconcile.result = ActivationReconciliationResult.verified;
    await f.sdk.getRewardsReceiveIdentity();
    expect(f.active.record, isNotNull);
    expect(f.submit.calls, 0);
  });
  test(
    'failed protected migration write leaves legacy status and retries',
    () async {
      f.active.fail = true;
      await expectLater(
        f.sdk.getRewardsReceiveIdentity(),
        throwsA(isA<WalletSdkException>()),
      );
      expect(f.active.record, isNull);
      expect(
        (await f.submission.read())!.status,
        ActivationSubmissionStatus.verified,
      );
      f.active.fail = false;
      await f.sdk.getRewardsReceiveIdentity();
      expect(f.active.record, isNotNull);
      expect(f.submit.calls, 0);
    },
  );
}

final class _Fixture {
  _Fixture(
    this.sdk,
    this.active,
    this.reconcile,
    this.submit,
    this.configuration,
    this.submission,
    this.builder,
  );
  final DefaultWalletSdk sdk;
  final _ActiveStore active;
  final _Reconcile reconcile;
  final _Submit submit;
  final ProtectedConfigurationStore configuration;
  final PreferencesActivationSubmissionStore submission;
  final String builder;

  static Future<_Fixture> create() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    DateTime now = DateTime.utc(2026, 9, 19, 12);
    final _ActiveStore active = _ActiveStore();
    final _Reconcile reconcile = _Reconcile();
    final _Submit submit = _Submit();
    final DefaultWalletSdk sdk = DefaultWalletSdk(
      activeRewardsStore: active,
      activationReconciliationClient: reconcile,
      activationSubmissionClient: submit,
      random: Random(7),
      now: () => now,
    );
    final ActivationRequestView view = await sdk.startActivation(
      const BuilderIdentity(displayName: 'Test Builder', phone: '+95912345678'),
    );
    final DecodedActivationRequest request = await ActivationQrCodec()
        .decodeAndValidate(view.qrValue, now: now);
    final WalletKeyPair distributor = await WalletKeyGenerator(
      random: Random(8),
    ).generate();
    final WalletKeyPair issuer = await WalletKeyGenerator(
      random: Random(9),
    ).generate();
    final ActivationResponseView response = await ActivationResponseService()
        .create(
          request: request,
          configuration: ProviderConfiguration(
            endpoint: Uri.parse('https://xlm.nownodes.io'),
            apiKey: 'old-test-key',
            environment: ProviderEnvironment.test,
            version: 1,
          ),
          ledger: DistributorLedgerStatus(
            nativeBalance: 100,
            nativeSellingLiabilities: 0,
            subentryCount: 1,
            sequence: '20',
            nonNativeSpendableBalances: const <double>[100],
            feeP95Stroops: 100,
            nonNativeAssets: <DistributorAssetBalance>[
              DistributorAssetBalance(
                code: 'ALT',
                issuer: issuer.accountId,
                spendable: 100,
              ),
            ],
          ),
          distributorAccount: distributor.accountId,
          distributorSecret: distributor.secretSeed,
          now: now,
          responseId: 'RES-TEST-01',
        );
    await ProtectedActivationInspectionStore().savePendingResponse(
      response.qrValue,
    );
    final Map<String, dynamic> json =
        jsonDecode(response.qrValue) as Map<String, dynamic>;
    final StellarActivationProtocol protocol = StellarActivationProtocol();
    final List<int> hash = await protocol.transactionHash(
      protocol.decodeEnvelopeBase64(json['envelope_xdr'] as String),
      StellarActivationProtocol.testNetworkPassphrase,
    );
    final PreferencesActivationSubmissionStore submission =
        PreferencesActivationSubmissionStore();
    await submission.write(
      ActivationSubmissionRecord(
        responseId: response.responseId,
        transactionHash: hash
            .map((int b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
        status: ActivationSubmissionStatus.verified,
      ),
    );
    final ProtectedConfigurationStore configuration =
        ProtectedConfigurationStore();
    await configuration.savePending(
      ProviderConfiguration(
        endpoint: Uri.parse('https://xlm.nownodes.io'),
        apiKey: 'new-test-key',
        environment: ProviderEnvironment.test,
        version: 2,
      ),
    );
    await configuration.promotePending(now);
    now = DateTime.utc(2026, 10, 3);
    return _Fixture(
      sdk,
      active,
      reconcile,
      submit,
      configuration,
      submission,
      request.activationAddress,
    );
  }
}

final class _ActiveStore implements ActiveRewardsStore {
  bool fail = false;
  ActiveRewardsRecord? record;
  @override
  Future<ActiveRewardsRecord?> read() async => record;
  @override
  Future<void> write(ActiveRewardsRecord value) async {
    if (fail) {
      throw StateError('Simulated failure');
    }
    record = value;
  }
}

final class _Reconcile implements ActivationReconciliationClient {
  int calls = 0;
  String? apiKey;
  double? minimumRewards;
  ActivationReconciliationResult result =
      ActivationReconciliationResult.verified;
  @override
  Future<ActivationReconciliationResult> reconcile({
    required ProviderConfiguration configuration,
    required String transactionHash,
    required String builderAccount,
    required String assetCode,
    required String assetIssuer,
    required double minimumRewards,
  }) async {
    calls++;
    apiKey = configuration.apiKey;
    this.minimumRewards = minimumRewards;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return result;
  }
}

final class _Submit implements ActivationSubmissionClient {
  int calls = 0;
  @override
  Future<ActivationSubmissionResult> submit({
    required ProviderConfiguration configuration,
    required String envelopeXdr,
  }) async {
    calls++;
    return ActivationSubmissionResult.accepted;
  }
}
