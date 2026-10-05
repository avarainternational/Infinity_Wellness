import 'package:http/http.dart' as http;
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';

enum ActivationReconciliationResult { pending, verified, failed }

abstract interface class ActivationReconciliationClient {
  Future<ActivationReconciliationResult> reconcile({
    required ProviderConfiguration configuration,
    required String transactionHash,
    required String builderAccount,
    required String assetCode,
    required String assetIssuer,
    required double minimumRewards,
  });
}

final class DirectActivationReconciliationClient
    implements ActivationReconciliationClient {
  DirectActivationReconciliationClient({
    http.Client? client,
    HorizonHttpClient? transport,
    this.totalTimeout = const Duration(seconds: 15),
  }) : _transport = HorizonHttpClient.resolve(
         client: client,
         transport: transport,
       );

  final HorizonHttpClient _transport;
  final Duration totalTimeout;

  @override
  Future<ActivationReconciliationResult> reconcile({
    required ProviderConfiguration configuration,
    required String transactionHash,
    required String builderAccount,
    required String assetCode,
    required String assetIssuer,
    required double minimumRewards,
  }) async {
    try {
      return await _reconcile(
        configuration: configuration,
        transactionHash: transactionHash,
        builderAccount: builderAccount,
        assetCode: assetCode,
        assetIssuer: assetIssuer,
        minimumRewards: minimumRewards,
      ).timeout(totalTimeout);
    } catch (_) {
      return ActivationReconciliationResult.pending;
    }
  }

  Future<ActivationReconciliationResult> _reconcile({
    required ProviderConfiguration configuration,
    required String transactionHash,
    required String builderAccount,
    required String assetCode,
    required String assetIssuer,
    required double minimumRewards,
  }) async {
    try {
      final HorizonHttpResult transaction = await _get(configuration, <String>[
        'transactions',
        transactionHash,
      ]);
      if (transaction.statusCode == 404) {
        return ActivationReconciliationResult.pending;
      }
      if (transaction.statusCode != 200 ||
          transaction.bytes.length > 128 * 1024) {
        return ActivationReconciliationResult.pending;
      }
      final Map<String, dynamic> transactionJson = transaction.decodeJson();
      if (transactionJson['successful'] != true) {
        return ActivationReconciliationResult.failed;
      }
      final HorizonHttpResult account = await _get(configuration, <String>[
        'accounts',
        builderAccount,
      ]);
      if (account.statusCode == 404) {
        return ActivationReconciliationResult.pending;
      }
      if (account.statusCode != 200 || account.bytes.length > 128 * 1024) {
        return ActivationReconciliationResult.pending;
      }
      final Map<String, dynamic> accountJson = account.decodeJson();
      if (accountJson['account_id'] != builderAccount) {
        return ActivationReconciliationResult.failed;
      }
      final List<dynamic> balances = accountJson['balances'] as List<dynamic>;
      final bool verified = balances.any((dynamic raw) {
        final Map<String, dynamic> balance = raw as Map<String, dynamic>;
        return balance['asset_code'] == assetCode &&
            balance['asset_issuer'] == assetIssuer &&
            double.parse(balance['balance'] as String) >= minimumRewards;
      });
      return verified
          ? ActivationReconciliationResult.verified
          : ActivationReconciliationResult.failed;
    } catch (_) {
      return ActivationReconciliationResult.pending;
    }
  }

  Future<HorizonHttpResult> _get(
    ProviderConfiguration configuration,
    List<String> segments,
  ) => _transport.request(
    configuration: configuration,
    pathSegments: segments,
    maximumResponseBytes: 128 * 1024,
  );
}
