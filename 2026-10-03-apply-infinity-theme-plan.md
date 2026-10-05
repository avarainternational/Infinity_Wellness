# Apply Infinity Wellness Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Target--Employee Wellness visual theme (colors, fonts, logo, `ThemeData`, dimens) with the full Infinity_App-main theme, keeping routing, controllers, bindings, features, and `wallet_sdk` untouched.

**Architecture:** Single-theme swap through the existing token files (`AppColors`, `AppDimens`, `AppTheme`, `AppImages`), plus pubspec font/asset wiring and asset copies. Screens keep structure; hardcoded hex/`Inter` literals get replaced by `AppColors`/`AppTheme` tokens.

**Tech Stack:** Flutter / Dart `^3.9.2`, GetX `^4.7.2`, Material 3, Google-Fonts-free local Poppins TTF.

**Spec:** In-chat approved design of 2026-10-03 ("Theme only" option): apply colors, logo, fonts, and `ThemeData` from `Infinity_App-main`; no structural or flow changes.

**Implementation status (2026-10-03):** Theme and assets applied; dependency resolution, analysis, all 67 tests, format check, and emulator first-screen smoke passed. Commit steps are inapplicable because `Target--Employee Wellness` is not a Git repository.

## Global Constraints

- Do not modify GetX routes, controllers, bindings, feature structure, or `lib/wallet_sdk/`.
- Keep every `AppColors`/`AppDimens`/`AppImages` member referenced by target code working (verified: all currently used members exist in Infinity's source files).
- Match `Infinity_App-main/lib/app/constant/resources/app_theme.dart`, `app_colors.dart`, `app_dimens.dart`, `app_images.dart` verbatim except import path `infinity_wellness` → `employee_wellness`.
- Package name stays `employee_wellness`.

## Review Focus

- Token-name regressions: a target widget referencing an `AppColors` member missing from Infinity's file must fail compile/analyze (none known; verify).
- Font asset mismatch: `pubspec.yaml` font family must be `Poppins` and file present at `assets/fonts/Poppins-Medium.ttf`.
- Logo path mismatch: `AppImages.logo` path must exist under `assets/images/`.
- Hardcoded old-theme literals (violet `#5B20E5`, orange `#F35A12`, `Inter`) left in widgets would silently keep the old look.
- `AppTheme` must use `fontFamily: 'Poppins'` and `scaffoldBackgroundColor: Color(0xFFF8FAFC)` from Infinity.

---

### Task 1: Copy theme resource files from Infinity_App-main

**Files:**
- Modify: `lib/app/constant/resources/app_colors.dart`
- Modify: `lib/app/constant/resources/app_dimens.dart`
- Modify: `lib/app/constant/resources/app_images.dart`

**Interfaces:**
- Produces: Infinity's full `AppColors`, `AppDimens`, `AppImages` public members
- Consumes: file copies from `Infinity_App-main/lib/app/constant/resources/`

- [x] **Step 1: Copy the three files verbatim**

```bash
cp "../Infinity_App-main/lib/app/constant/resources/app_colors.dart" lib/app/constant/resources/app_colors.dart
cp "../Infinity_App-main/lib/app/constant/resources/app_dimens.dart" lib/app/constant/resources/app_dimens.dart
cp "../Infinity_App-main/lib/app/constant/resources/app_images.dart" lib/app/constant/resources/app_images.dart
```

- [x] **Step 2: Run analyze**

Run: `flutter analyze`
Expected: reports any `AppColors.<member>` references in target that no longer resolve (fix by keeping a one-line alias in `AppColors` only if a genuinely missing member is reported — do not revert the palette).

- [ ] **Step 3: Commit**

```bash
git add lib/app/constant/resources/app_colors.dart lib/app/constant/resources/app_dimens.dart lib/app/constant/resources/app_images.dart
git commit -m "feat: adopt Infinity Wellness color and dimension tokens"
```

### Task 2: Replace AppTheme with Infinity's theme

**Files:**
- Modify: `lib/app/constant/resources/app_theme.dart`

**Interfaces:**
- Consumes: `AppColors` from Task 1
- Produces: `AppTheme.lightTheme` identical to Infinity's (Poppins, `#F8FAFC` scaffold, seed `primaryDarkBlue`, 12px radii, M3 nav bar)

- [x] **Step 1: Copy and rename the package import**

Copy `Infinity_App-main/lib/app/constant/resources/app_theme.dart` over the target file and replace `package:infinity_wellness` with `package:employee_wellness` (two occurrences: import line only).

- [x] **Step 2: Run analyze**

Run: `flutter analyze`
Expected: zero issues in `app_theme.dart`.

- [ ] **Step 3: Commit**

```bash
git add lib/app/constant/resources/app_theme.dart
git commit -m "feat: adopt Infinity Wellness Material 3 theme"
```

### Task 3: Wire Poppins font and Infinity assets

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/fonts/Poppins-Medium.ttf`
- Create: `assets/images/infinity_wellness_logo.png`

- [x] **Step 1: Copy assets**

```bash
mkdir -p assets/fonts
cp "../Infinity_App-main/assets/fonts/Poppins-Medium.ttf" assets/fonts/Poppins-Medium.ttf
cp "../Infinity_App-main/assets/images/infinity_wellness_logo.png" assets/images/infinity_wellness_logo.png
cp "../Infinity_App-main/assets/images/splash_banner.png" assets/images/splash_banner.png
```

- [x] **Step 2: Update pubspec.yaml**

Under `flutter:`, ensure `assets:` lists `assets/images/` (already present) and add an `infinity_wellness_logo.png`-compatible entry implicitly via that directory entry. Under `flutter:`, add:

```yaml
  fonts:
    - family: Poppins
      fonts:
        - asset: assets/fonts/Poppins-Medium.ttf
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 500
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 600
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 700
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 800
```

(Match `Infinity_App-main/pubspec.yaml` lines ~91-104; only the font family and weights.)

- [x] **Step 3: Verify**

Run: `flutter pub get`
Expected: success; `flutter analyze` still clean.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml assets/fonts assets/images/infinity_wellness_logo.png assets/images/splash_banner.png
git commit -m "feat: add Poppins font and Infinity brand assets"
```

### Task 4: Replace hardcoded old-theme literals in widgets

**Files:**
- Modify: any target file flagged in Step 1 (expected: `lib/app/features/wallet/widget/wallet_ui.dart`, `wallet_screen_components.dart`, `app_master` screens, `profile` widgets)

- [x] **Step 1: Find leftovers**

Run: `grep -rn "Inter\|0xFFF35A12\|0xFF5B20E5\|0xFFD94A08\|0xFFEEE8FF\|0xFFFFF0E8" lib --include=*.dart`
Expected: list of hardcoded old-theme references (plus the new `app_colors.dart` if grep pattern catches new palette — ignore that file).

- [x] **Step 2: Swap each literal**

Replace old orange/violet literals with the matching `AppColors` token (e.g. primary action color → `AppColors.primary`/`primaryDarkBlue`, soft backgrounds → `AppColors.primarySoft`/`cyanPillBg`), and `Inter`/font-family literals with removal (inherit `Poppins` from `AppTheme`). Do not restructure widgets.

- [x] **Step 3: Verify**

Run: `flutter analyze && flutter test`
Expected: no lints; tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A lib
git commit -m "refactor: route widget colors through AppColors tokens"
```

### Task 5: Final verification

**Files:** none

- [x] **Step 1: Full checks**

Run: `flutter pub get && flutter analyze && flutter test && dart format --set-exit-if-changed lib`
Expected: analyze clean, all tests pass, no format diffs.

- [x] **Step 2: Manual smoke (report only)**

Run the app (`flutter run`) and confirm splash/first screen renders with the Infinity blue palette, Poppins text, and the Infinity logo where `AppImages.logo` is used.
