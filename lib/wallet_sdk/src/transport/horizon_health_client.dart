import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:employee_wellness/wallet_sdk/src/transport/horizon_http_client.dart';
import 'package:employee_wellness/wallet_sdk/src/configuration/provider_configuration.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

abstract interface class HorizonHealthClient {
  Future<void> check(ProviderConfiguration configuration);
}

final class DirectHorizonHealthClient implements HorizonHealthClient {
  DirectHorizonHealthClient({
    http.Client? client,
    HorizonHttpClient? transport,
    this.connectTimeout = const Duration(seconds: 5),
    this.readTimeout = const Duration(seconds: 5),
    this.totalTimeout = const Duration(seconds: 10),
    this.maximumResponseBytes = 64 * 1024,
    this.maximumAttempts = 3,
    this.retryBaseDelay = const Duration(milliseconds: 200),
    Random? random,
    Future<void> Function(Duration duration)? delay,
  }) : assert(maximumAttempts > 0),
       assert(maximumResponseBytes > 0),
       _transport = HorizonHttpClient.resolve(
         client: client,
         transport: transport,
         connectTimeout: connectTimeout,
         readTimeout: readTimeout,
       ),
       _random = random ?? Random.secure(),
       _delay = delay ?? _defaultDelay;

  static const String _testNetworkPassphrase =
      'Test SDF Network ; September 2015';
  static const String _publicNetworkPassphrase =
      'Public Global Stellar Network ; September 2015';

  final HorizonHttpClient _transport;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration totalTimeout;
  final int maximumResponseBytes;
  final int maximumAttempts;
  final Duration retryBaseDelay;
  final Random _random;
  final Future<void> Function(Duration duration) _delay;

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

  @override
  Future<void> check(ProviderConfiguration configuration) async {
    try {
      await _checkWithRetries(configuration).timeout(totalTimeout);
    } on TimeoutException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerTimeout,
        safeMessage: 'The service check timed out. Try again.',
        canRetry: true,
      );
    }
  }

  Future<void> _checkWithRetries(ProviderConfiguration configuration) async {
    for (int attempt = 0; attempt < maximumAttempts; attempt++) {
      try {
        await _checkOnce(configuration);
        return;
      } on WalletSdkException catch (error) {
        if (!_isTransient(error.code) || attempt + 1 >= maximumAttempts) {
          rethrow;
        }
        final int exponentialMilliseconds =
            retryBaseDelay.inMilliseconds * (1 << attempt);
        final int jitterMilliseconds = retryBaseDelay.inMilliseconds == 0
            ? 0
            : _random.nextInt(retryBaseDelay.inMilliseconds + 1);
        await _delay(
          Duration(milliseconds: exponentialMilliseconds + jitterMilliseconds),
        );
      }
    }
  }

  Future<void> _checkOnce(ProviderConfiguration configuration) async {
    try {
      final HorizonHttpResult response = await _transport.request(
        configuration: configuration,
        maximumResponseBytes: maximumResponseBytes,
      );
      _validateStatus(response.statusCode);
      final String? contentType = response.headers['content-type'];
      if (!_isJsonMediaType(contentType)) {
        throw _invalidResponse();
      }

      final Map<String, dynamic> decoded = response.decodeJson();
      final Object? networkPassphrase = decoded['network_passphrase'];
      final Object? horizonVersion = decoded['horizon_version'];
      if (networkPassphrase is! String ||
          networkPassphrase.isEmpty ||
          horizonVersion is! String ||
          horizonVersion.isEmpty) {
        throw _invalidResponse();
      }

      final String expectedPassphrase =
          configuration.environment == ProviderEnvironment.test
          ? _testNetworkPassphrase
          : _publicNetworkPassphrase;
      if (networkPassphrase != expectedPassphrase) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.providerNetworkMismatch,
          safeMessage: 'The service is connected to the wrong environment.',
          canRetry: false,
        );
      }
    } on WalletSdkException {
      rethrow;
    } on TimeoutException {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerTimeout,
        safeMessage: 'The service check timed out. Try again.',
        canRetry: true,
      );
    } on FormatException {
      throw _invalidResponse();
    } on HorizonHttpException catch (error) {
      if (error.failure == HorizonHttpFailure.responseTooLarge) {
        throw _invalidResponse();
      }
      throw WalletSdkException(
        code: error.failure == HorizonHttpFailure.timeout
            ? WalletSdkFailureCode.providerTimeout
            : WalletSdkFailureCode.providerServiceUnavailable,
        safeMessage: error.failure == HorizonHttpFailure.timeout
            ? 'The service check timed out. Try again.'
            : 'The activation service is unavailable. Try again.',
        canRetry: true,
      );
    }
  }

  bool _isTransient(WalletSdkFailureCode code) =>
      code == WalletSdkFailureCode.providerRateLimited ||
      code == WalletSdkFailureCode.providerServiceUnavailable ||
      code == WalletSdkFailureCode.providerTimeout;

  bool _isJsonMediaType(String? contentType) {
    if (contentType == null) {
      return false;
    }
    final String mediaType = contentType.split(';').first.trim().toLowerCase();
    return mediaType == 'application/json' || mediaType.endsWith('+json');
  }

  void _validateStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    if (statusCode == 401 || statusCode == 403) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerUnauthorized,
        safeMessage: 'The NOWNodes API key was not accepted.',
        canRetry: true,
      );
    }
    if (statusCode == 429) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerRateLimited,
        safeMessage: 'The activation service is busy. Try again shortly.',
        canRetry: true,
      );
    }
    throw const WalletSdkException(
      code: WalletSdkFailureCode.providerServiceUnavailable,
      safeMessage: 'The activation service is unavailable. Try again.',
      canRetry: true,
    );
  }

  WalletSdkException _invalidResponse() => const WalletSdkException(
    code: WalletSdkFailureCode.providerInvalidResponse,
    safeMessage: 'The activation service returned an invalid response.',
    canRetry: true,
  );
}
