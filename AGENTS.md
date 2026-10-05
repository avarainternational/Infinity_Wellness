# Employee Wellness repository guidance

Read the relevant files in `context/` before changing product behavior, architecture, UI, or the Wallet SDK. The skeleton design is in `2026-10-02-employee-wellness-skeleton-design.md`; the visual theme plan is in `2026-10-03-apply-infinity-theme-plan.md`.

Keep feature code on the public `WalletSdk` boundary. Do not put credentials, seeds, QR internals, or transport responses in UI code or documentation. The SDK's Builder and distributor API identifiers and protected-storage keys are intentionally retained from the port; employee-facing language belongs in the presentation layer.

Keep context files synchronized with changes. Distinguish live SDK behavior from mock screens. Run `flutter pub get`, `flutter analyze`, and `flutter test` independently. Format changed Dart files with `dart format`. Build a native artifact when changing platform configuration. Preserve unrelated files and user changes.
