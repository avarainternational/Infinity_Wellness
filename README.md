# Infinity Wellness — Employee Wellness

A Flutter employee wellness app built with Material 3, GetX, and a ported Wallet SDK. The initial route opens Employee Wallet activation for Wellness Points. Wellness Admin exposes activation and protected service configuration flows.

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

The Wallet SDK supports protected activation, live balance and history reads, receive identity, reviewed transfers with native device authentication, durable reconciliation, encrypted user-held backup and restore, device removal, and protected configuration updates. A real provider key and administrator authority must be supplied on device through Wellness Admin Advanced. Production release still requires two-device verification and independent security review.

See `context/` for architecture, current behavior, and constraints. The imported technical design documents in `docs/` preserve source SDK identifiers where those are part of its public API or protocol examples.
