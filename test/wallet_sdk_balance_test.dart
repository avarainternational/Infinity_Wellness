import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_balance_client.dart';
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
    assetCode: 'ALT',
    assetIssuer: issuer,
    activationTransactionHash: 'a' * 64,
    responseId: 'RES-TEST',
    verifiedAt: DateTime.utc(2026, 10, 3),
  );
  final ProviderConfiguration configuration = ProviderConfiguration(
    endpoint: Uri.parse('https://xlm.nownodes.io'),
    apiKey: 'test-private-key',
    environment: identity.environment,
    version: 1,
  );
  Map<String, Object> asset({
    String total = '123456789.1234567',
    String liabilities = '0.0000001',
    bool authorized = true,
  }) => <String, Object>{
    'asset_type': 'credit_alphanum4',
    'asset_code': identity.assetCode,
    'asset_issuer': issuer,
    'balance': total,
    'selling_liabilities': liabilities,
    'is_authorized': authorized,
  };
  Future<RewardsLedgerBalance> load(
    List<Object> balances, {
    String? returnedAccount,
    int status = 200,
  }) async {
    final HorizonHttpClient transport = HorizonHttpClient(
      client: MockClient((http.Request request) async {
        expect(request.url.path, '/accounts/$account');
        expect(request.headers['api-key'], 'test-private-key');
        return http.Response(
          jsonEncode(<String, Object>{
            'account_id': returnedAccount ?? account,
            'balances': balances,
          }),
          status,
        );
      }),
    );
    try {
      return await DirectRewardsBalanceClient(
        transport: transport,
      ).load(configuration: configuration, identity: identity);
    } finally {
      transport.close();
    }
  }

  test('selects App Master asset and subtracts liabilities exactly', () async {
    final RewardsLedgerBalance balance = await load(<Object>[
      <String, Object>{'asset_type': 'native', 'balance': '999'},
      asset(),
    ]);
    expect(balance.total, '123456789.1234567');
    expect(balance.available, '123456789.1234566');
  });
  test(
    'zero is valid and unauthorized trustline has no available Rewards',
    () async {
      expect(
        (await load(<Object>[asset(total: '0', liabilities: '0')])).available,
        '0',
      );
      final RewardsLedgerBalance frozen = await load(<Object>[
        asset(total: '3', liabilities: '0', authorized: false),
      ]);
      expect(frozen.total, '3');
      expect(frozen.available, '0');
    },
  );
  test(
    'rejects missing duplicate wrong-issuer and wrong-account data',
    () async {
      await expectLater(load(<Object>[]), throwsFormatException);
      await expectLater(
        load(<Object>[asset(), asset()]),
        throwsFormatException,
      );
      await expectLater(
        load(<Object>[
          <String, Object>{...asset(), 'asset_issuer': account},
        ]),
        throwsFormatException,
      );
      await expectLater(
        load(<Object>[asset()], returnedAccount: issuer),
        throwsFormatException,
      );
    },
  );
  test(
    'rejects excess precision nonfinite negative and overflowing values',
    () async {
      for (final String amount in <String>[
        '1.00000001',
        'NaN',
        '-1',
        '1e3',
        '922337203685.4775808',
      ]) {
        await expectLater(
          load(<Object>[asset(total: amount, liabilities: '0')]),
          throwsFormatException,
        );
      }
      expect(
        (await load(<Object>[
          asset(total: '922337203685.4775807', liabilities: '0.0000001'),
        ])).available,
        '922337203685.4775806',
      );
    },
  );
  test('rejects invalid liabilities and trustline fields', () async {
    await expectLater(
      load(<Object>[asset(total: '1', liabilities: '2')]),
      throwsFormatException,
    );
    await expectLater(
      load(<Object>[
        <String, Object>{...asset(), 'asset_type': 'native'},
      ]),
      throwsFormatException,
    );
    await expectLater(
      load(<Object>[
        <String, Object>{...asset(), 'is_authorized': 'true'},
      ]),
      throwsFormatException,
    );
    await expectLater(
      load(<Object>[asset()], status: 503),
      throwsFormatException,
    );
  });
}
