import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:employee_wellness/app/features/wallet/controller/wallet_controller.dart';
import 'package:employee_wellness/app/constant/routing/app_route.dart';
import 'package:employee_wellness/main_app.dart';
import 'package:employee_wellness/app/features/app_master/controller/app_master_controller.dart';
import 'package:employee_wellness/app/features/app_master/screen/app_master_configuration_review_screen.dart';
import 'package:employee_wellness/app/features/app_master/service/qr_input_adapter.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

void main() {
  late _FakeWalletSdk fakeWalletSdk;
  late _FakeQrImagePicker fakeQrImagePicker;
  late _FakeQrImageDecoder fakeQrImageDecoder;

  setUp(() {
    Get.reset();
    fakeWalletSdk = _FakeWalletSdk();
    fakeQrImagePicker = _FakeQrImagePicker();
    fakeQrImageDecoder = _FakeQrImageDecoder();
    Get.put<WalletSdk>(fakeWalletSdk, permanent: true);
    Get.put<QrInputAdapter>(
      QrInputAdapter(
        imagePicker: fakeQrImagePicker,
        imageDecoder: fakeQrImageDecoder,
      ),
      permanent: true,
    );
  });

  tearDown(Get.reset);

  testWidgets('Infinity wallet fits a narrow phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Get.find<WalletController>().openWalletOverview();
    await tester.pumpAndSettle();
    expect(find.text('9.5 RWD'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Get.find<WalletController>().openAppMaster();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('employee and admin route replacement retain one SDK session', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final wallet = Get.find<WalletController>();
    wallet.openAppMaster();
    await tester.pumpAndSettle();
    expect(identical(Get.find<WalletSdk>(), fakeWalletSdk), isTrue);
    Get.find<AppMasterController>().openBuilderWallet();
    await tester.pumpAndSettle();
    expect(identical(Get.find<WalletController>(), wallet), isTrue);
    expect(identical(Get.find<WalletSdk>(), fakeWalletSdk), isTrue);
  });

  testWidgets('lock and removal use SDK access state without a mock passcode', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final controller = Get.find<WalletController>();
    await controller.openLocked();
    await tester.pumpAndSettle();
    expect(fakeWalletSdk.access, RewardsAccessState.locked);
    expect(find.text('Mock Wellness Points passcode'), findsNothing);
    await tester.tap(find.text('Unlock Wellness Points'));
    await tester.pumpAndSettle();
    expect(fakeWalletSdk.access, RewardsAccessState.unlocked);
    controller.openRemoveWallet();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Authenticate and disable access'));
    await tester.tap(find.text('Authenticate and disable access'));
    await tester.pumpAndSettle();
    expect(fakeWalletSdk.access, RewardsAccessState.removed);
    expect(find.text('Restore Wellness Points access'), findsOneWidget);
    await tester.tap(find.text('Restore Wellness Points access'));
    await tester.pumpAndSettle();
    expect(fakeWalletSdk.access, RewardsAccessState.unlocked);
  });

  testWidgets(
    'Send amount prepares an immutable SDK review with no mock approval',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      Get.toNamed(Routes.walletSendScan);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Public receiving account'),
        'public-recipient',
      );
      await tester.tap(find.text('Check recipient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter amount'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Wellness Points amount'),
        '2.5',
      );
      await tester.tap(find.text('Prepare transfer review'));
      await tester.pumpAndSettle();
      expect(find.text('2.5 RWD'), findsOneWidget);
      expect(find.text('0.00001 XLM'), findsOneWidget);
      expect(find.text('public-issuer'), findsOneWidget);
      expect(find.text('Confirm send'), findsNothing);
      Get.find<WalletController>().amountController.text = '999';
      await tester.pump();
      expect(find.text('2.5 RWD'), findsOneWidget);
      expect(find.text('999 RWD'), findsNothing);
      await tester.ensureVisible(find.text('Confirm and send'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm and send'));
      await tester.pumpAndSettle();
      expect(
        find.text('Wellness Points sent — ledger confirmed'),
        findsOneWidget,
      );
      expect(find.text('test-hash'), findsOneWidget);
      expect(find.text('2.5 RWD'), findsOneWidget);
    },
  );

  testWidgets(
    'Recipient check uses SDK data and clears observation when edited',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      Get.toNamed(Routes.walletSendScan);
      await tester.pumpAndSettle();
      expect(find.text('Scan sample recipient'), findsNothing);
      final field = find.widgetWithText(TextField, 'Public receiving account');
      await tester.enterText(field, 'public-recipient');
      await tester.tap(find.text('Check recipient'));
      await tester.pumpAndSettle();
      expect(find.text('Can receive up to 100 RWD'), findsOneWidget);
      expect(find.text('Receiving account checked'), findsOneWidget);
      expect(find.text('Continue to review'), findsNothing);
      await tester.enterText(field, 'changed-recipient');
      await tester.pumpAndSettle();
      expect(find.text('Receiving account checked'), findsNothing);
    },
  );

  testWidgets('History distinguishes empty pages from unavailable reads', (
    tester,
  ) async {
    fakeWalletSdk.historyEmpty = true;
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    Get.toNamed(Routes.walletHistory);
    await tester.pumpAndSettle();
    expect(
      find.text('No Wellness Points payments on the pages checked.'),
      findsOneWidget,
    );
    expect(find.text('Load more history'), findsNothing);
    expect(find.text('Sent to Avery Chen'), findsNothing);
  });

  testWidgets('History loads pages and preserves rows on failed refresh', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    Get.toNamed(Routes.walletHistory);
    await tester.pumpAndSettle();
    expect(find.text('2 RWD'), findsOneWidget);
    await tester.tap(find.text('Load more history'));
    await tester.pumpAndSettle();
    expect(find.text('3 RWD'), findsOneWidget);
    expect(find.text('Load more history'), findsNothing);
    fakeWalletSdk.historyShouldFail = true;
    await tester.tap(find.byTooltip('Refresh Wellness Points history'));
    await tester.pumpAndSettle();
    expect(find.text('2 RWD'), findsOneWidget);
    expect(
      find.text('Previously loaded history — refresh unavailable.'),
      findsOneWidget,
    );
    fakeWalletSdk.historyShouldFail = false;
    await tester.tap(find.text('Retry history'));
    await tester.pumpAndSettle();
    expect(find.text('3 RWD'), findsNothing);
    expect(
      find.text('Previously loaded history — refresh unavailable.'),
      findsNothing,
    );
  });

  testWidgets('Overview loads SDK balance and marks failed refresh stale', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    Get.toNamed(Routes.walletOverview);
    await tester.pumpAndSettle();
    expect(find.text('9.5 RWD'), findsOneWidget);
    expect(find.text('1,250 pts'), findsNothing);
    fakeWalletSdk.balanceShouldFail = true;
    await tester.tap(find.byTooltip('Refresh Wellness Points balance'));
    await tester.pumpAndSettle();
    expect(find.text('9.5 RWD'), findsOneWidget);
    expect(
      find.text('Previously checked balance — refresh unavailable.'),
      findsOneWidget,
    );
    fakeWalletSdk.balanceShouldFail = false;
    await tester.tap(find.byTooltip('Refresh Wellness Points balance'));
    await tester.pumpAndSettle();
    expect(
      find.text('Previously checked balance — refresh unavailable.'),
      findsNothing,
    );
  });

  testWidgets('Receive renders the exact SDK public account and QR', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    Get.find<WalletController>().openReceive();
    await tester.pumpAndSettle();
    expect(find.text('test-public-account'), findsOneWidget);
    expect(tester.widget<QrImageView>(find.byType(QrImageView)), isNotNull);
    expect(find.text('BLD-JR-00142'), findsNothing);
  });

  testWidgets('Receive failure hides identity and offers retry', (
    tester,
  ) async {
    fakeWalletSdk.receiveShouldFail = true;
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    Get.find<WalletController>().openReceive();
    await tester.pumpAndSettle();
    expect(find.text('Receiving details unavailable.'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    fakeWalletSdk.receiveShouldFail = false;
    await tester.tap(find.text('Load receiving details'));
    await tester.pumpAndSettle();
    expect(find.text('test-public-account'), findsOneWidget);
  });

  testWidgets('opens the User Wallet activation entry', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Employee Wallet'), findsOneWidget);
    expect(find.text('Employee details'), findsOneWidget);
    expect(find.text('Wellness Points are not activated'), findsOneWidget);
    expect(find.byTooltip('Open Wellness Admin'), findsOneWidget);
  });

  testWidgets('previews the QR activation review flow', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Employee name'),
      'Jordan Rivers',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number with country code'),
      '+959123456789',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start activation'));
    await tester.pumpAndSettle();

    expect(find.text('Activation Request'), findsOneWidget);
    expect(find.text('Your activation request'), findsOneWidget);
    expect(find.text('Scan activation QR'), findsOneWidget);
    expect(find.text('Import QR image'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import QR image'));
    await tester.pumpAndSettle();

    expect(find.text('Review Activation'), findsOneWidget);
    expect(find.text('Activation costs covered'), findsOneWidget);
    expect(find.textContaining('XLM'), findsNothing);
    expect(find.textContaining('trustline'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Approve and activate'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Approve and activate'));
    await tester.pumpAndSettle();
    expect(find.text('Activation is being verified.'), findsOneWidget);
  });

  testWidgets('cancels an activation request after confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _openActivationRequest(tester);

    await tester.ensureVisible(find.text('Cancel activation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel activation'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel activation?'), findsOneWidget);
    await tester.tap(find.text('Cancel activation').last);
    await tester.pumpAndSettle();

    expect(fakeWalletSdk.cancelCalls, 1);
    expect(find.text('Wellness Points are not activated'), findsOneWidget);
  });

  testWidgets('keeps the request available when cancellation fails', (
    tester,
  ) async {
    fakeWalletSdk.cancelShouldFail = true;
    await tester.pumpWidget(const MyApp());
    await _openActivationRequest(tester);

    await tester.ensureVisible(find.text('Cancel activation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel activation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel activation').last);
    await tester.pumpAndSettle();

    expect(fakeWalletSdk.cancelCalls, 1);
    expect(find.text('Cancel activation'), findsOneWidget);
    expect(find.text('Wellness Points are not activated'), findsNothing);
    expect(
      find.text("We couldn't cancel this activation. Try again."),
      findsOneWidget,
    );
  });

  testWidgets('previews Wellness Admin activation package flow', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byTooltip('Open Wellness Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Wellness Admin'), findsOneWidget);
    expect(find.text('Activation capacity'), findsOneWidget);
    expect(find.text('13 Employees'), findsOneWidget);
    expect(find.text('My Wellness Points'), findsOneWidget);
    expect(find.textContaining('XLM'), findsNothing);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('NOWNodes configuration'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'NOWNodes API key'),
      'test-api-key',
    );
    expect(Get.find<AppMasterController>().nowNodesApiKey, 'test-api-key');
    await tester.ensureVisible(find.text('Save and verify settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and verify settings'));
    await tester.pumpAndSettle();
    expect(find.text('Configuration v1 ready'), findsWidgets);
    expect(fakeWalletSdk.providerSaveCalls, 1);
    expect(fakeWalletSdk.lastProviderInput?.apiKey, 'test-api-key');
    expect(Get.find<AppMasterController>().nowNodesApiKey, isEmpty);
    await tester.scrollUntilVisible(
      find.text('Configuration v1 ready').last,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Configuration v1 ready'), findsWidgets);
    expect(find.text('Environment'), findsWidgets);
    expect(find.textContaining('XLM'), findsNothing);

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, 1200),
      2000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -480));
    await tester.pumpAndSettle();
    expect(find.text('Wellness Points accounts'), findsOneWidget);
    expect(find.text('Jordan Rivers'), findsNothing);
    expect(
      find.text('Wellness Admin roster service is not configured.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Import QR image'),
      -220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Import QR image'));
    await tester.pumpAndSettle();

    expect(find.text('Activate Employee'), findsOneWidget);
    expect(find.text('Activation package'), findsOneWidget);
    expect(find.text('Noah Williams'), findsOneWidget);
    expect(find.text('+95912345678'), findsOneWidget);
    expect(find.text('ACT-TEST-01'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create activation QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create activation QR'));
    await tester.pumpAndSettle();

    expect(find.text('Activation QR'), findsOneWidget);
    expect(find.text('Save QR image'), findsOneWidget);
  });

  testWidgets('clears the NOWNodes key and shows a safe SDK failure', (
    tester,
  ) async {
    fakeWalletSdk.providerSaveShouldFail = true;
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open Wellness Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'NOWNodes API key'),
      'rejected-test-key',
    );
    await tester.ensureVisible(find.text('Save and verify settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and verify settings'));
    await tester.pumpAndSettle();

    expect(fakeWalletSdk.providerSaveCalls, 1);
    expect(Get.find<AppMasterController>().nowNodesApiKey, isEmpty);
    expect(find.text('The NOWNodes API key was not accepted.'), findsOneWidget);
    expect(find.textContaining('rejected-test-key'), findsNothing);
  });

  testWidgets('handles cancelled and unreadable QR image imports safely', (
    tester,
  ) async {
    fakeQrImagePicker.path = null;
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open Wellness Admin'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Import QR image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import QR image'));
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't find"), findsNothing);

    fakeQrImagePicker.path = 'unreadable.png';
    fakeQrImageDecoder.capture = const BarcodeCapture();
    await tester.ensureVisible(find.text('Import QR image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import QR image'));
    await tester.pumpAndSettle();
    expect(
      find.text("We couldn't find a readable activation QR in that image."),
      findsOneWidget,
    );
  });

  testWidgets('shows a safe camera permission message', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open Wellness Admin'));
    await tester.pumpAndSettle();
    Get.find<AppMasterController>().handleQrFailure(
      QrInputFailure.permissionDenied,
    );
    await tester.pump();

    expect(
      find.text('Camera access was denied. Import a QR image instead.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps an invalid activation request out of review', (
    tester,
  ) async {
    fakeWalletSdk.inspectShouldFail = true;
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open Wellness Admin'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Import QR image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import QR image'));
    await tester.pumpAndSettle();

    expect(find.text('Activate Employee'), findsNothing);
    expect(
      find.text("We couldn't verify this activation request."),
      findsOneWidget,
    );
  });

  testWidgets('offers the restored Employee review after restart', (
    tester,
  ) async {
    fakeWalletSdk.restoredReview = _FakeWalletSdk.review;
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open Wellness Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Resume Employee review'), findsOneWidget);
    await tester.tap(find.text('Resume Employee review'));
    await tester.pumpAndSettle();
    expect(find.text('Noah Williams'), findsOneWidget);
    expect(find.text('ACT-TEST-01'), findsOneWidget);
  });

  testWidgets('imports distributor secret once and clears the field', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open Wellness Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Distributor account'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Distributor secret key'),
      'private-test-value',
    );
    await tester.ensureVisible(find.text('Import and verify account'));
    await tester.tap(find.text('Import and verify account'));
    await tester.pumpAndSettle();
    expect(find.text('Import distributor account?'), findsOneWidget);
    await tester.tap(find.text('Import securely'));
    await tester.pumpAndSettle();

    expect(find.text('Distributor verified'), findsOneWidget);
    expect(find.text('GABCDE…UVWXYZ'), findsOneWidget);
    expect(Get.find<AppMasterController>().distributorSecret, isEmpty);
    expect(find.textContaining('private-test-value'), findsNothing);
  });

  testWidgets('applies a verified Employee configuration update', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    Get.toNamed(Routes.walletOverview);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Update Wellness Points service'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Update Wellness Points service'));
    await tester.pump();
    await tester.tap(find.text('Update Wellness Points service'));
    await tester.pumpAndSettle();

    expect(find.text('Update Wellness Points Service'), findsOneWidget);
    expect(find.text('CFG-TEST-01'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Import update QR image'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Import update QR image'));
    await tester.pumpAndSettle();

    expect(find.text('Review Service Update'), findsOneWidget);
    expect(find.text('UPD-TEST-01'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Apply service update'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Apply service update'));
    await tester.pumpAndSettle();

    expect(find.text('Service Updated'), findsOneWidget);
    expect(find.text('Configuration ready'), findsOneWidget);
    expect(fakeWalletSdk.configurationApplyCalls, 1);
  });

  testWidgets('creates a device-bound configuration update in Wellness Admin', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    Get.toNamed(Routes.appMasterAdvanced);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Employee configuration updates'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Import Employee request image'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    final AppMasterController controller = Get.find<AppMasterController>();
    await controller.acceptConfigurationRequest('opaque-configuration-request');
    expect(controller.configurationRequestReview.value, isNotNull);
    await tester.pumpWidget(
      const GetMaterialApp(home: AppMasterConfigurationReviewScreen()),
    );
    await tester.pump();

    expect(find.text('Review Configuration Request'), findsOneWidget);
    expect(find.text('CFG-TEST-01'), findsOneWidget);
    await controller.createConfigurationUpdate();
    expect(controller.configurationUpdate.value, isNotNull);
    expect(controller.configurationUpdate.value!.updateId, 'UPD-TEST-01');
    expect(fakeWalletSdk.configurationUpdateCalls, 1);
  });
}

