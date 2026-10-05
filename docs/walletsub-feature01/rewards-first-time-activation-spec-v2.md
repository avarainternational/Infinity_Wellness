# Wellness Points First-Time Activation Specification V2

## Product decision

First-time Wellness Points activation is a phone-to-phone QR handshake between the Employee
App and Wellness Admin App. Both people use simple Wellness Points language. All implementation
complexity belongs inside the Wallet SDK.

## End-to-end experience

0. The Wellness Admin saves and verifies the NOWNodes configuration in Advanced.
1. The Employee enters their name and phone number.
2. The Employee taps **Start activation**.
3. The app asks the Wallet SDK to prepare an activation request.
4. The Employee App displays the request QR.
5. The Wellness Admin scans the QR or imports its image.
6. The Wellness Admin App asks the Wallet SDK to inspect the request.
7. The Wellness Admin reviews the Employee and setup summary and approves it.
8. The Wellness Admin App asks the Wallet SDK to prepare the response QR, including
   the encrypted device-bound provider configuration.
9. The Employee scans the response QR or imports its image.
10. The Employee App asks the Wallet SDK to inspect the response.
11. The Employee reviews the summary and approves activation.
12. The Wallet SDK installs the provider configuration, completes activation, and
    verifies the result.
13. The Employee App shows the verified Wellness Points outcome.

## Application boundary

The Flutter application may know only:

- Employee identity;
- activation request ID;
- safe QR content supplied by the Wallet SDK;
- expiry and display status;
- safe review rows;
- activation progress; and
- safe success or failure results.

The Flutter application must not construct, interpret, modify, store, or log the
protected contents used by the Wallet SDK.

## Simple Wallet SDK interface

```dart
abstract interface class WalletSdk {
  Future<ActivationRequestView> startActivation(BuilderIdentity builder);
  Future<ActivationRequestReview> inspectBuilderRequest(String qrValue);
  Future<ActivationResponseView> approveBuilderRequest(String requestId);
  Future<ActivationReview> inspectActivationResponse(String qrValue);
  Future<ActivationOutcome> approveActivation(String responseId);
  Future<ActivationStatus> getActivationStatus();
  Future<void> cancelActivation();
}
```

These are application-facing types. Their fields contain only values required to
render the interface. The SDK never returns protected credentials or provider data.

## Required outcomes

- `notActivated`
- `requestReady`
- `waitingForResponse`
- `readyForReview`
- `working`
- `verifying`
- `activated`
- `retryableFailure`
- `restartRequired`

Each failure contains a stable code for application branching and a safe message
for display. Provider-specific failures never cross the SDK boundary.

## Safety rules

- QR scanning and QR-image import use the same SDK inspection method.
- A QR is never acted on before SDK inspection and human review.
- The Employee and Wellness Admin approve only on their own phones.
- Protected credentials never cross between phones.
- Repeated, expired, mismatched, modified, or wrong-purpose QR content is rejected.
- An uncertain result remains in verification until the SDK establishes the final
  outcome.
- Success is shown only after `approveActivation()` returns `activated`.

## Wellness Admin surfaces

- **Overview:** activation capacity, Wellness Points availability, and Employee access.
- **Activate Employee:** safe Employee and setup review.
- **Activation QR:** QR display and image save.
- **Advanced:** safe service health plus masked NOWNodes endpoint/API-key setup and
  rotation controls for the Wellness Admin.
- **My Wellness Points:** the same Wellness Points experience used by a Employee.

Provider configuration is the only implementation-specific setting exposed in
Advanced. Its key is masked, submitted directly to the Wallet SDK, cleared from
the field, and never returned to the application.

## Acceptance criteria

- The two phones complete the experience using QR only.
- Application code uses only `WalletSdk` and safe SDK models.
- No protected credential crosses devices or enters Flutter presentation state.
- No provider-specific terminology appears in screens, controllers, routes,
  application models, analytics, or ordinary logs.
- Success, cancellation, expiry, mismatch, modification, repetition, interruption,
  and uncertain-result tests pass.
