import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';

enum ActivationSubmissionResult { accepted, rejected, uncertain }

abstract interface class ActivationSubmissionClient {
  Future<ActivationSubmissionResult> submit({
    required ProviderConfiguration configuration,
    required String envelopeXdr,
  });
}

final class DirectActivationSubmissionClient
    implements ActivationSubmissionClient {
  DirectActivationSubmissionClient({
    http.Client? client,
    HorizonHttpClient? transport,
  }) : _transport = HorizonHttpClient.resolve(
         client: client,
         transport: transport,
       );

  final HorizonHttpClient _transport;

  @override
  Future<ActivationSubmissionResult> submit({
    required ProviderConfiguration configuration,
    required String envelopeXdr,
  }) async {
    try {
      final HorizonHttpResult response = await _transport
          .request(
            configuration: configuration,
            method: 'POST',
            pathSegments: const <String>['transactions'],
            headers: <String, String>{
              'accept': 'application/json',
              'api-key': configuration.apiKey,
              'content-type': 'application/x-www-form-urlencoded',
            },
            formFields: <String, String>{'tx': envelopeXdr},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ActivationSubmissionResult.accepted;
      }
      if (response.statusCode >= 400 &&
          response.statusCode < 500 &&
          response.statusCode != 408 &&
          response.statusCode != 429) {
        return ActivationSubmissionResult.rejected;
      }
      return ActivationSubmissionResult.uncertain;
    } on TimeoutException {
      return ActivationSubmissionResult.uncertain;
    } catch (_) {
      return ActivationSubmissionResult.uncertain;
    }
  }
}
