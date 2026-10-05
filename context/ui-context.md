# UI Context

Infinity Wellness uses the Infinity App Material 3 light theme: a cool `#F8FAFC` scaffold, white cards, subtle slate borders, and a blue `AppColors.primaryDarkBlue` action color. The shared header shows the Infinity logo with a blue accent. Poppins is bundled locally in `assets/fonts/Poppins-Medium.ttf` and registered across the weights used by the theme.

Shared palette, spacing, and image paths come from `AppColors`, `AppDimens`, and `AppImages` in `lib/app/constant/resources/`. `AppTheme.lightTheme` is ported from `Infinity_App-main`, with only its package import changed and Dart formatting applied. Screens retain their existing structure and may use Infinity's violet secondary token for selected status and illustration accents.

The initial screen is Employee Wallet activation. An explicit control switches to Wellness Admin; this is a prototype role switch, not authorization. Employee screens use Employee, Employee Wallet, and Wellness Points labels. Wellness Admin Advanced may show masked provider configuration and safe status only. Balance, send, receive, history, and security previews must remain clearly identified as prototypes until backed by verified services.
