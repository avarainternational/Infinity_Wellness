# Decision Log

## 2026-10-02 — Employee Wellness skeleton port

Created the target with `flutter create --project-name employee_wellness --org com.infinitywellness`. Ported the source application structure, flows, tests, technical design documents, and complete Wallet SDK. Rebranded the UI for employees and Wellness Points. Kept SDK public identifiers, protocol data, and storage keys compatible with the source; only package imports changed in the SDK. Did not bring source credentials or the Infinity App's Supabase/mini-app features.

The overview and transfer-related UI remains presentation-only. Native camera and photo permissions support the ported QR adapter. The visual header uses a code-native wordmark rather than the source logo.

## 2026-10-03 — Infinity App theme port

Copied Infinity App's color, dimension, image-path, and ThemeData resources into Employee Wellness. Bundled its local Poppins font, logo, and splash banner. The shared Wallet header now renders the logo and blue accent. This is a visual-only change; the source app's Supabase, mini-apps, routes, and data flows remain outside scope.

## 2026-10-05 — Functional Wallet upgrade

Synchronized the wallet implementation to BuilderPros commit `86141899dc3339d769872e61669a5daf291baf4d` while preserving Infinity application identity, theme assets, package name, employee-facing terminology, protocol identifiers, and protected-storage keys. Added live wallet reads, protected transfers, durable transfer reconciliation, encrypted user-held recovery, service-configuration rotation, and public asset-holder listing.

Kept the SDK as one application-scoped instance shared by the employee and admin controllers. Adapted native-authentication messages at construction rather than renaming SDK protocol values. Classified the admin roster as an asset-holder list rather than employee identity. Added a recovery guard so an imported unresolved transfer cannot be silently ignored when different local evidence exists.
