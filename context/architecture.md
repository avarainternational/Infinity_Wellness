# Architecture

Flutter and Material 3 provide UI; GetX provides routing, bindings, and reactive state. `lib/main.dart` launches `lib/main_app.dart`. Routes are centralized in `lib/app/constant/routing/`. Resource tokens are in `lib/app/constant/resources/`.

`lib/app/core/` contains `BaseController`, `BaseView<T>`, and `InitialBinding`. Wallet and Wellness Admin feature modules use `binding/`, `controller/`, `screen/`, and `widget/` folders. Wallet screens are grouped by activation, overview, receive, send, history, and security; each route-level screen has one file, and barrel files contain exports. Profile has a reusable employee identity component.

Controllers own state mutations and text-controller lifetime; views use `Obx`. WalletController and the public `WalletSdk` instance are application-scoped so route replacement cannot split authorization, transfer, or recovery state. Feature code imports only `lib/wallet_sdk/wallet_sdk.dart`; SDK internals own crypto, protected storage, protocol/XDR, QR, provider HTTP, activation, authority, balance/history, transfers, access control, and recovery. Protocol and persisted keys retain source identifiers. `wellness_copy.dart` adapts legacy SDK and native-authentication messages at the presentation boundary without changing protocol values.

Transfer approval is bound to an immutable review, revalidated around native authentication, consumed once at submission, and persisted before the network POST. Uncertain submissions reconcile by transaction hash and block another send. Recovery exports only password-encrypted `BRB1` text through an SDK-owned page; feature controllers never hold plaintext signing material. The admin roster queries public asset holders and must not be treated as an authenticated employee directory.

The source app's Supabase and Infinity App concepts are not part of this scaffold.
