import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

abstract interface class RewardsRecipientClient {
  Future<String> inspect({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
    required String account,
  });
}

final class DirectRewardsRecipientClient implements RewardsRecipientClient {
  DirectRewardsRecipientClient({required HorizonHttpClient transport})
    : _transport = transport;
  final HorizonHttpClient _transport;

  @override
  Future<String> inspect({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
    required String account,
  }) => _inspect(
    configuration,
    identity,
    account,
  ).timeout(const Duration(seconds: 12));

  Future<String> _inspect(
    ProviderConfiguration configuration,
    ActiveRewardsRecord identity,
    String account,
  ) async {
    const StrKeyCodec().decodeEd25519PublicKey(account);
    final result = await _transport.request(
      configuration: configuration,
      pathSegments: <String>['accounts', account],
      maximumResponseBytes: 128 * 1024,
    );
    if (result.statusCode == 404) {
      _reject('This receiving account does not exist.');
    }
    if (result.statusCode != 200) {
      throw const FormatException('Recipient unavailable.');
    }
    final data = result.decodeJson();
    if (data['account_id'] != account ||
        data['balances'] is! List<dynamic> ||
        data['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid recipient account.');
    }
    // Memo routing is outside the address-only receive contract. Do not guess it.
    if ((data['data'] as Map<String, dynamic>).containsKey(
      'config.memo_required',
    )) {
      _reject(
        'This account requires memo routing, which is not supported yet.',
      );
    }
    if (account == identity.assetIssuer) {
      _reject('Sending Rewards back to the issuer is not supported yet.');
    }
    final matches = <Map<String, dynamic>>[];
    for (final raw in data['balances'] as List<dynamic>) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid trustline.');
      }
      if (raw['asset_code'] == identity.assetCode &&
          raw['asset_issuer'] == identity.assetIssuer) {
        matches.add(raw);
      }
    }
    if (matches.isEmpty) {
      _reject('This account cannot receive your Rewards asset.');
    }
    if (matches.length != 1) {
      throw const FormatException('Duplicate trustline.');
    }
    final line = matches.single;
    if (line['asset_type'] !=
            (identity.assetCode.length <= 4
                ? 'credit_alphanum4'
                : 'credit_alphanum12') ||
        line['is_authorized'] is! bool) {
      throw const FormatException('Invalid trustline.');
    }
    if (line['is_authorized'] != true) {
      _reject('This account is not authorized to receive your Rewards.');
    }
    final limit = _units(line['limit']);
    final balance = _units(line['balance']);
    final liabilities = _units(line['buying_liabilities']);
    if (balance + liabilities > limit) {
      throw const FormatException('Invalid receiving capacity.');
    }
    final capacity = limit - balance - liabilities;
    if (capacity == BigInt.zero) {
      _reject('This account has no remaining Rewards receiving capacity.');
    }
    final scale = BigInt.from(10000000);
    final fraction = (capacity % scale)
        .toString()
        .padLeft(7, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty
        ? '${capacity ~/ scale}'
        : '${capacity ~/ scale}.$fraction';
  }

  BigInt _units(Object? value) {
    if (value is! String ||
        value.length > 30 ||
        !RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]{1,7})?$').hasMatch(value)) {
      throw const FormatException('Invalid amount.');
    }
    final parts = value.split('.');
    final units =
        BigInt.parse(parts[0]) * BigInt.from(10000000) +
        BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(7, '0'));
    if (units > BigInt.parse('9223372036854775807')) {
      throw const FormatException('Amount overflow.');
    }
    return units;
  }

  Never _reject(String message) => throw WalletSdkException(
    code: WalletSdkFailureCode.invalidRewardsRecipient,
    safeMessage: message,
    canRetry: false,
  );
}
