import 'package:http/http.dart' as http;
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

final class DistributorLedgerStatus {
  const DistributorLedgerStatus({
    required this.nativeBalance,
    required this.nativeSellingLiabilities,
    required this.subentryCount,
    required this.sequence,
    required this.nonNativeSpendableBalances,
    required this.feeP95Stroops,
    this.nonNativeAssets = const <DistributorAssetBalance>[],
  });

  final double nativeBalance;
  final double nativeSellingLiabilities;
  final int subentryCount;
  final String sequence;
  final List<double> nonNativeSpendableBalances;
  final int feeP95Stroops;
  final List<DistributorAssetBalance> nonNativeAssets;
}

final class DistributorAssetBalance {
  const DistributorAssetBalance({
    required this.code,
    required this.issuer,
    required this.spendable,
  });

  final String code;
  final String issuer;
  final double spendable;
}

abstract interface class DistributorStatusClient {
  Future<DistributorLedgerStatus> load({
    required ProviderConfiguration configuration,
    required String accountId,
  });
}

final class DirectDistributorStatusClient implements DistributorStatusClient {
  DirectDistributorStatusClient({
    http.Client? client,
    HorizonHttpClient? transport,
  }) : _transport = HorizonHttpClient.resolve(
         client: client,
         transport: transport,
       );

  final HorizonHttpClient _transport;

  @override
  Future<DistributorLedgerStatus> load({
    required ProviderConfiguration configuration,
    required String accountId,
  }) async {
    try {
      final List<HorizonHttpResult> responses = await Future.wait(
        <Future<HorizonHttpResult>>[
          _get(configuration, <String>['accounts', accountId]),
          _get(configuration, const <String>['fee_stats']),
        ],
      ).timeout(const Duration(seconds: 12));
      if (responses.any(
        (HorizonHttpResult response) =>
            response.statusCode != 200 || response.bytes.length > 128 * 1024,
      )) {
        throw _unavailable();
      }
      final Map<String, dynamic> account = responses[0].decodeJson();
      final Map<String, dynamic> fees = responses[1].decodeJson();
      final List<dynamic> balances = account['balances'] as List<dynamic>;
      double? nativeBalance;
      double nativeLiabilities = 0;
      final List<double> rewardsBalances = <double>[];
      final List<DistributorAssetBalance> rewardsAssets =
          <DistributorAssetBalance>[];
      for (final dynamic raw in balances) {
        final Map<String, dynamic> balance = raw as Map<String, dynamic>;
        final double amount = double.parse(balance['balance'] as String);
        final double selling = double.parse(
          (balance['selling_liabilities'] as String?) ?? '0',
        );
        if (balance['asset_type'] == 'native') {
          nativeBalance = amount;
          nativeLiabilities = selling;
        } else {
          final double spendable = (amount - selling).clamp(0, double.infinity);
          rewardsBalances.add(spendable);
          final Object? code = balance['asset_code'];
          final Object? issuer = balance['asset_issuer'];
          if (code is String && issuer is String) {
            rewardsAssets.add(
              DistributorAssetBalance(
                code: code,
                issuer: issuer,
                spendable: spendable,
              ),
            );
          }
        }
      }
      final Map<String, dynamic> feeCharged =
          fees['fee_charged'] as Map<String, dynamic>;
      final String sequence = account['sequence'] as String;
      int.parse(sequence);
      return DistributorLedgerStatus(
        nativeBalance: nativeBalance!,
        nativeSellingLiabilities: nativeLiabilities,
        subentryCount: account['subentry_count'] as int,
        sequence: sequence,
        nonNativeSpendableBalances: rewardsBalances,
        feeP95Stroops: int.parse(feeCharged['p95'] as String),
        nonNativeAssets: rewardsAssets,
      );
    } on WalletSdkException {
      rethrow;
    } catch (_) {
      throw _unavailable();
    }
  }

  Future<HorizonHttpResult> _get(
    ProviderConfiguration configuration,
    List<String> pathSegments,
  ) => _transport.request(
    configuration: configuration,
    pathSegments: pathSegments,
    maximumResponseBytes: 128 * 1024,
  );

  WalletSdkException _unavailable() => const WalletSdkException(
    code: WalletSdkFailureCode.distributorAccountUnavailable,
    safeMessage: 'The activation account status is unavailable. Try again.',
    canRetry: true,
  );
}
