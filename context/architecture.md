# Architecture

Flutter and Material 3 provide UI; GetX provides routing, bindings, and reactive state. `lib/main.dart` launches `lib/main_app.dart`. Routes are centralized in `lib/app/constant/routing/`. Resource tokens are in `lib/app/constant/resources/`.

`lib/app/core/` contains `BaseController`, `BaseView<T>`, and `InitialBinding`. Wallet and Wellness Admin feature modules use `binding/`, `controller/`, `screen/`, and `widget/` folders. Wallet screens are grouped by activation, overview, receive, send, history, and security; each route-level screen has one file, and barrel files contain exports. Profile has a reusable employee identity component.

Controllers own state mutations and text-controller lifetime; views use `Obx`. WalletController is application-scoped because shared text controllers survive GetX route replacement. Feature code imports only `lib/wallet_sdk/wallet_sdk.dart`; SDK internals own crypto, protected storage, protocol/XDR, QR, provider HTTP, activation, authority, and time. Protocol and persisted keys retain source identifiers. `wellness_copy.dart` adapts legacy SDK messages at the presentation boundary without changing SDK values.

The source app's Supabase and Infinity App concepts are not part of this scaffold.
