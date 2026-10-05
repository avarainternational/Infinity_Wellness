# Decision Log

## 2026-10-02 — Employee Wellness skeleton port

Created the target with `flutter create --project-name employee_wellness --org com.infinitywellness`. Ported the source application structure, flows, tests, technical design documents, and complete Wallet SDK. Rebranded the UI for employees and Wellness Points. Kept SDK public identifiers, protocol data, and storage keys compatible with the source; only package imports changed in the SDK. Did not bring source credentials or the Infinity App's Supabase/mini-app features.

The overview and transfer-related UI remains presentation-only. Native camera and photo permissions support the ported QR adapter. The visual header uses a code-native wordmark rather than the source logo.

## 2026-10-03 — Infinity App theme port

Copied Infinity App's color, dimension, image-path, and ThemeData resources into Employee Wellness. Bundled its local Poppins font, logo, and splash banner. The shared Wallet header now renders the logo and blue accent. This is a visual-only change; the source app's Supabase, mini-apps, routes, and data flows remain outside scope.
