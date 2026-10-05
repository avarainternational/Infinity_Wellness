import 'dart:convert';

import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

final class RewardsLedgerHistoryPage {
  RewardsLedgerHistoryPage({required this.items, required this.nextCursor});
  final List<RewardsHistoryItem> items;
  final String? nextCursor;
}

abstract interface class RewardsHistoryClient {
  Future<RewardsLedgerHistoryPage> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
    String? cursor,
    required int limit,
  });
}

final class DirectRewardsHistoryClient implements RewardsHistoryClient {
  DirectRewardsHistoryClient({required HorizonHttpClient transport})
    : _transport = transport;
  final HorizonHttpClient _transport;

  @override
  Future<RewardsLedgerHistoryPage> load({
    required ProviderConfiguration configuration,
    required ActiveRewardsRecord identity,
    String? cursor,
    required int limit,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit');
    }
    String? before;
    if (cursor != null) {
      try {
        if (cursor.length > 2048) {
          throw const FormatException('Cursor too large.');
        }
        final Map<String, dynamic> decoded =
            jsonDecode(
                  utf8.decode(base64Url.decode(base64Url.normalize(cursor))),
                )
                as Map<String, dynamic>;
        if (decoded['v'] != 1 ||
            decoded['scope'] != _scope(identity) ||
            decoded['limit'] != limit) {
          throw const FormatException('Cursor scope mismatch.');
        }
        before = decoded['before'] as String;
        _token(before);
      } catch (_) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.invalidRewardsHistoryCursor,
          safeMessage: 'Refresh Rewards history to continue.',
          canRetry: true,
        );
      }
    }
    final HorizonHttpResult result = await _transport
        .request(
          configuration: configuration,
          pathSegments: <String>['accounts', identity.accountId, 'payments'],
          queryParameters: <String, String>{
            'order': 'desc',
            'limit': '$limit',
            'include_failed': 'false',
            if (before != null) 'cursor': before,
          },
          maximumResponseBytes: 256 * 1024,
        )
        .timeout(const Duration(seconds: 12));
    if (result.statusCode != 200) {
      throw const FormatException('History unavailable.');
    }
    final Map<String, dynamic> json = result.decodeJson();
    final Map<String, dynamic> embedded =
        json['_embedded'] as Map<String, dynamic>;
    final List<dynamic> records = embedded['records'] as List<dynamic>;
    if (records.length > limit) {
      throw const FormatException('Oversized page.');
    }
    final List<RewardsHistoryItem> items = <RewardsHistoryItem>[];
    BigInt? previous = before == null ? null : _token(before);
    String? last;
    for (final dynamic raw in records) {
      final Map<String, dynamic> record = raw as Map<String, dynamic>;
      final String token = record['paging_token'] as String;
      final BigInt position = _token(token);
      if (previous != null && position >= previous) {
        throw const FormatException('Non-progressing page.');
      }
      previous = position;
      last = token;
      // The current product shows confirmed direct Rewards payments only.
      if (record['type'] != 'payment' ||
          record['asset_code'] != identity.assetCode ||
          record['asset_issuer'] != identity.assetIssuer) {
        continue;
      }
      if (record['transaction_successful'] != true) {
        throw const FormatException('Unconfirmed payment.');
      }
      final String expectedType = identity.assetCode.length <= 4
          ? 'credit_alphanum4'
          : 'credit_alphanum12';
      if (record['asset_type'] != expectedType) {
        throw const FormatException('Invalid payment asset.');
      }
      final String from = record['from'] as String;
      final String to = record['to'] as String;
      const StrKeyCodec codec = StrKeyCodec();
      codec.decodeEd25519PublicKey(from);
      codec.decodeEd25519PublicKey(to);
      if (from != identity.accountId && to != identity.accountId) {
        throw const FormatException('Account mismatch.');
      }
      final String amount = record['amount'] as String;
      if (amount.length > 30 ||
          !RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]{1,7})?$').hasMatch(amount)) {
        throw const FormatException('Invalid payment amount.');
      }
      final List<String> parts = amount.split('.');
      final BigInt units =
          BigInt.parse(parts[0]) * BigInt.from(10000000) +
          BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(7, '0'));
      if (units <= BigInt.zero || units > BigInt.parse('9223372036854775807')) {
        throw const FormatException('Payment amount out of range.');
      }
      final String id = record['id'] as String;
      if (id != token) {
        throw const FormatException('Payment identity mismatch.');
      }
      final DateTime created = DateTime.parse(
        record['created_at'] as String,
      ).toUtc();
      items.add(
        RewardsHistoryItem(
          id: id,
          direction: from == to
              ? RewardsHistoryDirection.self
              : (to == identity.accountId
                    ? RewardsHistoryDirection.received
                    : RewardsHistoryDirection.sent),
          amount: amount,
          counterparty: to == identity.accountId ? from : to,
          createdAt: created,
        ),
      );
    }
    return RewardsLedgerHistoryPage(
      items: items,
      nextCursor: records.length == limit && last != null
          ? base64Url.encode(
              utf8.encode(
                jsonEncode(<String, Object>{
                  'v': 1,
                  'scope': _scope(identity),
                  'limit': limit,
                  'before': last,
                }),
              ),
            )
          : null,
    );
  }

  String _scope(ActiveRewardsRecord identity) =>
      '${identity.accountId}:${identity.environment.name}:${identity.assetCode}:${identity.assetIssuer}';
  BigInt _token(String value) {
    if (value.length > 30 || !RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
      throw const FormatException('Invalid paging token.');
    }
    return BigInt.parse(value);
  }
}
