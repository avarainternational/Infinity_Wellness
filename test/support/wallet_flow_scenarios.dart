import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:employee_wellness/app/constant/routing/app_route.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/main_app.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/default_wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/stellar_activation_protocol.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/activation_submission_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/configuration_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

Future<void> settle(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  do {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    bool busy = false;
    if (Get.isRegistered<WalletController>()) {
      final c = Get.find<WalletController>();
      busy =
          c.isRefreshingBalance.value ||
          c.isInspectingRecipient.value ||
          c.isPreparingTransfer.value ||
          c.isSendingTransfer.value ||
          c.isChangingAccess.value ||
          c.isCheckingTransfer.value ||
          c.isLoadingReceive.value ||
          c.isLoadingHistory.value;
    }
    if (!busy && !tester.binding.hasScheduledFrame) return;
  } while (DateTime.now().isBefore(deadline));
  throw StateError('Controlled flow did not settle.');
}

/// Same scenarios run headlessly and under the device integration binding.
/// Network, OS auth and persistence are controlled; SDK/signing/UI are real.
void registerWalletFlowScenarios() {
  late _Fixture fixture;
  setUp(() async {
    Get.reset();
    fixture = await _Fixture.create();
  });
  tearDown(() async {
    for (final sdk in fixture.instances) {
      await sdk.lockRewards();
    }
    Get.reset();
    fixture.transport.close();
  });

  Future<void> launch(WidgetTester tester) async {
    Get.put<WalletSdk>(fixture.compose(), permanent: true);
    await tester.pumpWidget(const MyApp());
    await settle(tester);
  }

  Future<void> send(WidgetTester tester) async {
    Get.toNamed(Routes.walletSendScan);
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Public receiving account'),
      fixture.recipient,
    );
    await tester.tap(find.text('Check recipient'));
    await settle(tester);
    expect(Get.find<WalletController>().recipientError.value, isEmpty);
    await tester.ensureVisible(find.text('Enter amount'));
    await settle(tester);
    await tester.tap(find.text('Enter amount'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Wellness Points amount'),
      '2.5',
    );
    await tester.ensureVisible(find.text('Prepare transfer review'));
    await settle(tester);
    await tester.tap(find.text('Prepare transfer review'));
    await settle(tester);
    expect(find.text('2.5 RWD'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirm and send'));
    await settle(tester);
    await tester.tap(find.text('Confirm and send'));
    await settle(tester);
  }

  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final sdk in fixture.instances) {
      await sdk.lockRewards();
    }
    Get.reset();
    await launch(tester);
  }

  testWidgets(
    'verified startup receive send history lock removal and restoration',
    (tester) async {
      await launch(tester);
      expect(Get.currentRoute, Routes.walletOverview);
      expect(Get.find<WalletController>().balanceError.value, isEmpty);
      expect(Get.find<WalletController>().isRefreshingBalance.value, false);
      expect(find.text('10 RWD'), findsOneWidget);
      Get.find<WalletController>().openReceive();
      await settle(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(fixture.source), findsOneWidget);
      Get.back<void>();
      await settle(tester);
      await send(tester);
      expect(
        find.text('Wellness Points sent — ledger confirmed'),
        findsOneWidget,
      );
      expect(fixture.posts, 1);
      expect(fixture.auth.calls, 1);
      Get.offAllNamed(Routes.walletOverview);
      await settle(tester);
      expect(find.text('7.5 RWD'), findsOneWidget);
      Get.find<WalletController>().openHistory();
      await settle(tester);
      expect(
        Get.find<WalletController>().historyItems.single.amount,
        '2.5000000',
      );
      await Get.find<WalletController>().openLocked();
      await settle(tester);
      await tester.tap(find.text('Unlock Wellness Points'));
      await settle(tester);
      Get.find<WalletController>().openRemoveWallet();
      await settle(tester);
      await tester.ensureVisible(find.text('Authenticate and disable access'));
      await settle(tester);
      await tester.tap(find.text('Authenticate and disable access'));
      await settle(tester);
      expect(find.text('Restore Wellness Points access'), findsOneWidget);
      await restart(tester);
      expect(Get.currentRoute, Routes.walletLocked);
      await tester.tap(find.text('Restore Wellness Points access'));
      await settle(tester);
      expect(Get.currentRoute, Routes.walletOverview);
      expect(find.text('7.5 RWD'), findsOneWidget);
      expect(fixture.posts, 1);
      expect(
        fixture.credentials.values[fixture.identity.credentialKey],
        isNotNull,
      );
      await Get.find<WalletSdk>().lockRewards();
    },
  );

  testWidgets(
    'uncertain send restart blocks resend and removal then reconciles without POST',
    (tester) async {
      fixture.ledgerVisible = false;
      await launch(tester);
      await send(tester);
      expect(
        Get.find<WalletController>().transferOutcome.value!.state,
        RewardsTransferState.uncertain,
      );
      expect(fixture.posts, 1);
      await restart(tester);
      final sdk = Get.find<WalletSdk>();
      await expectLater(
        sdk.prepareRewardsTransfer(
          publicAccount: fixture.recipient,
          amount: '1',
        ),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.rewardsTransferPending,
          ),
        ),
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
      fixture.ledgerVisible = true;
      await Get.find<WalletController>().openTransferStatus();
      await settle(tester);
      await tester.tap(find.text('Check saved transfer'));
      await settle(tester);
      expect(
        find.text('Wellness Points sent — ledger confirmed'),
        findsOneWidget,
      );
      expect(fixture.posts, 1);
      expect(fixture.auth.calls, 1);
      await Get.find<WalletSdk>().lockRewards();
    },
  );
}

