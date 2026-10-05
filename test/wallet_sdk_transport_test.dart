import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee_wellness/wallet_sdk/src/authority/distributor_authority_service.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/wallet_key_generator.dart';
import 'package:employee_wellness/wallet_sdk/src/default_wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/activation_reconciliation_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/activation_submission_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/distributor_status_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_health_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ProviderConfiguration configuration = ProviderConfiguration(
    endpoint: Uri.parse('https://xlm.nownodes.io/base?old=1#old'),
    apiKey: 'test-key',
    environment: ProviderEnvironment.test,
    version: 1,
  );
  Matcher failure(HorizonHttpFailure code) => throwsA(
    isA<HorizonHttpException>().having(
      (HorizonHttpException e) => e.failure,
      'failure',
      code,
    ),
  );

  test(
    'joins paths, clears query/fragment, overlays headers and encodes form',
    () async {
      final HorizonHttpClient transport = HorizonHttpClient(
        client: MockClient((http.Request request) async {
          expect(
            request.url,
            Uri.parse('https://xlm.nownodes.io/base/transactions'),
          );
          expect(request.headers['api-key'], 'test-key');
          expect(request.headers['accept'], 'application/hal+json');
          expect(request.bodyFields, <String, String>{'tx': 'a+b/='});
          return http.Response(
            '{}',
            201,
            headers: <String, String>{'x-test': 'yes'},
          );
        }),
      );
      addTearDown(transport.close);
      final HorizonHttpResult result = await transport.request(
        configuration: configuration,
        method: 'POST',
        pathSegments: const <String>['transactions'],
        headers: const <String, String>{'accept': 'application/hal+json'},
        formFields: const <String, String>{'tx': 'a+b/='},
      );
      expect(result.statusCode, 201);
      expect(result.headers['x-test'], 'yes');
      expect(result.decodeJson(), isEmpty);
    },
  );

  test('stream cap accepts exact boundary and rejects excess', () async {
    final HorizonHttpClient transport = HorizonHttpClient(
      client: MockClient.streaming(
        (_, __) async => http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ]),
          200,
        ),
      ),
    );
    addTearDown(transport.close);
    expect(
      (await transport.request(
        configuration: configuration,
        maximumResponseBytes: 4,
      )).bytes,
      <int>[1, 2, 3, 4],
    );
    await expectLater(
      transport.request(configuration: configuration, maximumResponseBytes: 3),
      failure(HorizonHttpFailure.responseTooLarge),
    );
  });

  test('maps send and read timeouts without exposing request data', () async {
    final Completer<http.Response> response = Completer<http.Response>();
    final HorizonHttpClient send = HorizonHttpClient(
      client: MockClient((_) => response.future),
      connectTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(send.close);
    await expectLater(
      send.request(configuration: configuration),
      failure(HorizonHttpFailure.timeout),
    );
    response.complete(http.Response('{}', 200));
    final StreamController<List<int>> stream = StreamController<List<int>>();
    final HorizonHttpClient read = HorizonHttpClient(
      client: MockClient.streaming(
        (_, __) async => http.StreamedResponse(stream.stream, 200),
      ),
      readTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(read.close);
    await expectLater(
      read.request(configuration: configuration),
      failure(HorizonHttpFailure.timeout),
    );
    await stream.close();
  });

  test('maps client and socket network failures', () async {
    for (final Exception error in <Exception>[
      http.ClientException('private'),
      const SocketException('private'),
    ]) {
      final HorizonHttpClient transport = HorizonHttpClient(
        client: MockClient((_) async => throw error),
      );
      addTearDown(transport.close);
      await expectLater(
        transport.request(configuration: configuration),
        failure(HorizonHttpFailure.network),
      );
    }
  });

  test('JSON decoding rejects malformed and non-object bodies', () {
    for (final String body in <String>['broken', '[]', 'null']) {
      expect(
        () => HorizonHttpResult(
          statusCode: 200,
          headers: const <String, String>{},
          bytes: utf8.encode(body),
        ).decodeJson(),
        throwsFormatException,
      );
    }
  });

  test('all consumers reject conflicting injection', () {
    final http.Client client = MockClient(
      (_) async => http.Response('{}', 200),
    );
    final HorizonHttpClient transport = HorizonHttpClient(client: client);
    addTearDown(transport.close);
    for (final Object Function() create in <Object Function()>[
      () => DirectHorizonHealthClient(client: client, transport: transport),
      () => DirectDistributorStatusClient(client: client, transport: transport),
      () => DirectActivationSubmissionClient(
        client: client,
        transport: transport,
      ),
      () => DirectActivationReconciliationClient(
        client: client,
        transport: transport,
      ),
      () => HorizonDistributorAccountVerifier(
        client: client,
        transport: transport,
      ),
    ]) {
      expect(create, throwsArgumentError);
    }
  });

  test('all five consumers delegate through one transport', () async {
    final List<String> paths = <String>[];
    final HorizonHttpClient transport = HorizonHttpClient(
      client: MockClient((http.Request request) async {
        paths.add('${request.method} ${request.url.path}');
        expect(request.headers['api-key'], 'test-key');
        return _response(request, 'builder');
      }),
    );
    addTearDown(transport.close);
    await DirectHorizonHealthClient(transport: transport).check(configuration);
    await HorizonDistributorAccountVerifier(
      transport: transport,
    ).verify(configuration: configuration, accountId: 'builder');
    await DirectDistributorStatusClient(
      transport: transport,
    ).load(configuration: configuration, accountId: 'builder');
    expect(
      await DirectActivationSubmissionClient(
        transport: transport,
      ).submit(configuration: configuration, envelopeXdr: 'test'),
      ActivationSubmissionResult.accepted,
    );
    expect(
      await DirectActivationReconciliationClient(
        transport: transport,
      ).reconcile(
        configuration: configuration,
        transactionHash: 'hash',
        builderAccount: 'builder',
        assetCode: 'RWD',
        assetIssuer: 'issuer',
        minimumRewards: 1,
      ),
      ActivationReconciliationResult.verified,
    );
    expect(paths, <String>[
      'GET /base',
      'GET /base/accounts/builder',
      'GET /base/accounts/builder',
      'GET /base/fee_stats',
      'POST /base/transactions',
      'GET /base/transactions/hash',
      'GET /base/accounts/builder',
    ]);
  });

  test('reconciliation total deadline covers both sequential reads', () async {
    final Completer<http.Response> account = Completer<http.Response>();
    final Completer<void> accountStarted = Completer<void>();
    final HorizonHttpClient transport = HorizonHttpClient(
      client: MockClient((http.Request request) async {
        if (request.url.path.contains('/transactions/')) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response('{"successful":true}', 200);
        }
        accountStarted.complete();
        return account.future;
      }),
    );
    addTearDown(transport.close);
    final Future<ActivationReconciliationResult> result =
        DirectActivationReconciliationClient(
          transport: transport,
          totalTimeout: const Duration(milliseconds: 100),
        ).reconcile(
          configuration: configuration,
          transactionHash: 'hash',
          builderAccount: 'builder',
          assetCode: 'RWD',
          assetIssuer: 'issuer',
          minimumRewards: 1,
        );
    await accountStarted.future;
    expect(
      await result.timeout(const Duration(milliseconds: 500)),
      ActivationReconciliationResult.pending,
    );
    account.complete(http.Response('{}', 404));
  });

  test('oversize reconciliation remains pending', () async {
    final HorizonHttpClient transport = HorizonHttpClient(
      client: MockClient(
        (_) async => http.Response('x' * (128 * 1024 + 1), 200),
      ),
    );
    addTearDown(transport.close);
    expect(
      await DirectActivationReconciliationClient(
        transport: transport,
      ).reconcile(
        configuration: configuration,
        transactionHash: 'hash',
        builderAccount: 'builder',
        assetCode: 'RWD',
        assetIssuer: 'issuer',
        minimumRewards: 1,
      ),
      ActivationReconciliationResult.pending,
    );
  });

  test(
    'SDK composition shares injected transport for health verifier and status',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final WalletKeyPair key = await WalletKeyGenerator(
        random: Random(82),
      ).generate();
      final List<String> paths = <String>[];
      final HorizonHttpClient transport = HorizonHttpClient(
        client: MockClient((http.Request request) async {
          paths.add(request.url.path);
          return _response(request, key.accountId);
        }),
      );
      addTearDown(transport.close);
      final DefaultWalletSdk sdk = DefaultWalletSdk(
        horizonHttpClient: transport,
      );
      await sdk.saveAppMasterProviderConfiguration(
        const ProviderConfigurationInput(
          endpoint: 'https://xlm.nownodes.io',
          apiKey: 'test-key',
          environment: ProviderEnvironment.test,
          version: 1,
        ),
      );
      expect(
        (await sdk.importDistributorSecret(key.secretSeed)).state,
        DistributorAuthorityState.ready,
      );
      await sdk.getAppMasterOverview();
      expect(
        paths
            .where((String p) => p.endsWith('/accounts/${key.accountId}'))
            .length,
        2,
      );
      expect(paths, contains('/fee_stats'));
      expect(paths.first, anyOf('', '/'));
    },
  );
}

http.Response _response(http.Request request, String account) {
  final String path = request.url.path;
  final Map<String, Object> json;
  if (path.contains('/accounts/')) {
    json = <String, Object>{
      'account_id': account,
      'sequence': '1',
      'subentry_count': 1,
      'balances': <Object>[
        <String, Object>{
          'asset_type': 'native',
          'balance': '100',
          'selling_liabilities': '0',
        },
        <String, Object>{
          'asset_type': 'credit_alphanum4',
          'asset_code': 'RWD',
          'asset_issuer': 'issuer',
          'balance': '20',
          'selling_liabilities': '0',
        },
      ],
    };
  } else if (path.endsWith('/fee_stats')) {
    json = <String, Object>{
      'fee_charged': <String, Object>{'p95': '100'},
    };
  } else if (path.contains('/transactions')) {
    json = <String, Object>{'successful': true};
  } else {
    json = <String, Object>{
      'network_passphrase': 'Test SDF Network ; September 2015',
      'horizon_version': 'test',
    };
  }
  return http.Response(
    jsonEncode(json),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
