import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_history_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  final String account = const StrKeyCodec().encodeEd25519PublicKey(
    List<int>.filled(32, 1),
  );
  final String other = const StrKeyCodec().encodeEd25519PublicKey(
    List<int>.filled(32, 2),
  );
  final ActiveRewardsRecord identity = ActiveRewardsRecord(
    accountId: account,
    credentialKey: 'rewards.activation.secret.ACT-TEST',
    environment: ProviderEnvironment.test,
    assetCode: 'ALT',
    assetIssuer: other,
    activationTransactionHash: 'a' * 64,
    responseId: 'RES-TEST',
    verifiedAt: DateTime.utc(2026, 10, 3),
  );
  final ProviderConfiguration configuration = ProviderConfiguration(
    endpoint: Uri.parse('https://xlm.nownodes.io/base?old=1'),
    apiKey: 'test-key',
    environment: ProviderEnvironment.test,
    version: 1,
  );
  Map<String, Object> payment(String id, {bool outgoing = false}) =>
      <String, Object>{
        'id': id,
        'paging_token': id,
        'type': 'payment',
        'transaction_successful': true,
        'asset_type': 'credit_alphanum4',
        'asset_code': 'ALT',
        'asset_issuer': other,
        'from': outgoing ? account : other,
        'to': outgoing ? other : account,
        'amount': '1.0000001',
        'created_at': '2026-10-03T00:00:00Z',
      };
  http.Response response(List<Object> records) => http.Response(
    jsonEncode(<String, Object>{
      '_embedded': <String, Object>{'records': records},
    }),
    200,
  );
  test(
    'returns scoped descending pages with exact amounts and direction',
    () async {
      final List<http.Request> requests = <http.Request>[];
      final HorizonHttpClient transport = HorizonHttpClient(
        client: MockClient((http.Request request) async {
          requests.add(request);
          return requests.length == 1
              ? response(<Object>[payment('30'), payment('20', outgoing: true)])
              : response(<Object>[payment('10')]);
        }),
      );
      addTearDown(transport.close);
      final DirectRewardsHistoryClient client = DirectRewardsHistoryClient(
        transport: transport,
      );
      final RewardsLedgerHistoryPage first = await client.load(
        configuration: configuration,
        identity: identity,
        limit: 2,
      );
      expect(first.items.first.amount, '1.0000001');
      expect(first.items.first.direction, RewardsHistoryDirection.received);
      expect(first.items.last.direction, RewardsHistoryDirection.sent);
      final RewardsLedgerHistoryPage next = await client.load(
        configuration: configuration,
        identity: identity,
        limit: 2,
        cursor: first.nextCursor,
      );
      expect(next.items.single.id, '10');
      expect(next.nextCursor, isNull);
      expect(requests.last.url.path, '/base/accounts/$account/payments');
      expect(requests.last.url.queryParameters, <String, String>{
        'order': 'desc',
        'limit': '2',
        'include_failed': 'false',
        'cursor': '20',
      });
      expect(requests.last.headers['api-key'], 'test-key');
    },
  );
  test(
    'filtered page advances cursor and empty last page ends pagination',
    () async {
      int calls = 0;
      final HorizonHttpClient transport = HorizonHttpClient(
        client: MockClient(
          (_) async => ++calls == 1
              ? response(<Object>[
                  <String, Object>{...payment('30'), 'asset_code': 'OTHER'},
                ])
              : response(<Object>[]),
        ),
      );
      addTearDown(transport.close);
      final DirectRewardsHistoryClient client = DirectRewardsHistoryClient(
        transport: transport,
      );
      final RewardsLedgerHistoryPage first = await client.load(
        configuration: configuration,
        identity: identity,
        limit: 1,
      );
      expect(first.items, isEmpty);
      expect(first.nextCursor, isNotNull);
      final RewardsLedgerHistoryPage last = await client.load(
        configuration: configuration,
        identity: identity,
        limit: 1,
        cursor: first.nextCursor,
      );
      expect(last.items, isEmpty);
      expect(last.nextCursor, isNull);
    },
  );
  test('rejects malformed and wrong-scope cursor before HTTP', () async {
    int calls = 0;
    final HorizonHttpClient transport = HorizonHttpClient(
      client: MockClient((_) async {
        calls++;
        return response(<Object>[payment('30')]);
      }),
    );
    addTearDown(transport.close);
    final DirectRewardsHistoryClient client = DirectRewardsHistoryClient(
      transport: transport,
    );
    final String cursor = (await client.load(
      configuration: configuration,
      identity: identity,
      limit: 1,
    )).nextCursor!;
    await expectLater(
      client.load(
        configuration: configuration,
        identity: identity,
        limit: 2,
        cursor: cursor,
      ),
      throwsA(isA<WalletSdkException>()),
    );
    await expectLater(
      client.load(
        configuration: configuration,
        identity: identity,
        limit: 1,
        cursor: 'bad',
      ),
      throwsA(isA<WalletSdkException>()),
    );
    expect(calls, 1);
  });
  test('rejects unordered repeated and malformed payment records', () async {
    for (final List<Object> records in <List<Object>>[
      <Object>[payment('10'), payment('20')],
      <Object>[payment('20'), payment('20')],
      <Object>[
        <String, Object>{...payment('20'), 'amount': '1.00000001'},
      ],
      <Object>[
        <String, Object>{...payment('20'), 'transaction_successful': false},
      ],
      <Object>[
        <String, Object>{...payment('20'), 'to': other, 'from': other},
      ],
    ]) {
      final HorizonHttpClient transport = HorizonHttpClient(
        client: MockClient((_) async => response(records)),
      );
      try {
        await expectLater(
          DirectRewardsHistoryClient(
            transport: transport,
          ).load(configuration: configuration, identity: identity, limit: 2),
          throwsFormatException,
        );
      } finally {
        transport.close();
      }
    }
  });
}
