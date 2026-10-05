# Employee Wellness App Skeleton — Design Spec

Date: 2026-10-02
Status: Approved (design stage)

## Goal

Create a runnable Flutter skeleton in `Target--Employee Wellness` that ports the
architecture, concepts, and UI of `TheFlutterBuilderProsApp-main`, rebranded for
employee wellness, including the complete Wallet ("Wellness Points") experience
and the full `wallet_sdk`.

## Decisions

- Target created with fresh `flutter create` (not a tree copy).
- Pure rebranded skeleton port of the source app's structure and features.
- Domain language renamed: Builder → Employee, Rewards/Builder Rewards →
  Wellness Points, Wallet → Employee Wallet (Wellness Points).
- `lib/wallet_sdk/` ported in full, preserving its public API boundary.
- Source's Supabase/Infinity-App concepts (mini-apps, live data) are out of scope.

## Scaffold

- `flutter create --project-name employee_wellness` into
  `Target--Employee Wellness`, org `com.infinitywellness`.
- Overlay: `pubspec.yaml` deps (get ^4.7.2, flutter_secure_storage, cryptography,
  http, qr_flutter, shared_preferences), `analysis_options.yaml`, `AGENTS.md`,
  `context/`, `docs/`, `assets/`.
- Rename package `the_builder_pros` → `employee_wellness` everywhere (imports,
  android/iOS application IDs, app title in `AppString`).

## Architecture (ported 1:1)

- `lib/main.dart` → `lib/main_app.dart` (`GetMaterialApp`, theme, initial route,
  `InitialBinding`).
- `lib/app/constant/resources/` (`app_string.dart`, `app_theme.dart`) and
  `lib/app/constant/routing/` (`app_pages.dart`).
- `lib/app/core/base/` (`BaseController`, `BaseView<T>`) and
  `lib/app/core/binding/initial_binding.dart`.
- `lib/app/features/wallet/` with `binding/ controller/ screen/ widget/`;
  screens grouped: `activation/ overview/ receive/ send/ history/ security/`,
  one file per route-level screen, barrel-only `wallet_screens.dart`.
- `lib/app/features/app_master/` same shape (Distributor Dashboard equivalent:
  Employee Wellness admin/activation packages), links to shared Wallet routes.
- `lib/app/features/profile/widget/` reusable identity components.
- `GetX` reactive state via `Obx`; controllers extend `BaseController`; screens
  extend `BaseView<T>`; bindings own controller registration; state mutations in
  controllers/services only.

## Wallet essentials

- `lib/wallet_sdk/` ported in full: `src/crypto`, `src/configuration`,
  `src/transport`, `src/activation`, `src/protocol` (+`xdr`), `src/qr`,
  `src/storage`, `src/time`, `src/authority`.
- Feature code imports only the safe public `WalletSdk` API (unchanged boundary).
- Flows ported: not-activated screen → activation request (real QR from opaque
  SDK value, 15-minute pending persistence, confirmed cancel with safe retry on
  cleanup failure), activation response review, overview, receive, send, history,
  security — presentation prototypes preserved as in source.
- `WalletController` application-scoped (shared text controllers survive GetX
  route replacement).
- App Master Advanced submits endpoint/environment/transient key through the
  public `WalletSdk`; duplicate-save prevention; field cleared after submit;
  only safe metadata restored.
- NOWNodes Horizon config validation, health-check via private direct HTTP
  client, bounded retry with jitter, atomic promotion — ported unchanged.

## Documentation

- All `context/*.md` and `AGENTS.md` rewritten for Employee Wellness, same
  structure; `current-state.md` reset to describe the new skeleton.
- Docs kept in sync per source conventions (current-state, project-overview,
  architecture, code-standards, ui-context, decision-log, progress-tracker,
  ai-workflow-rules).

## Verification

- `flutter pub get`, `flutter analyze`, `flutter test` from target root;
  `dart format` on changed Dart files; report failures and skipped checks.

## Non-goals

- Infinity_App Supabase backend, mini-apps, or live-data features.
- Modifying wallet_sdk internals beyond rename/packaging.
- Credential migration from the source repo.
