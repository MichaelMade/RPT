# RPT App Store Submission Packet

This packet is the manual App Store Connect entry source of truth for the first TestFlight/App Store submission. It mirrors `RPT/App/AppStoreReleasePlan.swift` and `fastlane/metadata/en-US/`.

## App identity

| Field | Value |
|---|---|
| App name | RPT - Reverse Pyramid Training |
| Bundle ID | `com.MichaelMade.RPT` |
| SKU | `rpt-ios-001` |
| Category | Health & Fitness |
| Content rights | No third-party content |
| Age rating baseline | 4+ if App Store Connect confirms no medical/regulated/UGC answers |
| Price model | Freemium |
| In-app purchase | `rpt.pro.lifetime` — one-time lifetime unlock, planned launch price `$9.99` |

## Metadata

| Field | Copy |
|---|---|
| Subtitle | Reverse pyramid training log |
| Promotional text | Log heavy top sets first, get RPT back-off guidance, and track strength trends without an account. |
| Keywords | `rpt,strength log,workout tracker,progressive overload,weight lifting,gym planner,rest timer,1rm` |
| Support URL | https://github.com/MichaelMade/RPT/issues |
| Privacy URL | https://github.com/MichaelMade/RPT/blob/master/Privacy%20Policy |
| Terms of Use (EULA) | Apple's Standard EULA — https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ |

## Long description

A focused strength-training log for lifters who train heavy first.

RPT is built around reverse pyramid training: hit your heaviest set while you're fresh, then reduce the weight and chase strong back-off sets. It keeps the workout flow fast, private, and focused on progressive overload instead of generic fitness noise.

Training tools:
- Log live workouts with set editing, RPE, rest timer, and completion check-offs
- Get RPT back-off weight suggestions from your top set
- Generate low-fatigue warm-up ramps before heavy work
- Re-run completed sessions as follow-up workouts
- Plan templates, plate math, and 1RM estimates without spreadsheets

Progress tracking:
- Lifetime workouts, streak, volume, and average duration
- 16-week consistency heatmap
- Weekly volume trends and muscle-balance views
- Personal records and estimated 1RM trends
- CSV export for your full training history with RPT Pro

Private by design:
No account. No tracking. No ads. Your training data stays on device unless you export it yourself.

RPT Free includes the core training loop: workout logging, starter template, and basic stats. RPT Pro is a one-time lifetime upgrade for advanced analytics, unlimited custom templates, and full CSV export.

## Screenshot story

| Shot | Title | Target screen | Caption |
|---:|---|---|---|
| 1 | Start Heavy | Active workout logging | Open with your top set, then let RPT calculate every back-off set. |
| 2 | Plan the Session | Templates and workout tools | Reusable templates, warm-up ramps, plate math, and RPT weight drops stay one tap away. |
| 3 | Track Progress | Stats dashboard | See volume, consistency, PRs, and estimated 1RM trends from completed working sets. |
| 4 | Stay Private | Settings and export | No account, no tracking, on-device history, and CSV export when you unlock RPT Pro. |
| 5 | Unlock RPT Pro | RPT Pro upgrade | A lifetime upgrade for advanced analytics, unlimited custom templates, and full CSV export. |

## Privacy answers draft

Based on the current source and `RPT/PrivacyInfo.xcprivacy`:

| App Store Connect question | Draft answer |
|---|---|
| Does this app collect data? | No |
| Does this app use tracking? | No |
| Linked to user? | No data collected |
| Third-party advertising? | No |
| Analytics SDKs? | No |
| Account creation? | No |
| Data export | User-triggered CSV export only; data remains on device unless shared by the user |
| Required-reason APIs | UserDefaults only, declared in `PrivacyInfo.xcprivacy` |
| StoreKit purchase traffic | Apple StoreKit/App Store purchase services only for `rpt.pro.lifetime` |

## Reviewer notes draft

RPT is a private on-device workout log. The app has no account system, no tracking, no advertising SDK, and no analytics SDK. Training data is stored locally via SwiftData and only leaves the device if the user explicitly exports a CSV.

RPT Pro is a one-time lifetime in-app purchase (`rpt.pro.lifetime`) that unlocks advanced analytics, unlimited custom templates, and CSV export. The core logging flow remains usable without purchase.

RPT uses Apple's Standard EULA for App Store purchases: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/.

## Release gates before pressing Submit

- [ ] Build archive on Mac/Xcode and confirm `PrivacyInfo.xcprivacy` is present in the archive.
- [ ] Generate and inspect the Xcode privacy report.
- [ ] Create App Store Connect app record for bundle ID `com.MichaelMade.RPT`.
- [ ] Create non-consumable IAP `rpt.pro.lifetime`, attach review screenshot, and set launch price.
- [ ] Confirm App Store Connect is set to Apple's Standard EULA.
- [ ] Add GitHub Actions signing secrets listed in `docs/GitHubReleaseSetup.md`.
- [ ] Run GitHub `iOS CI` workflow green.
- [ ] Run `App Store Release Candidate` workflow with `upload_to_testflight=false` and inspect artifact.
- [ ] Run `App Store Release Candidate` workflow with `upload_to_testflight=true`.
- [ ] Device-check onboarding, starter template launch, workout save/resume, StoreKit purchase/restore, entitlement persistence, and CSV export.
- [ ] Capture final screenshots from the five-shot story.
