import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

abstract interface class TransferAuthenticator {
  Future<bool> authenticate(String reason);
  Future<void> cancel();
}

final class NativeTransferAuthenticator implements TransferAuthenticator {
  NativeTransferAuthenticator({
    LocalAuthentication? authentication,
    this.messageMapper,
  }) : _authentication = authentication ?? LocalAuthentication();
  final LocalAuthentication _authentication;
  final String Function(String)? messageMapper;
  @override
  Future<bool> authenticate(String reason) async {
    if (!await _authentication.isDeviceSupported()) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsAuthorizationUnavailable,
        safeMessage: 'Set up device authentication before authorizing Rewards.',
        canRetry: false,
      );
    }
    return _authentication.authenticate(
      localizedReason: messageMapper?.call(reason) ?? reason,
      biometricOnly: false,
      persistAcrossBackgrounding: false,
    );
  }

  @override
  Future<void> cancel() async {
    await _authentication.stopAuthentication();
  }
}

/// Private one-intent approval. Public status is never accepted as evidence.
final class TransferAuthorizationService with WidgetsBindingObserver {
  TransferAuthorizationService({
    required TransferAuthenticator authenticator,
    required WalletClock clock,
  }) : _authenticator = authenticator,
       _clock = clock;
  final TransferAuthenticator _authenticator;
  final WalletClock _clock;
  RewardsTransferReview? _approved;
  DateTime? _expiresAt;
  Timer? _timer;
  bool _observing = false;
  bool _busy = false;
  int _generation = 0;
  Future<void>? _cancellation;
  Completer<void>? _cancelSignal;

  Future<RewardsTransferAuthorization> authorize(
    RewardsTransferReview review,
    Future<void> Function() revalidate,
  ) async {
    if (_busy) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsAuthorizationUnavailable,
        safeMessage: 'Authorization is already in progress.',
        canRetry: true,
      );
    }
    invalidate();
    _busy = true;
    _cancelSignal = Completer<void>();
    final int generation = _generation;
    _observe();
    _timer = Timer(review.expiresAt.difference(_clock.nowUtc()), invalidate);
    try {
      await revalidate();
      _checkAttempt(generation, review);
      final Future<bool> nativeAttempt = _authenticator
          .authenticate(
            'Authorize ${review.amount} ${review.assetCode} to ${review.publicAccount}. Maximum fee ${review.maximumFee} XLM.',
          )
          .timeout(review.expiresAt.difference(_clock.nowUtc()));
      final bool authenticated = await Future.any<bool>(<Future<bool>>[
        nativeAttempt,
        _cancelSignal!.future.then<bool>(
          (_) => throw const WalletSdkException(
            code: WalletSdkFailureCode.invalidRewardsTransferReview,
            safeMessage:
                'Authorization was cancelled. Prepare the transfer again.',
            canRetry: false,
          ),
        ),
      ]);
      _checkAttempt(generation, review);
      if (!authenticated) {
        throw const WalletSdkException(
          code: WalletSdkFailureCode.rewardsAuthorizationDenied,
          safeMessage:
              'Device authentication was cancelled or not accepted. No payment was sent.',
          canRetry: true,
        );
      }
      await revalidate();
      _checkAttempt(generation, review);
      final DateTime shortExpiry = _clock.nowUtc().add(
        const Duration(seconds: 30),
      );
      final DateTime expires = shortExpiry.isBefore(review.expiresAt)
          ? shortExpiry
          : review.expiresAt;
      _approved = review;
      _expiresAt = expires;
      _timer?.cancel();
      _timer = Timer(expires.difference(_clock.nowUtc()), invalidate);
      return RewardsTransferAuthorization(
        reviewId: review.reviewId,
        expiresAt: expires,
      );
    } on WalletSdkException {
      invalidate();
      rethrow;
    } catch (_) {
      invalidate();
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsAuthorizationUnavailable,
        safeMessage:
            'Device authentication is unavailable. No payment was sent.',
        canRetry: true,
      );
    } finally {
      await _cancellation;
      _cancellation = null;
      _cancelSignal = null;
      _busy = false;
      if (_approved == null) _unobserve();
    }
  }

  void _checkAttempt(int generation, RewardsTransferReview review) {
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    if (generation != _generation ||
        !_clock.nowUtc().isBefore(review.expiresAt) ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidRewardsTransferReview,
        safeMessage:
            'Authorization expired or was cancelled. Prepare the transfer again.',
        canRetry: false,
      );
    }
  }

  /// Future signing may consume this only after revalidating the private intent.
  bool isValid(RewardsTransferReview review) =>
      identical(review, _approved) &&
      _expiresAt != null &&
      _clock.nowUtc().isBefore(_expiresAt!) &&
      _clock.nowUtc().isBefore(review.expiresAt);

  /// Consume once at the durable submission boundary.
  bool consume(RewardsTransferReview review) {
    final bool valid =
        identical(review, _approved) &&
        _expiresAt != null &&
        _clock.nowUtc().isBefore(_expiresAt!) &&
        _clock.nowUtc().isBefore(review.expiresAt);
    invalidate();
    return valid;
  }

  void invalidate() {
    if (_busy && _cancelSignal != null && !_cancelSignal!.isCompleted) {
      _cancelSignal!.complete();
    }
    _generation++;
    _approved = null;
    _expiresAt = null;
    _timer?.cancel();
    _timer = null;
    _unobserve();
    if (_busy) _cancellation ??= _cancelSafely();
  }

  Future<void> cancel() async {
    invalidate();
    await _cancellation;
  }

  Future<void> _cancelSafely() async {
    try {
      await _authenticator.cancel().timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Approval is already revoked. */
    }
  }

  void _observe() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  void _unobserve() {
    if (!_observing) return;
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native prompts may make the app inactive; actual backgrounding revokes approval.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      invalidate();
    }
  }
}
