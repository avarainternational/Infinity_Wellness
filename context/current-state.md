# Current State

Last synchronized: 2026-10-03

## Repository

- Flutter package: `employee_wellness`
- Android application ID: `com.infinitywellness.employee_wellness`
- Display name: Infinity Wellness
- Target scaffold: new `flutter create` output with source application and SDK overlaid

## Runtime

`lib/main.dart` launches `GetMaterialApp` from `lib/main_app.dart`. GetX bindings register an application-scoped Wallet controller and shared public `WalletSdk`. The initial route is the Employee Wallet activation screen. Wallet and Wellness Admin routes use the source journey layout.

The complete source `lib/wallet_sdk/` is ported with only Dart package import changes. A presentation helper maps SDK Builder/Rewards wording into employee-facing copy. Feature code uses `wallet_sdk.dart`; its public Builder and distributor identifiers remain intact. SDK-backed flows include protected 15-minute pending activation requests, opaque QR values, confirmed cancellation with retryable cleanup failure, response inspection, approval, direct submission/reconciliation, configuration handshakes, protected administrator authority, and NOWNodes Horizon validation with bounded retry and atomic promotion.

Wellness Admin Advanced sends an endpoint, environment, and transient API key through `WalletSdk`, prevents duplicate saves, clears the entered key, and restores only safe status metadata. The UI has camera/gallery QR acquisition permissions on Android and iOS.

The overview, receive, send, history, and security screens retain source presentation prototypes. Their balances, transactions, and protected action previews are not live Wellness Points operations. The SDK port does not migrate source credentials or install a provider configuration. Production operation remains gated by two-device testnet verification and independent security approval. No Supabase or mini-app features are included.

## Visual theme

The app uses Infinity App's `AppColors`, `AppDimens`, `AppImages`, and `AppTheme` resources, the bundled Poppins font, and the Infinity logo in the shared header. The source splash banner is bundled but no splash route was added. Routes, controllers, bindings, and `wallet_sdk` were not changed by the theme port.

## Verification

On 2026-10-02, `flutter pub get`, `flutter analyze`, all 67 Flutter tests, and `flutter build apk --debug` passed. The debug APK is at `build/app/outputs/flutter-apk/app-debug.apk`. The iOS plist passed `plutil -lint`. Physical-device and security gates remain open.

On 2026-10-03, the Infinity visual theme passed `flutter pub get`, `flutter analyze`, all 67 Flutter tests, and `dart format --set-exit-if-changed lib`. `flutter run -d emulator-5554` built, installed, and rendered the first screen with the bundled Infinity logo, blue palette, and Poppins text. The emulator logged an EncryptedSharedPreferences decryption fallback during startup; the screen still rendered. That storage warning was outside the theme-only change.
