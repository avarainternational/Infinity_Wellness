import 'dart:convert';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/rewards_amount.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';

final class AppMasterRosterService {
  const AppMasterRosterService(this.transport);
  final HorizonHttpClient transport;
  Future<AppMasterRosterPage> load({
    required ProviderConfiguration configuration,
    required String authorityAccount,
    required String assetCode,
    required String assetIssuer,
    required int limit,
    String? cursor,
  }) async {
    try {
      if (limit < 1 || limit > 50) throw const FormatException();
      final scope =
          '${configuration.environment}:${configuration.version}:$authorityAccount:$assetCode:$assetIssuer:$limit';
      String? after;
      if (cursor != null) {
        if (cursor.length > 4096) throw const FormatException();
        final data =
            jsonDecode(
                  utf8.decode(base64Url.decode(base64Url.normalize(cursor))),
                )
                as Map<String, dynamic>;
        if (data['scope'] != scope) throw const FormatException();
        after = data['after'] as String;
        if (after.isEmpty || after.length > 256) throw const FormatException();
      }
      final response = await transport.request(
        configuration: configuration,
        pathSegments: const ['accounts'],
        queryParameters: {
          'asset': '$assetCode:$assetIssuer',
          'limit': '$limit',
          'order': 'asc',
          if (after != null) 'cursor': after,
        },
        maximumResponseBytes: 1024 * 1024,
      );
      if (response.statusCode != 200) throw const FormatException();
      final records =
          (response.decodeJson()['_embedded']
                  as Map<String, dynamic>)['records']
              as List<dynamic>;
      if (records.length > limit) throw const FormatException();
      final entries = <BuilderAccessEntry>[];
      final seen = <String>{};
      String? lastToken;
      for (final raw in records) {
        final account = raw as Map<String, dynamic>;
        final id = account['account_id'] as String;
        const StrKeyCodec().decodeEd25519PublicKey(id);
        if (!seen.add(id)) throw const FormatException();
        final token = account['paging_token'] as String;
        if (token.isEmpty || token.length > 256 || token == after) {
          throw const FormatException();
        }
        lastToken = token;
        final lines = (account['balances'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where(
              (b) =>
                  b['asset_code'] == assetCode &&
                  b['asset_issuer'] == assetIssuer,
            )
            .toList();
        if (lines.length != 1) throw const FormatException();
        final line = lines.single;
        final balance = RewardsAmount.display(
          RewardsAmount.parse(line['balance']),
        );
        final authorized = line['is_authorized'];
        if (authorized is! bool) throw const FormatException();
        entries.add(
          BuilderAccessEntry(
            id: id,
            displayName:
                'Builder ${id.substring(0, 6)}…${id.substring(id.length - 4)}',
            publicAccount: id,
            state: authorized
                ? BuilderAccessState.active
                : BuilderAccessState.suspended,
            updatedAt: DateTime.parse(
              account['last_modified_time'] as String,
            ).toUtc(),
            rewardsBalance: balance,
          ),
        );
      }
      return AppMasterRosterPage(
        environment: configuration.environment,
        authorityAccount: authorityAccount,
        entries: entries,
        observedAt: DateTime.now().toUtc(),
        nextCursor: records.length == limit && lastToken != null
            ? base64Url.encode(
                utf8.encode(jsonEncode({'scope': scope, 'after': lastToken})),
              )
            : null,
      );
    } catch (_) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rosterUnavailable,
        safeMessage: 'Builder Rewards are unavailable. Refresh and try again.',
        canRetry: true,
      );
    }
  }
}
