# UI Context

Infinity Wellness uses the Infinity App Material 3 light theme: a cool `#F8FAFC` scaffold, white cards, subtle slate borders, and a blue `AppColors.primaryDarkBlue` action color. The shared header shows the Infinity logo with a blue accent. Poppins is bundled locally in `assets/fonts/Poppins-Medium.ttf` and registered across the weights used by the theme.

Shared palette, spacing, and image paths come from `AppColors`, `AppDimens`, and `AppImages` in `lib/app/constant/resources/`. `AppTheme.lightTheme` is ported from `Infinity_App-main`, with only its package import changed and Dart formatting applied. Screens retain their existing structure and may use Infinity's violet secondary token for selected status and illustration accents.

The initial screen is Employee Wallet activation. An explicit control switches to Wellness Admin; this remains a development/testing role switch, not authorization. Employee screens use Employee, Employee Wallet, and Wellness Points labels. Wellness Admin Advanced may show masked provider configuration and safe status only. Functional wallet screens expose loading, empty, stale, uncertain, and retry states without leaking provider responses or credential material. Shared headers and balance rows must remain usable on a 320 logical-pixel phone at 1.3 text scale.
