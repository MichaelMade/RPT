# RPT App Store Privacy Answers

Last updated: 2026-11-12

Use this as the source checklist when filling App Store Connect privacy nutrition labels for the current RPT binary.

## Current disclosure stance

- **Data collected by the developer:** No.
- **Tracking:** No.
- **Third-party advertising:** No.
- **Third-party analytics SDKs:** No. TelemetryDeck (or any other analytics SDK) is not linked. `FunnelRemoteConfig.telemetryDeckAppID` is empty, and the remote sink is a no-op.
- **Accounts or sign-in:** No.
- **Developer-run backend receiving workout data:** No.

## Data handled only on device

RPT stores workout logs, exercise/template data, rest-timer preferences, onboarding state, app settings, workout-recovery state, and anonymous conversion-funnel events (`install`, onboarding, paywall, purchase, restore) locally on the user's device. Funnel events do not include a user identifier, IDFA, Apple ID, or workout contents. The privacy manifest declares UserDefaults access for app functionality (`CA92.1`).

These local-only values should not be entered as developer-collected App Store privacy data unless a future release sends them to a server or third-party SDK. If a TelemetryDeck app ID is supplied and that SDK is linked later, re-check this checklist before the next App Store submission.

## Notifications

The rest-end alert is opt-in and uses local notifications only. RPT asks for notification permission (`alert`, `sound`) at runtime when the user turns the alert on, schedules one local notification for the end of a running rest when the app leaves the foreground, and removes it when the app returns. The notification text is fixed ("Rest complete") and carries no workout data. There is no `aps-environment` entitlement, no remote-notification registration, and no push token. Nothing about notifications is developer-collected data, so the privacy nutrition labels do not change.

## User-initiated export

CSV export creates a local file and opens the iOS share sheet. Users choose the destination. This remains user-initiated sharing, not automatic developer collection.

## StoreKit purchase flow

RPT Pro uses Apple's StoreKit/App Store purchase and restore flow for product ID `rpt.pro.lifetime`. RPT reads entitlement state to unlock Pro features and does not receive payment-card details.

## Re-check before release

Before submitting a build, verify in Xcode/App Store Connect that the archived binary still has:

1. No unexpected permission strings for camera, photos, contacts, location, microphone, Bluetooth, or HealthKit. Notification permission needs no usage string; confirm it is still requested only by the opt-in rest-end alert, and that the archive has no `aps-environment` entitlement.
2. No analytics, ads, crash-reporting, or tracking SDKs added since this checklist was written.
3. `PrivacyInfo.xcprivacy` bundled in the archive with only the required-reason API usage expected for UserDefaults.
4. App Store privacy answers still matching the current binary after StoreKit configuration is validated.
