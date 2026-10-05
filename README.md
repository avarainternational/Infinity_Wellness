# Infinity Wellness — Employee Wellness

A Flutter employee wellness app skeleton built with Material 3, GetX, and a ported Wallet SDK. The initial route opens Employee Wallet activation for Wellness Points. Wellness Admin exposes activation and service configuration flows.

## Run

```sh
flutter pub get
flutter run
```

## Verify

```sh
flutter analyze
flutter test
```

The activation SDK supports protected local requests, QR review, NOWNodes health checks, approval, submission, and reconciliation. The overview, receive, send, history, and security surfaces retain presentation prototypes and must not be described as live Wellness Points transactions. A real provider key and administrator authority must be supplied on device through Wellness Admin Advanced. Production release requires two-device testnet verification and independent security review.

See `context/` for architecture, current behavior, and constraints. The imported technical design documents in `docs/` preserve source SDK identifiers where those are part of its public API or protocol examples.
