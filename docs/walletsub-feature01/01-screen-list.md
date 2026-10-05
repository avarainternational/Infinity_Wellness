# Wallet Sub-Feature 01 — Screen List

The first release has no Home screen. First-time activation follows
`rewards-first-time-activation-spec-v2.md`. Every screen uses the Wallet SDK through
a controller; no screen handles activation internals.

## Wellness Points

| ID | Screen | Purpose | Main actions |
| --- | --- | --- | --- |
| B-01 | Wellness Points — Not Activated | Collect Employee name and phone | Start activation |
| B-02 | Activation Request | Display the SDK-provided request QR | Copy request, scan response, import QR image |
| B-03 | Review Activation | Display the SDK-provided review | Approve, cancel |
| B-04 | Activation Progress | Show safe progress and outcome | Wait, retry when offered |
| B-05 | Wellness Points | Show Employee card, balance, and actions | Receive, Send, history, remove access |
| B-06 | Receive Wellness Points | Display SDK-provided receive QR | Copy, return |
| B-07 | Scan Recipient | Pass scanned/imported content to the SDK | Scan, import, cancel |
| B-08 | Send Amount | Collect Wellness Points amount | Continue, cancel |
| B-09 | Review Send | Display SDK-provided review | Confirm, cancel |
| B-10 | Confirm Action | Confirm a protected action | Confirm, cancel |
| B-11 | Send Outcome | Display SDK-provided outcome | Done, safe retry |
| B-12 | Wellness Points History | Display safe Wellness Points activity | Refresh, inspect |
| B-13 | Wellness Points Locked | Explain local protection | Unlock |
| B-14 | Remove Wellness Points Access | Remove access from this device | Confirm, cancel |

## Wellness Admin

| ID | Screen | Purpose | Main actions |
| --- | --- | --- | --- |
| M-01 | Wellness Admin Overview | Show activation capacity and Employee access | Scan/import request, open Advanced/My Wellness Points |
| M-02 | Activate Employee | Display the SDK-provided Employee review | Create activation QR, cancel |
| M-03 | Activation QR | Display the SDK-provided response QR | Save image, finish |
| M-04 | Advanced | Configure NOWNodes and show safe service/support status | Save endpoint/API key, rotate configuration, refresh status |
| M-05 | My Wellness Points | Reuse the Wellness Points screens | Standard Wellness Points actions |

## UI rule

Screens render safe SDK view models and return user intent. They never decode QR
content, make activation decisions, manipulate protected values, or translate raw
provider failures.
