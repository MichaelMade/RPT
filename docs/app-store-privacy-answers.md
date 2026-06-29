# RPT App Store Privacy Answers

Last updated: 2026-06-29

Use this as the source checklist when filling App Store Connect privacy nutrition labels for the current RPT binary.

## Current disclosure stance

- **Data collected by the developer:** No.
- **Tracking:** No.
- **Third-party advertising:** No.
- **Third-party analytics SDKs:** No.
- **Accounts or sign-in:** No.
- **Developer-run backend receiving workout data:** No.

## Data handled only on device

RPT stores workout logs, exercise/template data, rest-timer preferences, onboarding state, app settings, and workout-recovery state locally on the user's device. The privacy manifest declares UserDefaults access for app functionality.

These local-only values should not be entered as developer-collected App Store privacy data unless a future release sends them to a server or third-party SDK.

## User-initiated export

CSV export creates a local file and opens the iOS share sheet. Users choose the destination. This remains user-initiated sharing, not automatic developer collection.

## StoreKit purchase flow

RPT Pro uses Apple's StoreKit/App Store purchase and restore flow for product ID `rpt.pro.lifetime`. RPT reads entitlement state to unlock Pro features and does not receive payment-card details.

## Re-check before release

Before submitting a build, verify in Xcode/App Store Connect that the archived binary still has:

1. No unexpected permission strings for camera, photos, contacts, location, microphone, Bluetooth, HealthKit, or notifications.
2. No analytics, ads, crash-reporting, or tracking SDKs added since this checklist was written.
3. `PrivacyInfo.xcprivacy` bundled in the archive with only the required-reason API usage expected for UserDefaults.
4. App Store privacy answers still matching the current binary after StoreKit configuration is validated.