final class _FakeWalletSdk implements WalletSdk {
  @override
  Future<String> createRewardsBackup(String password) async =>
      throw UnsupportedError('Recovery fixture not configured');
  @override
  Future<void> confirmRewardsBackup(String backup, String password) async =>
      throw UnsupportedError('Recovery fixture not configured');
  @override
  Future<void> restoreRewardsBackup(String backup, String password) async =>
      throw UnsupportedError('Recovery fixture not configured');
  @override
  Future<void> eraseRewardsFromDevice() async =>
      throw UnsupportedError('Recovery fixture not configured');
  @override
  Future<RewardsTransferOutcome?> resolvePendingRewardsTransfer({
    String? competingTransactionHash,
  }) async => transferOutcome;
  @override
  Future<AppMasterRosterPage> getAppMasterRoster({
    String? cursor,
    int limit = 20,
  }) async {
    throw const WalletSdkException(
      code: WalletSdkFailureCode.rosterNotConfigured,
      safeMessage: 'Wellness Admin roster service is not configured.',
      canRetry: false,
    );
  }

  RewardsAccessState access = RewardsAccessState.locked;
  @override
  Future<RewardsAccessState> getRewardsAccessState() async => access;
  @override
  Future<void> lockRewards() async {
    access = RewardsAccessState.locked;
  }

