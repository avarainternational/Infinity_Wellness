# Current State

Last synchronized: 2026-10-05

## Repository

- Flutter package: `employee_wellness`
- Android application ID: `com.infinitywellness.employee_wellness`
- Display name: Infinity Wellness
- Target scaffold: new `flutter create` output with source application and SDK overlaid

## Runtime

`lib/main.dart` launches `GetMaterialApp` from `lib/main_app.dart`. GetX bindings register an application-scoped Wallet controller and shared public `WalletSdk`. The initial route is the Employee Wallet activation screen. Wallet and Wellness Admin routes use the source journey layout.

The Wallet SDK is synchronized to the BuilderPros wallet snapshot at commit `86141899dc3339d769872e61669a5daf291baf4d`. A presentation helper maps SDK Builder/Rewards wording into employee-facing copy. Feature code uses `wallet_sdk.dart`; its public Builder and distributor identifiers and protected-storage keys remain intact.

SDK-backed behavior now includes activation, active-identity migration, balance and confirmed-payment history reads, public receive identity, recipient inspection, exact transfer preparation, native authentication, signed submission, durable uncertain-transfer reconciliation, locking, encrypted user-held backup, same-account restoration, permanent local credential removal, and employee/admin configuration handshakes. Wellness Admin can configure funding and initial Wellness Points and list public accounts holding the configured points asset.

The overview, receive, send, history, and security screens use the SDK rather than mock wallet data. The admin asset-holder list is not an employee directory and does not verify employment identity. The role switch remains a development/testing control rather than authorization. The SDK port does not migrate credentials from another installed application or install provider configuration. No Supabase or mini-app features are included.

## Visual theme

The app keeps Infinity App's `AppColors`, `AppDimens`, `AppImages`, and `AppTheme` resources, the bundled Poppins font, and the Infinity logo. The upgraded wallet screens retain those tokens and support narrow phone layouts with larger text.

## Verification

On 2026-10-02, `flutter pub get`, `flutter analyze`, all 67 Flutter tests, and `flutter build apk --debug` passed. The debug APK is at `build/app/outputs/flutter-apk/app-debug.apk`. The iOS plist passed `plutil -lint`. Physical-device and security gates remain open.

On 2026-10-03, the Infinity visual theme passed `flutter pub get`, `flutter analyze`, all 67 Flutter tests, and `dart format --set-exit-if-changed lib`. `flutter run -d emulator-5554` built, installed, and rendered the first screen with the bundled Infinity logo, blue palette, and Poppins text. The emulator logged an EncryptedSharedPreferences decryption fallback during startup; the screen still rendered. That storage warning was outside the theme-only change.

On 2026-10-05, the wallet upgrade passed dependency resolution, `dart format --set-exit-if-changed lib test integration_test`, clean `flutter analyze`, all 161 Flutter tests, iOS plist validation, and `flutter build apk --debug`. The debug APK is at `build/app/outputs/flutter-apk/app-debug.apk`. Physical-device activation, transfer, native-authentication, protected-storage interruption, and recovery scenarios remain release gates.
