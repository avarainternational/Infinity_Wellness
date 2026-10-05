import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';

enum HorizonHttpFailure { timeout, network, responseTooLarge }

final class HorizonHttpException implements Exception {
  const HorizonHttpException(this.failure);

  final HorizonHttpFailure failure;
}

final class HorizonHttpResult {
  HorizonHttpResult({
    required this.statusCode,
    required Map<String, String> headers,
    required List<int> bytes,
  }) : headers = Map<String, String>.unmodifiable(headers),
       bytes = List<int>.unmodifiable(bytes);

  final int statusCode;
  final Map<String, String> headers;
  final List<int> bytes;

  Map<String, dynamic> decodeJson() {
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }
}

/// Private request mechanics only: consumers own retries and domain outcomes.
final class HorizonHttpClient {
  HorizonHttpClient({
    http.Client? client,
    this.connectTimeout = const Duration(seconds: 5),
    this.readTimeout = const Duration(seconds: 5),
  }) : _client =
           client ?? IOClient(HttpClient()..connectionTimeout = connectTimeout);

  final http.Client _client;
  final Duration connectTimeout;
  final Duration readTimeout;

  static HorizonHttpClient resolve({
    HorizonHttpClient? transport,
    http.Client? client,
    Duration connectTimeout = const Duration(seconds: 5),
    Duration readTimeout = const Duration(seconds: 5),
  }) {
    if (transport != null && client != null) {
      throw ArgumentError('Supply either transport or client.');
    }
    return transport ??
        HorizonHttpClient(
          client: client,
          connectTimeout: connectTimeout,
          readTimeout: readTimeout,
        );
  }

  Future<HorizonHttpResult> request({
    required ProviderConfiguration configuration,
    String method = 'GET',
    List<String> pathSegments = const <String>[],
    Map<String, String> queryParameters = const <String, String>{},
    Map<String, String> headers = const <String, String>{},
    Map<String, String>? formFields,
    int? maximumResponseBytes,
  }) async {
    if (maximumResponseBytes != null && maximumResponseBytes <= 0) {
      throw ArgumentError.value(maximumResponseBytes, 'maximumResponseBytes');
    }
    final Uri endpoint = Uri(
      scheme: configuration.endpoint.scheme,
      userInfo: configuration.endpoint.userInfo,
      host: configuration.endpoint.host,
      port: configuration.endpoint.hasPort ? configuration.endpoint.port : null,
      pathSegments: <String>[
        ...configuration.endpoint.pathSegments.where(
          (String s) => s.isNotEmpty,
        ),
        ...pathSegments,
      ],
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final http.Request request = http.Request(method, endpoint)
      ..headers.addAll(<String, String>{
        'accept': 'application/json',
        'api-key': configuration.apiKey,
      })
      ..headers.addAll(headers);
    if (formFields != null) {
      request.bodyFields = formFields;
    }
    try {
      final http.StreamedResponse response = await _client
          .send(request)
          .timeout(connectTimeout);
      final List<int> bytes = <int>[];
      await for (final List<int> chunk in response.stream.timeout(
        readTimeout,
      )) {
        if (maximumResponseBytes != null &&
            bytes.length + chunk.length > maximumResponseBytes) {
          throw const HorizonHttpException(HorizonHttpFailure.responseTooLarge);
        }
        bytes.addAll(chunk);
      }
      return HorizonHttpResult(
        statusCode: response.statusCode,
        headers: response.headers,
        bytes: bytes,
      );
    } on TimeoutException {
      throw const HorizonHttpException(HorizonHttpFailure.timeout);
    } on SocketException {
      throw const HorizonHttpException(HorizonHttpFailure.network);
    } on http.ClientException {
      throw const HorizonHttpException(HorizonHttpFailure.network);
    }
  }

  void close() => _client.close();
}
