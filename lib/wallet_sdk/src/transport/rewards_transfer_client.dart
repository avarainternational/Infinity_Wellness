import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/rewards_amount.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/rewards_balance_client.dart';

final class RewardsTransferCost {
  const RewardsTransferCost({
    required this.rewardsBalance,
    required this.feeStroops,
    required this.sequence,
    required this.nativeSpendable,
  });
  final int feeStroops;
  final RewardsLedgerBalance rewardsBalance;
  final String sequence;
  final BigInt nativeSpendable;
}

abstract interface class RewardsTransferClient {
  Future<RewardsTransferCost> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
  });
}

final class DirectRewardsTransferClient implements RewardsTransferClient {
  DirectRewardsTransferClient({required HorizonHttpClient transport})
    : _transport = transport;
  final HorizonHttpClient _transport;

  @override
  Future<RewardsTransferCost> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
  }) => _load(configuration, identity).timeout(const Duration(seconds: 12));

  Future<RewardsTransferCost> _load(
    ProviderConfiguration configuration,
    ActiveRewardsRecord identity,
  ) async {
    final List<HorizonHttpResult> responses = await Future.wait(
      <Future<HorizonHttpResult>>[
        _transport.request(
          configuration: configuration,
          pathSegments: <String>['accounts', identity.accountId],
          maximumResponseBytes: 128 * 1024,
        ),
        _transport.request(
          configuration: configuration,
          pathSegments: const <String>['fee_stats'],
          maximumResponseBytes: 32 * 1024,
        ),
        _transport.request(
          configuration: configuration,
          pathSegments: const <String>['ledgers'],
          queryParameters: const <String, String>{
            'order': 'desc',
            'limit': '1',
          },
          maximumResponseBytes: 32 * 1024,
        ),
      ],
    );
    if (responses.any((HorizonHttpResult r) => r.statusCode != 200)) {
      throw const FormatException('Cost unavailable.');
    }
    final Map<String, dynamic> account = responses[0].decodeJson();
    final Map<String, dynamic> fees = responses[1].decodeJson();
    final Map<String, dynamic> ledgers = responses[2].decodeJson();
    final dynamic records =
        (ledgers['_embedded'] as Map<String, dynamic>)['records'];
    if (records is! List<dynamic> ||
        records.length != 1 ||
        records.single is! Map<String, dynamic>) {
      throw const FormatException('Invalid ledger.');
    }
    final Map<String, dynamic> ledger = records.single as Map<String, dynamic>;
    final int reserve = _integer(ledger['base_reserve_in_stroops']);
    final int baseFee = _integer(ledger['base_fee_in_stroops']);
    final int recentBaseFee = _integer(
      fees['last_ledger_base_fee'],
      string: true,
    );
    final int p95 = _integer(
      (fees['fee_charged'] as Map<String, dynamic>)['p95'],
      string: true,
    );
    final int fee = <int>[
      baseFee,
      recentBaseFee,
      p95,
    ].reduce((int a, int b) => a > b ? a : b);
    if (reserve == 0 || fee == 0 || fee > 0xffffffff) {
      throw const FormatException('Invalid cost.');
    }
    if (account['account_id'] != identity.accountId ||
        account['sequence'] is! String) {
      throw const FormatException('Invalid account.');
    }
    final String sequence = account['sequence'] as String;
    final thresholds = account['thresholds'] as Map<String, dynamic>;
    final int threshold = _integer(thresholds['med_threshold']);
    final signers = account['signers'] as List<dynamic>;
    final matchingSigners = signers
        .where(
          (dynamic raw) =>
              raw is Map<String, dynamic> &&
              raw['key'] == identity.accountId &&
              raw['type'] == 'ed25519_public_key',
        )
        .toList();
    if (matchingSigners.length != 1 ||
        threshold > 255 ||
        _integer((matchingSigners.single as Map<String, dynamic>)['weight']) <
            threshold ||
        _integer((matchingSigners.single as Map<String, dynamic>)['weight']) ==
            0) {
      throw const FormatException('Signing authority unavailable.');
    }
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(sequence) ||
        BigInt.parse(sequence) >= RewardsAmount.maximum) {
      throw const FormatException('Invalid sequence.');
    }
    final int reserveCount =
        2 +
        _integer(account['subentry_count']) +
        _integer(account['num_sponsoring']) -
        _integer(account['num_sponsored']);
    if (reserveCount < 0) throw const FormatException('Invalid sponsorship.');
    final List<dynamic> balances = account['balances'] as List<dynamic>;
    final List<Map<String, dynamic>> native = <Map<String, dynamic>>[];
    for (final dynamic raw in balances) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid balance.');
      }
      if (raw['asset_type'] == 'native') native.add(raw);
    }
    if (native.length != 1) {
      throw const FormatException('Invalid native balance.');
    }
    final BigInt balance = RewardsAmount.parse(native.single['balance']);
    final BigInt liabilities = RewardsAmount.parse(
      native.single['selling_liabilities'],
    );
    if (liabilities > balance) {
      throw const FormatException('Invalid liabilities.');
    }
    return RewardsTransferCost(
      rewardsBalance: DirectRewardsBalanceClient.parseAccount(
        account,
        identity,
        requireLiabilities: true,
      ),
      feeStroops: fee,
      sequence: sequence,
      nativeSpendable:
          balance -
          liabilities -
          BigInt.from(reserveCount) * BigInt.from(reserve),
    );
  }

  int _integer(Object? value, {bool string = false}) {
    if (string) {
      if (value is! String ||
          !RegExp(r'^(0|[1-9][0-9]{0,9})$').hasMatch(value)) {
        throw const FormatException('Invalid integer.');
      }
      value = int.parse(value);
    }
    if (value is! int || value < 0 || value > 0xffffffff) {
      throw const FormatException('Invalid integer.');
    }
    return value;
  }
}
