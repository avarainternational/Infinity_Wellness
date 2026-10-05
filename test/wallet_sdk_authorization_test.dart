import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:employee_wellness/wallet_sdk/src/authorization/transfer_authorization_service.dart';
import 'package:employee_wellness/wallet_sdk/src/time/wallet_clock.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late _Authenticator authenticator;
  late TransferAuthorizationService service;
  late RewardsTransferReview review;
  setUp(() {
    now = DateTime.utc(2026, 10, 3);
    authenticator = _Authenticator();
    service = TransferAuthorizationService(
      authenticator: authenticator,
      clock: CallbackWalletClock(() => now),
    );
    review = RewardsTransferReview(
      reviewId: 'SEND-test',
      publicAccount: 'public-recipient',
      environment: ProviderEnvironment.test,
      assetCode: 'ALT',
      assetIssuer: 'public-issuer',
      amount: '1.25',
      maximumFee: '0.00002',
      expiresAt: now.add(const Duration(minutes: 2)),
    );
  });
  tearDown(() => service.invalidate());
  test('native approval binds exact review and is consumed once', () async {
    int checks = 0;
    final result = await service.authorize(review, () async {
      checks++;
    });
    expect(checks, 2);
    expect(authenticator.reason, contains('1.25 ALT to public-recipient'));
    expect(authenticator.reason, contains('0.00002 XLM'));
    expect(result.expiresAt, now.add(const Duration(seconds: 30)));
    expect(service.consume(review), isTrue);
    expect(service.consume(review), isFalse);
  });
  test('public lookalike cannot forge private approval', () async {
    await service.authorize(review, () async {});
    final copy = RewardsTransferReview(
      reviewId: review.reviewId,
      publicAccount: review.publicAccount,
      environment: review.environment,
      assetCode: review.assetCode,
      assetIssuer: review.assetIssuer,
      amount: review.amount,
      maximumFee: review.maximumFee,
      expiresAt: review.expiresAt,
    );
    expect(service.consume(copy), isFalse);
  });
  test(
    'denied unsupported and failed validation never grant approval',
    () async {
      authenticator.accept = false;
      await expectLater(
        service.authorize(review, () async {}),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.code,
            'code',
            WalletSdkFailureCode.rewardsAuthorizationDenied,
          ),
        ),
      );
      expect(service.consume(review), isFalse);
      authenticator.fail = true;
      await expectLater(
        service.authorize(review, () async {}),
        throwsA(
          isA<WalletSdkException>().having(
            (e) => e.safeMessage,
            'safe message',
            isNot(contains('private-error')),
          ),
        ),
      );
      int checks = 0;
      authenticator.fail = false;
      authenticator.accept = true;
      await expectLater(
        service.authorize(review, () async {
          if (++checks == 2) throw StateError('changed');
        }),
        throwsA(isA<WalletSdkException>()),
      );
      expect(service.consume(review), isFalse);
    },
  );
  test(
    'expiry and background invalidate approvals, inactive native dialog does not',
    () async {
      await service.authorize(review, () async {});
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(service.consume(review), isTrue);
      await service.authorize(review, () async {});
      now = now.add(const Duration(seconds: 30));
      expect(service.consume(review), isFalse);
      await service.authorize(review, () async {});
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(service.consume(review), isFalse);
    },
  );
  test(
    'cancellation rejects pending native success without waiting for it',
    () async {
      authenticator.gate = Completer<bool>();
      final pending = service.authorize(review, () async {});
      await authenticator.started.future;
      final rejected = expectLater(pending, throwsA(isA<WalletSdkException>()));
      await service.cancel();
      await rejected;
      authenticator.gate!.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(service.consume(review), isFalse);
      expect(authenticator.cancellations, greaterThan(0));
    },
  );
  test(
    'concurrent approval is rejected and late review expiry cannot approve',
    () async {
      authenticator.gate = Completer<bool>();
      final pending = service.authorize(review, () async {});
      await authenticator.started.future;
      await expectLater(
        service.authorize(review, () async {}),
        throwsA(isA<WalletSdkException>()),
      );
      now = review.expiresAt;
      authenticator.gate!.complete(true);
      await expectLater(pending, throwsA(isA<WalletSdkException>()));
      expect(service.consume(review), isFalse);
    },
  );
}

final class _Authenticator implements TransferAuthenticator {
  bool accept = true;
  bool fail = false;
  String? reason;
  int cancellations = 0;
  Completer<bool>? gate;
  final Completer<void> started = Completer<void>();
  @override
  Future<bool> authenticate(String reason) async {
    this.reason = reason;
    if (!started.isCompleted) started.complete();
    if (fail) throw StateError('private-error');
    return gate == null ? accept : await gate!.future;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}