final class _Fixture {
  late ActiveRewardsRecord identity;
  late String source, recipient;
  final _Credentials credentials = _Credentials();
  final _SendStore sends = _SendStore();
  final _Auth auth = _Auth();
  final List<DefaultWalletSdk> instances = <DefaultWalletSdk>[];
  late HorizonHttpClient transport;
  bool ledgerVisible = true;
  int posts = 0;
  String? envelope, hash;
  static Future<_Fixture> create() async {
    final f = _Fixture();
    final generator = WalletKeyGenerator();
    final key = await generator.generate();
    f.source = key.accountId;
    f.recipient = (await generator.generate()).accountId;
    f.identity = ActiveRewardsRecord(
      accountId: f.source,
      credentialKey: 'rewards.activation.secret.ACT-INTEGRATION',
      environment: ProviderEnvironment.test,
      assetCode: 'RWD',
      assetIssuer: (await generator.generate()).accountId,
      activationTransactionHash: 'a' * 64,
      responseId: 'RES-INTEGRATION',
      verifiedAt: DateTime.now().toUtc(),
    );
    f.credentials.values[f.identity.credentialKey] = key.secretSeed;
    f.transport = HorizonHttpClient(client: MockClient(f.respond));
    return f;
  }

  DefaultWalletSdk compose() {
    final sdk = DefaultWalletSdk(
      activeRewardsStore: _Active(identity),
      activationSubmissionStore: _Submission(identity),
      credentialStore: credentials,
      configurationStore: _Config(),
      rewardsSendStore: sends,
      transferAuthenticator: auth,
      horizonHttpClient: transport,
    );
    instances.add(sdk);
    return sdk;
  }

