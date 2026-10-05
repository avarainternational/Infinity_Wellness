import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

/// Ledger-verified identity, separate from temporary activation QR records.
/// This records the activation asset; it does not authorize a daily asset policy.
final class ActiveRewardsRecord {
  const ActiveRewardsRecord({
    required this.accountId,
    required this.credentialKey,
    required this.environment,
    required this.assetCode,
    required this.assetIssuer,
    required this.activationTransactionHash,
    required this.responseId,
    required this.verifiedAt,
  });

  final String accountId;
  final String credentialKey;
  final ProviderEnvironment environment;
  final String assetCode;
  final String assetIssuer;
  final String activationTransactionHash;
  final String responseId;
  final DateTime verifiedAt;

  void validate() {
    const StrKeyCodec codec = StrKeyCodec();
    codec.decodeEd25519PublicKey(accountId);
    codec.decodeEd25519PublicKey(assetIssuer);
    if (!credentialKey.startsWith('rewards.activation.secret.ACT-') ||
        !RegExp(r'^[a-zA-Z0-9]{1,12}$').hasMatch(assetCode) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(activationTransactionHash) ||
        !responseId.startsWith('RES-') ||
        !verifiedAt.isUtc) {
      throw const FormatException('Invalid active Rewards record.');
    }
  }

  String encode() {
    validate();
    return jsonEncode(<String, Object>{
      'version': 1,
      'account': accountId,
      'credential_key': credentialKey,
      'environment': environment.name,
      'asset_code': assetCode,
      'asset_issuer': assetIssuer,
      'activation_hash': activationTransactionHash,
      'response_id': responseId,
      'verified_at': verifiedAt.toIso8601String(),
    });
  }

  factory ActiveRewardsRecord.decode(String encoded) {
    if (encoded.length > 4096) {
      throw const FormatException('Active Rewards record is too large.');
    }
    final Object? value = jsonDecode(encoded);
    if (value is! Map<String, dynamic> || value['version'] != 1) {
      throw const FormatException('Unsupported active Rewards record.');
    }
    final ActiveRewardsRecord record = ActiveRewardsRecord(
      accountId: value['account'] as String,
      credentialKey: value['credential_key'] as String,
      environment: ProviderEnvironment.values.byName(
        value['environment'] as String,
      ),
      assetCode: value['asset_code'] as String,
      assetIssuer: value['asset_issuer'] as String,
      activationTransactionHash: value['activation_hash'] as String,
      responseId: value['response_id'] as String,
      verifiedAt: DateTime.parse(value['verified_at'] as String),
    );
    record.validate();
    return record;
  }
}

abstract interface class ActiveRewardsStore {
  Future<ActiveRewardsRecord?> read();
  Future<void> write(ActiveRewardsRecord record);
}

final class ProtectedActiveRewardsStore implements ActiveRewardsStore {
  ProtectedActiveRewardsStore({FlutterSecureStorage? secureStorage})
    : _storage = secureStorage ?? const FlutterSecureStorage();

  static const String storageKey = 'rewards.active.identity.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<ActiveRewardsRecord?> read() async {
    final String? encoded = await _storage.read(key: storageKey);
    return encoded == null ? null : ActiveRewardsRecord.decode(encoded);
  }

  @override
  Future<void> write(ActiveRewardsRecord record) =>
      _storage.write(key: storageKey, value: record.encode());
}
