# Code Standards

Use explicit Dart types, immutable models where practical, `const` widgets, and `dart format`. Keep one route-level screen per file. Controllers extend `BaseController`, route-level views extend `BaseView<T>`, bindings register controllers, and reactive UI uses `Obx`. Keep state mutation and service work out of widgets.

Use centralized route names and shared resources. Feature code may import only the public `wallet_sdk.dart` API; do not parse opaque QR payloads, expose credentials, or import `wallet_sdk/src/` from features. Keep employee-facing text in Employee/Wellness Points language while retaining SDK public identifiers.

Add meaningful tests when behavior changes. Run `flutter analyze` and `flutter test` independently from this repository root. Do not commit credentials, seeds, signed payloads, or real provider keys.