  Future<http.Response> respond(http.Request request) async {
    final parts = request.url.pathSegments;
    Object body;
    if (request.method == 'POST') {
      expect(parts, <String>['transactions']);
      expect(sends.record?.status, RewardsSendStatus.submitting);
      posts++;
      envelope = request.bodyFields['tx']!;
      final protocol = StellarActivationProtocol();
      hash = (await protocol.transactionHash(
        protocol.decodeEnvelopeBase64(envelope!),
        StellarActivationProtocol.testNetworkPassphrase,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hash, sends.record!.hash);
      return http.Response('{}', 200);
    } else if (parts.first == 'transactions') {
      if (!ledgerVisible) return http.Response('{}', 404);
      body = <String, Object>{
        'hash': hash!,
        'successful': true,
        'envelope_xdr': envelope!,
        'source_account': source,
        'source_account_sequence': '124',
      };
    } else if (parts.last == 'payments') {
      body = <String, Object>{
        '_embedded': <String, Object>{
          'records': <Object>[
            if (hash != null && ledgerVisible)
              <String, Object>{
                'id': '100',
                'paging_token': '100',
                'type': 'payment',
                'transaction_successful': true,
                'asset_type': 'credit_alphanum4',
                'asset_code': identity.assetCode,
                'asset_issuer': identity.assetIssuer,
                'from': source,
                'to': recipient,
                'amount': '2.5000000',
                'created_at': DateTime.now().toUtc().toIso8601String(),
              },
          ],
        },
      };
    } else if (parts.first == 'accounts') {
      final account = parts.last;
      body = <String, Object>{
        'account_id': account,
        'data': <String, Object>{},
        'sequence': '123',
        'thresholds': <String, int>{'med_threshold': 1},
        'signers': <Object>[
          <String, Object>{
            'key': account,
            'type': 'ed25519_public_key',
            'weight': 1,
          },
        ],
        'subentry_count': 1,
        'num_sponsoring': 0,
        'num_sponsored': 0,
        'balances': <Object>[
          <String, Object>{
            'asset_type': 'native',
            'balance': '10',
            'selling_liabilities': '0',
          },
          <String, Object>{
            'asset_type': 'credit_alphanum4',
            'asset_code': identity.assetCode,
            'asset_issuer': identity.assetIssuer,
            'balance': account == source && hash != null && ledgerVisible
                ? '7.5'
                : '10',
            'selling_liabilities': '0',
            'buying_liabilities': '0',
            'limit': '100',
            'is_authorized': true,
          },
        ],
      };
    } else if (parts.first == 'fee_stats') {
      body = <String, Object>{
        'last_ledger_base_fee': '100',
        'fee_charged': <String, String>{'p95': '100'},
      };
    } else if (parts.first == 'ledgers') {
      body = <String, Object>{
        '_embedded': <String, Object>{
          'records': <Object>[
            <String, int>{
              'base_reserve_in_stroops': 5000000,
              'base_fee_in_stroops': 100,
            },
          ],
        },
      };
    } else {
      throw StateError('Unexpected controlled endpoint.');
    }
    return http.Response(jsonEncode(body), 200);
  }
}

final class _Auth implements TransferAuthenticator {
  int calls = 0;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return true;
  }

  @override
  Future<void> cancel() async {}
}

final class _Credentials implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> contains(String key) async => values.containsKey(key);
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

final class _SendStore implements RewardsSendStore {
  String? saved;
  RewardsSendRecord? get record =>
      saved == null ? null : RewardsSendRecord.decode(saved!);
  @override
  Future<RewardsSendRecord?> read() async => record;
  @override
  Future<void> write(RewardsSendRecord record) async {
    saved = record.encode();
  }
}

final class _Active implements ActiveRewardsStore {
  _Active(this.record);
  ActiveRewardsRecord record;
  @override
  Future<ActiveRewardsRecord?> read() async => record;
  @override
  Future<void> write(ActiveRewardsRecord value) async {
    record = value;
  }
}

final class _Submission implements ActivationSubmissionStore {
  _Submission(ActiveRewardsRecord active)
    : record = ActivationSubmissionRecord(
        responseId: active.responseId,
        transactionHash: active.activationTransactionHash,
        status: ActivationSubmissionStatus.verified,
      );
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

final class _Config implements ConfigurationStore {
  @override
  Future<ProviderConfiguration?> readActive() async => ProviderConfiguration(
    endpoint: Uri.parse('https://xlm.nownodes.io'),
    apiKey: 'integration-only',
    environment: ProviderEnvironment.test,
    version: 1,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused configuration mutation.');
}
