import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/rewards_amount.dart';

final class RewardsLedgerBalance {
  const RewardsLedgerBalance({required this.total, required this.available});
  final String total;
  final String available;
}

abstract interface class RewardsBalanceClient {
  Future<RewardsLedgerBalance> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
  });
}

final class DirectRewardsBalanceClient implements RewardsBalanceClient {
  DirectRewardsBalanceClient({required HorizonHttpClient transport})
    : _transport = transport;
  final HorizonHttpClient _transport;

  @override
  Future<RewardsLedgerBalance> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
  }) => _load(configuration, identity).timeout(const Duration(seconds: 12));

  Future<RewardsLedgerBalance> _load(
    ProviderConfiguration configuration,
    ActiveRewardsRecord identity,
  ) async {
    final HorizonHttpResult result = await _transport.request(
      configuration: configuration,
      pathSegments: <String>['accounts', identity.accountId],
      maximumResponseBytes: 128 * 1024,
    );
    if (result.statusCode != 200) {
      throw const FormatException('Balance unavailable.');
    }
    final Map<String, dynamic> account = result.decodeJson();
    return parseAccount(account, identity);
  }

  static RewardsLedgerBalance parseAccount(
    Map<String, dynamic> account,
    ActiveRewardsRecord identity, {
    bool requireLiabilities = false,
  }) {
    if (account['account_id'] != identity.accountId ||
        account['balances'] is! List<dynamic>) {
      throw const FormatException('Account mismatch.');
    }
    final List<Map<String, dynamic>> matches = <Map<String, dynamic>>[];
    for (final dynamic raw in account['balances'] as List<dynamic>) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid balance.');
      }
      if (raw['asset_code'] == identity.assetCode &&
          raw['asset_issuer'] == identity.assetIssuer) {
        matches.add(raw);
      }
    }
    if (matches.length != 1) {
      throw const FormatException('Rewards asset unavailable.');
    }
    final Map<String, dynamic> balance = matches.single;
    final String expectedType = identity.assetCode.length <= 4
        ? 'credit_alphanum4'
        : 'credit_alphanum12';
    if (balance['asset_type'] != expectedType ||
        balance['is_authorized'] is! bool) {
      throw const FormatException('Invalid Rewards trustline.');
    }
    final BigInt total = RewardsAmount.parse(balance['balance']);
    final BigInt liabilities = RewardsAmount.parse(
      balance['selling_liabilities'] ?? (requireLiabilities ? null : '0'),
    );
    if (liabilities > total) {
      throw const FormatException('Invalid liabilities.');
    }
    final BigInt available = balance['is_authorized'] == true
        ? total - liabilities
        : BigInt.zero;
    return RewardsLedgerBalance(
      total: RewardsAmount.display(total),
      available: RewardsAmount.display(available),
    );
  }
}
