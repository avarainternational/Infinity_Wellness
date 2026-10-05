# Wallet Sub-Feature 01 — User Stories

## Employee activation

### US-01 — Start activation

As a Employee, I enter my name and phone and start activation.

- The app validates basic input and calls `WalletSdk.startActivation()` once.
- The action shows progress and prevents duplicate taps.
- The SDK returns either a safe request view or a safe failure.

### US-02 — Share the request QR

As a Employee, I show the SDK-provided request QR to an Wellness Admin.

- The application treats QR content as opaque.
- Copy uses exactly the value returned by the SDK.
- An unexpired pending request can be restored through the SDK.

### US-03 — Review the Employee request

As an Wellness Admin, I scan or import the request and review the Employee.

- Both input methods call `WalletSdk.inspectBuilderRequest()`.
- The app renders only the returned safe review.
- Invalid input receives a stable safe failure.

### US-04 — Prepare the activation QR

As an Wellness Admin, I approve a valid Employee request.

- The app calls `WalletSdk.approveBuilderRequest()`.
- The SDK returns a response ID, QR value, expiry, and safe status.
- The application does not inspect or modify the QR value.

### US-05 — Approve activation

As a Employee, I scan/import the response, review it, and approve it.

- Inspection uses `WalletSdk.inspectActivationResponse()`.
- Approval uses `WalletSdk.approveActivation()`.
- Cancellation performs no completion action.

### US-06 — See a verified result

As a Employee, I see success only when the SDK returns `activated`.

- An uncertain result shows safe verification progress.
- Retry is offered only when the SDK marks it safe.

## Wellness Admin operations

### US-07 — Monitor activation capacity

As an Wellness Admin, I see safe capacity and Wellness Points summaries supplied by the SDK.

### US-08 — Monitor Employee access

As an Wellness Admin, I see Employee access status and Wellness Points balances without internal
implementation details.

### US-09 — Inspect support information

As an Wellness Admin, I open Advanced to save the NOWNodes endpoint/API key and see
environment, configuration version, service health, last check, and safe support
references supplied by the SDK.

- The API key field is masked.
- Save passes the value directly to the Wallet SDK and clears the field.
- The SDK health-checks and protects the configuration before reporting success.
- Activation response creation is unavailable until configuration is healthy.

### US-10 — Use My Wellness Points

As an Wellness Admin user, I use the shared Wellness Points experience without transferring
Wellness Admin authority into the Employee controller.

## Cross-cutting rules

- Flutter code depends only on the Wallet SDK facade and safe models.
- QR values are opaque outside the SDK.
- Protected credentials never enter application state, screenshots, clipboard,
  analytics, crash reports, or ordinary logs.
- Mock screens never claim real SDK completion.