  @override
  Future<void> unlockRewards() async {
    access = RewardsAccessState.unlocked;
  }

  @override
  Future<void> removeRewardsAccess() async {
    access = RewardsAccessState.removed;
  }

  RewardsTransferOutcome? transferOutcome;
  @override
  Future<RewardsTransferOutcome?> getRewardsTransferStatus({
    bool reconcile = false,
  }) async => transferOutcome;
  @override
  Future<RewardsTransferOutcome> approveRewardsTransfer(
    String reviewId,
  ) async => transferOutcome = RewardsTransferOutcome(
    reviewId: reviewId,
    transactionHash: 'test-hash',
    publicAccount: preparedReview!.publicAccount,
    assetCode: 'RWD',
    amount: preparedReview!.amount,
    state: RewardsTransferState.confirmed,
  );
  @override
  Future<RewardsTransferAuthorization> authorizeRewardsTransfer(
    String reviewId,
  ) async => RewardsTransferAuthorization(
    reviewId: reviewId,
    expiresAt: DateTime.utc(2026, 10, 3, 12),
  );
  @override
  Future<void> cancelRewardsTransferAuthorization() async {}
  RewardsTransferReview? preparedReview;
  @override
  Future<RewardsTransferReview> prepareRewardsTransfer({
    required String publicAccount,
    required String amount,
  }) async {
    return preparedReview = RewardsTransferReview(
      reviewId: 'test-review',
      publicAccount: publicAccount,
      environment: ProviderEnvironment.test,
      assetCode: 'RWD',
      assetIssuer: 'public-issuer',
      amount: amount,
      maximumFee: '0.00001',
      expiresAt: DateTime.utc(2026, 10, 3, 12),
    );
  }

