import 'dart:convert';

import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

final class ProviderConfiguration {
  const ProviderConfiguration({
    required this.endpoint,
    required this.apiKey,
    required this.environment,
    required this.version,
    this.activationFundingUnits = 21000000,
    this.initialRewardsUnits = 10000000,
  });

  final Uri endpoint;
  final String apiKey;
  final ProviderEnvironment environment;
  final int version;
  final int activationFundingUnits;
  final int initialRewardsUnits;

  String encodeProtected() => jsonEncode(<String, Object>{
    'endpoint': endpoint.toString(),
    'api_key': apiKey,
    'environment': environment.name,
    'version': version,
    'activation_funding_units': activationFundingUnits,
    'initial_rewards_units': initialRewardsUnits,
  });

  factory ProviderConfiguration.decodeProtected(String value) {
    final Map<String, dynamic> json = jsonDecode(value) as Map<String, dynamic>;
    return ProviderConfiguration(
      endpoint: Uri.parse(json['endpoint'] as String),
      apiKey: json['api_key'] as String,
      environment: ProviderEnvironment.values.byName(
        json['environment'] as String,
      ),
      version: json['version'] as int,
      activationFundingUnits:
          (json['activation_funding_units'] as int?) ?? 21000000,
      initialRewardsUnits: (json['initial_rewards_units'] as int?) ?? 10000000,
    );
  }
}
