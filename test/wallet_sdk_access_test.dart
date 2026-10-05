import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/rewards_access_service.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String account =
      'GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF';
  late _Store store;
  late _Auth auth;
  late RewardsAccessService access;
  late DateTime now;
  int revocations = 0;
  setUp(() {
    store = _Store();
    auth = _Auth();
    now = DateTime.utc(2026, 10, 3);
    revocations = 0;
    access = RewardsAccessService(
      store: store,
      authenticator: auth,
      clock: CallbackWalletClock(() => now),
      revokeTransfer: () {
        revocations++;
      },
    );
  });
  tearDown(() => access.lock());

  test(
    'restart starts locked; native unlock expires and explicit lock revokes',
    () async {
      expect(await access.status(), RewardsAccessState.locked);
      await access.unlock(account);
      expect(await access.status(), RewardsAccessState.unlocked);
      now = now.add(const Duration(minutes: 5));
      expect(await access.status(), RewardsAccessState.locked);
      access.lock();
      expect(revocations, greaterThan(0));
      final restart = RewardsAccessService(
        store: store,
        authenticator: auth,
        clock: CallbackWalletClock(() => now),
        revokeTransfer: () {},
      );
      expect(await restart.status(), RewardsAccessState.locked);
      restart.lock();
    },
  );

  test(
    'removal persists across restart and native restore retains custody',
    () async {
      store.values['protected.seed'] = 'retained';
      int checks = 0;
      await access.remove(account, () async {
        checks++;
      });
      expect(checks, 1);
      expect(await access.status(), RewardsAccessState.removed);
      await expectLater(
        access.requireAvailable(),
        throwsA(isA<WalletSdkException>()),
      );
      final restart = RewardsAccessService(
        store: store,
        authenticator: auth,
        clock: CallbackWalletClock(() => now),
        revokeTransfer: () {},
      );
      expect(await restart.status(), RewardsAccessState.removed);
      await restart.unlock(account);
      expect(await restart.status(), RewardsAccessState.unlocked);
      expect(store.values['protected.seed'], 'retained');
      expect(store.deletes, 0);
      restart.lock();
    },
  );

  test('denial or account mismatch cannot restore removed access', () async {
    await access.remove(account, () async {});
    auth.accept = false;
    await expectLater(
      access.unlock(account),
      throwsA(isA<WalletSdkException>()),
    );
    expect(await access.status(), RewardsAccessState.removed);
    auth.accept = true;
    await expectLater(
      access.unlock('different'),
      throwsA(isA<WalletSdkException>()),
    );
    expect(await access.status(), RewardsAccessState.removed);
  });

  test('background cancellation rejects late native success', () async {
    auth.gate = Completer<bool>();
    final attempt = access.unlock(account);
    final assertion = expectLater(attempt, throwsA(isA<WalletSdkException>()));
    await Future<void>.delayed(Duration.zero);
    access.didChangeAppLifecycleState(AppLifecycleState.paused);
    auth.gate!.complete(true);
    await assertion;
    expect(await access.status(), RewardsAccessState.locked);
  });

  test(
    'locking during removal revalidation prevents durable removal',
    () async {
      await expectLater(
        access.remove(account, () async {
          access.lock();
        }),
        throwsA(isA<WalletSdkException>()),
      );
      expect(store.values[RewardsAccessService.storageKey], isNull);
      expect(await access.status(), RewardsAccessState.locked);
    },
  );

  test(
    'interrupted write may persist removal; status remains fail closed',
    () async {
      store.throwAfterWrite = true;
      await expectLater(
        access.remove(account, () async {}),
        throwsA(isA<WalletSdkException>()),
      );
      expect(await access.status(), RewardsAccessState.removed);
      expect(store.deletes, 0);
    },
  );

  test(
    'corrupt access marker blocks public availability and reads safely',
    () async {
      store.values[RewardsAccessService.storageKey] = 'corrupt';
      await expectLater(
        access.requireAvailable(),
        throwsA(isA<WalletSdkException>()),
      );
      await expectLater(access.status(), throwsA(isA<WalletSdkException>()));
      expect(access.isUnlocked, false);
    },
  );

  test('duplicate access operations cannot prompt twice', () async {
    auth.gate = Completer<bool>();
    final first = access.unlock(account);
    await expectLater(
      access.unlock(account),
      throwsA(isA<WalletSdkException>()),
    );
    auth.gate!.complete(true);
    await first;
    expect(auth.calls, 1);
  });
}

final class _Auth implements TransferAuthenticator {
  bool accept = true;
  int calls = 0;
  Completer<bool>? gate;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return gate == null ? accept : gate!.future;
  }

  @override
  Future<void> cancel() async {}
}

final class _Store implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  bool throwAfterWrite = false;
  int deletes = 0;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
    if (throwAfterWrite) throw StateError('interrupted');
  }

  @override
  Future<bool> contains(String key) async => values.containsKey(key);
  @override
  Future<void> delete(String key) async {
    deletes++;
    values.remove(key);
  }
}
