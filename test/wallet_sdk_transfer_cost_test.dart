import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_transfer_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  final String account = const StrKeyCodec().encodeEd25519PublicKey(
    List<int>.filled(32, 1),
  );
  final String issuer = const StrKeyCodec().encodeEd25519PublicKey(
    List<int>.filled(32, 2),
  );
  final ActiveRewardsRecord identity = ActiveRewardsRecord(
    accountId: account,
    credentialKey: 'rewards.activation.secret.ACT-TEST',
    environment: ProviderEnvironment.test,
    assetCode: 'RWD',
    assetIssuer: issuer,
    activationTransactionHash: 'a' * 64,
    responseId: 'RES-TEST',
    verifiedAt: DateTime.utc(2026),
  );
  final ProviderConfiguration config = ProviderConfiguration(
    endpoint: Uri.parse('https://xlm.nownodes.io'),
    apiKey: 'private',
    environment: identity.environment,
    version: 1,
  );
  Future<RewardsTransferCost> load({
    Map<String, dynamic>? changes,
    String p95 = '200',
    int reserve = 5000000,
    int baseFee = 100,
  }) async {
    final Map<String, dynamic> source = <String, dynamic>{
      'account_id': account,
      'thresholds': <String, int>{'med_threshold': 1},
      'signers': <Object>[
        <String, Object>{
          'key': account,
          'type': 'ed25519_public_key',
          'weight': 1,
        },
      ],
      'sequence': '123',
      'subentry_count': 3,
      'num_sponsoring': 2,
      'num_sponsored': 1,
      'balances': <Object>[
        <String, Object>{
          'asset_type': 'native',
          'balance': '4.0000001',
          'selling_liabilities': '0.5',
        },
        <String, Object>{
          'asset_type': 'credit_alphanum4',
          'asset_code': 'RWD',
          'asset_issuer': issuer,
          'balance': '10',
          'selling_liabilities': '2',
          'is_authorized': true,
        },
      ],
      ...?changes,
    };
    final HorizonHttpClient transport = HorizonHttpClient(
      client: MockClient((request) async {
        expect(request.headers['api-key'], 'private');
        final Object response;
        switch (request.url.pathSegments.first) {
          case 'accounts':
            expect(request.url.pathSegments.last, account);
            response = source;
          case 'fee_stats':
            response = <String, Object>{
              'last_ledger_base_fee': '150',
              'fee_charged': <String, String>{'p95': p95},
            };
          case 'ledgers':
            expect(request.url.queryParameters, <String, String>{
              'order': 'desc',
              'limit': '1',
            });
            response = <String, Object>{
              '_embedded': <String, Object>{
                'records': <Object>[
                  <String, int>{
                    'base_reserve_in_stroops': reserve,
                    'base_fee_in_stroops': baseFee,
                  },
                ],
              },
            };
          default:
            throw StateError('Unexpected endpoint.');
        }
        return http.Response(jsonEncode(response), 200);
      }),
    );
    try {
      return await DirectRewardsTransferClient(
        transport: transport,
      ).load(configuration: config, identity: identity);
    } finally {
      transport.close();
    }
  }

  test(
    'reserves sponsorship and liabilities exactly and selects maximum fee bid',
    () async {
      final RewardsTransferCost cost = await load();
      expect(cost.nativeSpendable, BigInt.from(5000001));
      expect(cost.feeStroops, 200);
      expect(cost.sequence, '123');
      expect(cost.rewardsBalance.available, '8');
      expect((await load(baseFee: 300)).feeStroops, 300);
      expect((await load(p95: '100')).feeStroops, 150);
    },
  );
  test(
    'rejects malformed sponsorship sequence fees and ledger reserve',
    () async {
      for (final Map<String, dynamic> change in <Map<String, dynamic>>[
        <String, dynamic>{'num_sponsored': null},
        <String, dynamic>{'num_sponsored': 100},
        <String, dynamic>{'sequence': '9223372036854775807'},
        <String, dynamic>{'subentry_count': -1},
        <String, dynamic>{'account_id': issuer},
        <String, dynamic>{'balances': <Object>[]},
      ]) {
        await expectLater(load(changes: change), throwsFormatException);
      }
      await expectLater(load(p95: '4294967296'), throwsFormatException);
      await expectLater(load(p95: 'NaN'), throwsFormatException);
      await expectLater(load(reserve: 0), throwsFormatException);
    },
  );
}