  @override
  Future<RewardsTransferReview> getPreparedRewardsTransfer(
    String reviewId,
  ) async => preparedReview!;
  @override
  Future<RewardsRecipientView> inspectRewardsRecipient(
    String publicAccount,
  ) async => RewardsRecipientView(
    publicAccount: publicAccount,
    environment: ProviderEnvironment.test,
    assetCode: 'RWD',
    receivingCapacity: '100',
    observedAt: DateTime.utc(2026, 10, 3),
  );
  bool historyEmpty = false;
  bool historyShouldFail = false;
  @override
  Future<RewardsHistoryPage> getRewardsHistory({
    String? cursor,
    int limit = 20,
  }) async {
    if (historyShouldFail) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsHistoryUnavailable,
        safeMessage: 'History unavailable.',
        canRetry: true,
      );
    }
    return RewardsHistoryPage(
      publicAccount: 'test-public-account',
      environment: ProviderEnvironment.test,
      assetCode: 'RWD',
      observedAt: DateTime.utc(2026, 10, 3),
      nextCursor: !historyEmpty && cursor == null ? 'next-test-page' : null,
      items: <RewardsHistoryItem>[
        if (!historyEmpty)
          RewardsHistoryItem(
            id: cursor == null ? 'first' : 'second',
            direction: RewardsHistoryDirection.received,
            amount: cursor == null ? '2' : '3',
            counterparty: 'test-counterparty',
            createdAt: DateTime.utc(2026, 10, 3),
          ),
      ],
    );
  }

  bool balanceShouldFail = false;
  @override
  Future<RewardsBalanceView> getRewardsBalance() async {
    if (balanceShouldFail) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.rewardsBalanceUnavailable,
        safeMessage: 'Balance unavailable.',
        canRetry: true,
      );
    }
    return RewardsBalanceView(
      publicAccount: 'test-public-account',
      environment: ProviderEnvironment.test,
      assetCode: 'RWD',
      total: '10',
      available: '9.5',
      observedAt: DateTime.utc(2026, 10, 3),
    );
  }

  bool receiveShouldFail = false;
  @override
  Future<RewardsReceiveView> getRewardsReceiveIdentity() async {
    if (receiveShouldFail) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.unavailable,
        safeMessage: 'Receiving details unavailable.',
        canRetry: true,
      );
    }
    return const RewardsReceiveView(
      publicAccount: 'test-public-account',
      qrValue: 'test-public-account',
      environment: ProviderEnvironment.test,
      assetCode: 'RWD',
    );
  }

  int cancelCalls = 0;
  bool cancelShouldFail = false;
  int providerSaveCalls = 0;
  ProviderConfigurationInput? lastProviderInput;
  bool providerSaveShouldFail = false;
  bool inspectShouldFail = false;
  ActivationRequestReview? restoredReview;
  int configurationApplyCalls = 0;
  int configurationUpdateCalls = 0;

  static final ActivationRequestReview review = ActivationRequestReview(
    requestId: 'ACT-TEST-01',
    builder: const BuilderIdentity(
      displayName: 'Noah Williams',
      phone: '+95912345678',
    ),
    expiresAt: DateTime(2030, 1, 1, 12),
    setupSteps: const <String>[
      'Set up Wellness Points',
      'Enable Wellness Points access',
      'Add starting Wellness Points',
    ],
  );

  static final ActivationRequestView request = ActivationRequestView(
    requestId: 'ACT-TEST-01',
    qrValue: 'thebuilderpros://rewards/activate/ACT-TEST-01',
    expiresAt: DateTime(2030, 1, 1, 12),
    builder: const BuilderIdentity(
      displayName: 'Jordan Rivers',
      phone: '+959123456789',
    ),
  );

  @override
  Future<ConfigurationOutcome> applyConfigurationUpdate(String updateId) async {
    configurationApplyCalls++;
    return ConfigurationOutcome(
      status: ProviderConfigurationStatus(
        state: ProviderConfigurationState.ready,
        environment: ProviderEnvironment.test,
        version: 2,
        endpointHost: 'xlm.nownodes.io',
        lastCheckedAt: DateTime.utc(2026, 10, 2),
      ),
    );
  }

  @override
  Future<ConfigurationRequestView> createConfigurationRequest() async =>
      ConfigurationRequestView(
        requestId: 'CFG-TEST-01',
        qrValue: 'opaque-configuration-request',
        expiresAt: DateTime(2030),
      );

  @override
  Future<ConfigurationUpdateView> createConfigurationUpdate(
    String requestId,
  ) async {
    configurationUpdateCalls++;
    return ConfigurationUpdateView(
      updateId: 'UPD-TEST-01',
      requestId: requestId,
      qrValue: 'opaque-configuration-update',
      expiresAt: DateTime(2030),
    );
  }

  @override
  Future<ConfigurationRequestReview> inspectConfigurationRequest(
    String qrValue,
  ) async => ConfigurationRequestReview(
    requestId: 'CFG-TEST-01',
    currentVersion: 1,
    environment: ProviderEnvironment.test,
    expiresAt: DateTime(2030),
  );

  @override
  Future<ConfigurationReview> inspectConfigurationUpdate(
    String qrValue,
  ) async => ConfigurationReview(
    updateId: 'UPD-TEST-01',
    version: 2,
    environment: ProviderEnvironment.test,
    endpointHost: 'xlm.nownodes.io',
    expiresAt: DateTime(2030),
  );

  @override
  Future<void> cancelActivation() async {
    cancelCalls++;
    if (cancelShouldFail) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.cancellationFailed,
        safeMessage: "We couldn't cancel this activation. Try again.",
        canRetry: true,
      );
    }
  }

  @override
  Future<ProviderConfigurationStatus> getProviderConfigurationStatus() async =>
      const ProviderConfigurationStatus.notConfigured();

  @override
  Future<DistributorAuthorityStatus> getDistributorAuthorityStatus() async =>
      const DistributorAuthorityStatus.notConfigured();

  @override
  Future<AppMasterOverview> getAppMasterOverview() async => AppMasterOverview(
    activationCapacity: 13,
    rewardsAvailable: '18,400',
    serviceStatus: 'Ready for activations',
    updatedAt: DateTime.utc(2026, 9, 19, 16),
  );

  @override
  Future<DistributorAuthorityStatus> importDistributorSecret(
    String secret,
  ) async => const DistributorAuthorityStatus(
    state: DistributorAuthorityState.ready,
    maskedAccountId: 'GABCDE…UVWXYZ',
    environment: ProviderEnvironment.production,
  );

  @override
  Future<void> removeDistributorAuthority() async {}

  @override
  Future<ActivationRequestReview> inspectBuilderRequest(String qrValue) async {
    if (inspectShouldFail) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.invalidActivationRequest,
        safeMessage: "We couldn't verify this activation request.",
        canRetry: false,
      );
    }
    return review;
  }

  @override
  Future<ActivationRequestReview?> restoreInspectedBuilderRequest() async =>
      restoredReview;

  @override
  Future<ActivationResponseView> approveBuilderRequest(
    String requestId,
  ) async => ActivationResponseView(
    responseId: 'RES-TEST-01',
    requestId: requestId,
    qrValue: 'opaque-activation-response',
    expiresAt: DateTime(2030, 1, 1, 12, 5),
  );

  @override
  Future<ActivationReview> inspectActivationResponse(String qrValue) async =>
      ActivationReview(
        responseId: 'RES-TEST-01',
        requestId: review.requestId,
        expiresAt: DateTime(2030, 1, 1, 12, 5),
        preparedBy: 'GABCDE…UVWXYZ',
        setupSteps: const <String>[
          'Activation costs covered',
          'Wellness Points access ready',
          'Starting Wellness Points: 1',
        ],
      );

  @override
  Future<ActivationOutcome> approveActivation(String responseId) async =>
      ActivationOutcome(
        responseId: responseId,
        state: ActivationOutcomeState.submitted,
        message: 'Activation submitted. Verifying Wellness Points setup…',
      );

  @override
  Future<WalletActivationStatus> reconcileActivation() async =>
      const WalletActivationStatus(
        state: WalletActivationState.pending,
        message: 'Activation is being verified.',
      );

  @override
  Future<WalletActivationStatus> getActivationStatus() async =>
      const WalletActivationStatus.notActivated();

  @override
  Future<ActivationRequestView?> restoreActivationRequest() async => null;

  @override
  Future<ActivationRequestView> startActivation(
    BuilderIdentity builder,
  ) async => request;

  @override
  Future<ProviderConfigurationOutcome> saveAppMasterProviderConfiguration(
    ProviderConfigurationInput input,
  ) async {
    providerSaveCalls++;
    lastProviderInput = input;
    if (providerSaveShouldFail) {
      throw const WalletSdkException(
        code: WalletSdkFailureCode.providerUnauthorized,
        safeMessage: 'The NOWNodes API key was not accepted.',
        canRetry: true,
      );
    }
    return ProviderConfigurationOutcome(
      status: ProviderConfigurationStatus(
        state: ProviderConfigurationState.ready,
        environment: input.environment,
        version: input.version,
        endpointHost: Uri.parse(input.endpoint).host,
        lastCheckedAt: DateTime.utc(2026, 9, 18, 12),
      ),
    );
  }
}

final class _FakeQrImagePicker implements QrImagePicker {
  String? path = 'activation-qr.png';

  @override
  Future<String?> pickImagePath() async => path;
}

final class _FakeQrImageDecoder implements QrImageDecoder {
  BarcodeCapture? capture = const BarcodeCapture(
    barcodes: <Barcode>[Barcode(rawValue: 'opaque-activation-request')],
  );

  @override
  Future<BarcodeCapture?> decode(String path) async => capture;
}

Future<void> _openActivationRequest(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Employee name'),
    'Jordan Rivers',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Phone number with country code'),
    '+959123456789',
  );
  await tester.drag(find.byType(ListView), const Offset(0, -260));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start activation'));
  await tester.pumpAndSettle();
}
