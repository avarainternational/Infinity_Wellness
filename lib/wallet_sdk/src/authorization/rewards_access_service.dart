import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

/// Device access only. Removal retains custody and reconciliation evidence.
final class RewardsAccessService with WidgetsBindingObserver {
  RewardsAccessService({
    required CredentialStore store,
    required TransferAuthenticator authenticator,
    required WalletClock clock,
    required void Function() revokeTransfer,
  }) : _store = store,
       _authenticator = authenticator,
       _clock = clock,
       _revokeTransfer = revokeTransfer;

  static const String storageKey = 'rewards.device.access.v1';
  final CredentialStore _store;
  final TransferAuthenticator _authenticator;
  final WalletClock _clock;
  final void Function() _revokeTransfer;
  DateTime? _expiry;
  Timer? _timer;
  int _generation = 0;
  bool _observing = false;
  bool _busy = false;
  Completer<void>? _cancelled;

  bool get isUnlocked => _expiry != null && _clock.nowUtc().isBefore(_expiry!);
  bool get isBusy => _busy;
  int get revision => _generation;

  Future<String?> _removedAccount() async {
    try {
      final String? value = await _store.read(storageKey);
      if (value == null || value == 'active') return null;
      if (value.startsWith('removed:') && value.length == 64) {
        return value.substring(8);
      }
      for (final prefix in ['erasing:', 'erased:']) {
        if (value.startsWith(prefix) && value.length == prefix.length + 56) {
          return value.substring(prefix.length);
        }
      }
      throw const FormatException();
    } catch (_) {
      lock();
      throw _error(
        'Saved Rewards access is unavailable. Preserve this device.',
      );
    }
  }

  Future<RewardsAccessState> status() async {
    if (await _removedAccount() != null) {
      lock();
      return RewardsAccessState.removed;
    }
    if (_expiry != null && !isUnlocked) lock();
    return isUnlocked ? RewardsAccessState.unlocked : RewardsAccessState.locked;
  }

  Future<void> requireAvailable() async {
    if (await _removedAccount() != null) {
      lock();
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsAccessRemoved,
        safeMessage:
            'Rewards access is disabled on this device. Restore access using device authentication.',
        canRetry: false,
      );
    }
  }

  /// The exact native transfer prompt can open access; public results cannot.
  void acceptTransferAuthentication() {
    if (_busy) throw _error('Another access operation is in progress.');
    _open();
  }

  void _open() {
    _expiry = _clock.nowUtc().add(const Duration(minutes: 5));
    _observe();
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 5), lock);
  }

  void lock() {
    _generation++;
    _expiry = null;
    _timer?.cancel();
    _timer = null;
    _revokeTransfer();
    if (_cancelled != null && !_cancelled!.isCompleted) _cancelled!.complete();
    if (_busy) unawaited(_cancelNative());
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  Future<void> unlock(String account) => _authenticate(
    'Unlock Rewards access on this device.',
    (check) async {
      final marker = await _store.read(storageKey);
      if (marker?.startsWith('erasing:') == true ||
          marker?.startsWith('erased:') == true) {
        throw _error('Restore your saved Rewards backup to use this account.');
      }
      final String? removed = await _removedAccount();
      if (removed != null && removed != account) {
        throw _error('Saved access does not match this Rewards account.');
      }
      check();
      if (removed != null) await _write('active');
      check();
      _open();
    },
  );

  Future<void> remove(
    String account,
    Future<void> Function() revalidate,
  ) => _authenticate(
    'Disable Rewards access on this device. Signing material will be retained for recovery.',
    (check) async {
      await revalidate();
      // No asynchronous gap between validity check and starting the write.
      check();
      await _write('removed:$account');
      lock();
    },
  );

  Future<void> _write(String value) async {
    try {
      await _store.write(key: storageKey, value: value);
      if (await _store.read(storageKey) != value) throw const FormatException();
    } catch (_) {
      lock();
      throw _error(
        'Access could not be saved safely. Check its status before continuing.',
      );
    }
  }

  Future<void> protect(
    String reason,
    Future<void> Function(void Function()) action,
  ) => _authenticate(reason, action);

  Future<void> saveMarker(String value) => _write(value);

  Future<void> _authenticate(
    String reason,
    Future<void> Function(void Function()) commit,
  ) async {
    if (_busy) throw _error('Device authentication is already in progress.');
    lock();
    _busy = true;
    final int generation = _generation;
    _cancelled = Completer<void>();
    _observe();
    try {
      _checkLifecycle();
      final bool accepted = await Future.any<bool>(<Future<bool>>[
        _authenticator.authenticate(reason).timeout(const Duration(minutes: 2)),
        _cancelled!.future.then((_) => false),
      ]);
      _checkLifecycle();
      if (!accepted || generation != _generation) {
        throw _error('Device authentication was cancelled or not accepted.');
      }
      await commit(() {
        _checkLifecycle();
        if (generation != _generation) {
          throw _error('Access authorization was cancelled.');
        }
      });
    } on WalletSdkException {
      lock();
      rethrow;
    } catch (_) {
      lock();
      throw _error('Device authentication is unavailable.');
    } finally {
      await _cancelNative();
      _busy = false;
      _cancelled = null;
      if (!isUnlocked) {
        if (_observing) WidgetsBinding.instance.removeObserver(this);
        _observing = false;
      }
    }
  }

  void _checkLifecycle() {
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      throw _error('Return to Rewards and authenticate again.');
    }
  }

  void _observe() {
    if (!_observing) WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  Future<void> _cancelNative() async {
    try {
      await _authenticator.cancel().timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Access was already revoked. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      lock();
    }
  }

  WalletSdkException _error(String message) => WalletSdkException(
    code: WalletSdkFailureCode.rewardsAccessUnavailable,
    safeMessage: message,
    canRetry: true,
  );
}
