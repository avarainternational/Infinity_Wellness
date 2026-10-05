import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_recipient_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  String address(int byte) =>
      const StrKeyCodec().encodeEd25519PublicKey(List<int>.filled(32, byte));
  final identity = ActiveRewardsRecord(
    accountId: address(1),
    credentialKey: 'rewards.activation.secret.ACT-TEST',
    environment: ProviderEnvironment.test,
    assetCode: 'OTHER',
    assetIssuer: address(2),
    activationTransactionHash: 'a' * 64,
    responseId: 'RES-TEST',
    verifiedAt: DateTime.utc(2026),
  );
  final configuration = ProviderConfiguration(
    endpoint: Uri.parse('https://xlm.nownodes.io'),
    apiKey: 'private-test',
    environment: ProviderEnvironment.test,
    version: 1,
  );
  Map<String, dynamic> trust() => <String, dynamic>{
    'asset_type': 'credit_alphanum12',
    'asset_code': 'OTHER',
    'asset_issuer': address(2),
    'balance': '1.0000001',
    'buying_liabilities': '2.0000001',
    'limit': '10',
    'is_authorized': true,
  };
  Future<String> inspect({
    List<Object>? lines,
    int status = 200,
    Map<String, dynamic>? data,
    String? returnedAccount,
    String? recipient,
  }) async {
    final account = recipient ?? address(3);
    final transport = HorizonHttpClient(
      client: MockClient((request) async {
        expect(request.url.path, '/accounts/$account');
        expect(request.headers['api-key'], 'private-test');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'account_id': returnedAccount ?? account,
            'balances': lines ?? <Object>[trust()],
            'data': data ?? <String, dynamic>{},
          }),
          status,
        );
      }),
    );
    try {
      return await DirectRewardsRecipientClient(transport: transport).inspect(
        configuration: configuration,
        identity: identity,
        account: account,
      );
    } finally {
      transport.close();
    }
  }

  final invalid = isA<WalletSdkException>().having(
    (e) => e.code,
    'code',
    WalletSdkFailureCode.invalidRewardsRecipient,
  );
  test(
    'exact activated asset receiving capacity subtracts buying liabilities',
    () async {
      expect(
        await inspect(
          lines: <Object>[
            <String, dynamic>{'asset_type': 'native'},
            trust(),
          ],
        ),
        '6.9999998',
      );
    },
  );
  test(
    'rejects nonexistent unauthorized missing and full trustlines',
    () async {
      await expectLater(inspect(status: 404), throwsA(invalid));
      await expectLater(inspect(lines: <Object>[]), throwsA(invalid));
      await expectLater(
        inspect(
          lines: <Object>[
            <String, dynamic>{...trust(), 'is_authorized': false},
          ],
        ),
        throwsA(invalid),
      );
      await expectLater(
        inspect(
          lines: <Object>[
            <String, dynamic>{
              ...trust(),
              'balance': '8',
              'buying_liabilities': '2',
            },
          ],
        ),
        throwsA(invalid),
      );
      await expectLater(
        inspect(
          lines: <Object>[
            <String, dynamic>{...trust(), 'asset_issuer': address(4)},
          ],
        ),
        throwsA(invalid),
      );
    },
  );
  test('rejects unsupported issuer returns and memo routing', () async {
    await expectLater(
      inspect(recipient: identity.assetIssuer),
      throwsA(invalid),
    );
    await expectLater(
      inspect(data: <String, dynamic>{'config.memo_required': 'MQ=='}),
      throwsA(invalid),
    );
  });
  test(
    'rejects mismatched duplicate malformed account and trustlines',
    () async {
      await expectLater(
        inspect(returnedAccount: address(4)),
        throwsFormatException,
      );
      await expectLater(
        inspect(lines: <Object>[trust(), trust()]),
        throwsFormatException,
      );
      for (final change in <Map<String, dynamic>>[
        <String, dynamic>{'balance': '1.00000001'},
        <String, dynamic>{'buying_liabilities': null},
        <String, dynamic>{'limit': '922337203685.4775808'},
        <String, dynamic>{'asset_type': 'native'},
        <String, dynamic>{'balance': '11'},
        <String, dynamic>{'is_authorized': 'true'},
      ]) {
        await expectLater(
          inspect(
            lines: <Object>[
              <String, dynamic>{...trust(), ...change},
            ],
          ),
          throwsFormatException,
        );
      }
      await expectLater(inspect(status: 503), throwsFormatException);
    },
  );
}
