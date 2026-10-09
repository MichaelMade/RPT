# RPT — Reverse Pyramid Training

A focused iOS strength-training app built around **reverse pyramid training**: hit your heaviest set first while you're fresh, then drop the weight and chase reps on every back-off set.

Built with SwiftUI, SwiftData, and Swift Charts. iOS 18+, iPhone and iPad. All data stays on device.

## Features

### Training
- **Live workout logging** — fast steppers, tap-to-type set editing, RPE tracking, and per-exercise completion check-offs.
- **RPT back-off suggestions** — log your top set and the app calculates every back-off weight from your configured percentage drops (default −10% / −15%), always anchored to the top set.
- **Warm-up ramp generator** — one tap builds a low-fatigue ramp (bar × 10 → 40% × 5 → 60% × 3 → 80% × 1) toward your top set.
- **Progression coaching** — double-progression targets on every exercise: hit the top of your rep range and RPT tells you to load more next session.
- **Rest timer** — progress-ring countdown with ±15s adjustments, haptic and sound cues, and optional auto-start when you check off a set.
- **Follow-up workouts** — re-run any completed session at +2.5% load with one tap.

### Planning
- **Activation-focused onboarding** — first run now ends with a concrete next step: launch the starter template, open template creation, or begin an empty first workout instead of dumping new users into a generic shell.
- **Release packaging plan** — App Store subtitle, promo copy, keyword set, screenshot story, support URL, and privacy URL live in `AppStoreReleasePlan` with regression tests so version 2.1 metadata stays aligned with the freemium product promise.
- **Templates** — reusable routines with per-exercise set counts and rep ranges, duplicate/edit/start in one tap, and automatic weight pre-fill from your last session.
- **Exercise library** — seeded with common barbell/bodyweight movements and extensible with custom exercises.
- **Smart search** — exercises and templates match on names (including hyphenless forms like `pullup`), muscles, push/pull split intent, instruction cues, body regions (`upper body`, `legs`, `core`), categories (`bodyweight`, `isolation`), custom-move queries (`custom`, `my exercise`), and rep plans like `5x5` or `3x8-10` — with direct name matches ranked first.
- **Plate calculator** — visual bar-loading math for lb/kg with multiple bar types.
- **RPT calculator** — plan a session from any top-set weight.

### Insight
- **Stats dashboard** — lifetime workouts, day streak, total volume, average duration.
- **Consistency heatmap** — GitHub-style 16-week training calendar.
- **Weekly volume chart** — 12-week trend of completed working-set volume.
- **Muscle balance** — working sets per muscle group over the last 4 weeks.
- **Personal records** — best estimated 1RM (Epley) per exercise, plus per-exercise e1RM trend charts.
- **CSV export** — every logged set, shareable from Stats or Settings.

## Architecture

```
RPT/
├── App/            Entry point + root tab shell
├── DesignSystem/   Theme (brand palette/gradients), shared components, heatmap
├── Models/         SwiftData models: Workout, Exercise, ExerciseSet, WorkoutTemplate, User, UserSettings
├── Managers/       Data layer: DataManager (container), Workout/Exercise/Template/Settings/User managers
├── ViewModels/     Screen state: WorkoutSession coordinator + per-screen view models
├── Utilities/      Pure logic: OneRepMax, WarmupPlanner, ProgressionAdvisor, WorkoutCSVExporter
└── Views/          SwiftUI screens by feature: Home, Workout, Templates, Exercises, Stats, Settings
```

- **Single in-progress workout** is coordinated by `WorkoutSession`; starting a template or follow-up while a draft is open always routes through an explicit save-or-discard handoff.
- **Persistence** uses a single SwiftData container with rollback-on-failed-save in every mutation path.
- **Pure training math** (e1RM, warm-up ramps, progression, plate math, RPT drops) lives in dependency-free utilities covered by unit tests in `RPTTests/`.
- **On-device funnel analytics** (`FunnelAnalytics`) records anonymous install → onboarding → paywall → purchase events locally. No third-party SDK is linked. A TelemetryDeck sink stays a no-op until an app ID is supplied.

## Testing

`RPTTests/` covers manager logic, persistence/rollback behavior, model invariants, RPT back-off math (including the top-set anchoring regression test), warm-up planning, progression suggestions, plate math, CSV export, and name normalization. Run with **⌘U** in Xcode.

The repo now includes a shared `RPT` Xcode scheme plus GitHub Actions release automation:

- `.github/workflows/ios-ci.yml` runs the Python static regression suite, then builds and tests the app on GitHub-hosted macOS with code signing disabled.
- `.github/workflows/app-store-release.yml` creates a signed App Store release-candidate archive/IPA and can upload it to TestFlight once Apple signing/App Store Connect secrets are added.
- `fastlane/` contains `ci`, `archive`, and `beta` lanes.
- `docs/GitHubReleaseSetup.md` lists the exact repository secrets and Mac-side setup steps.
- `release/AppStoreSubmission.md` is the App Store Connect metadata/privacy/reviewer-notes packet.

## Privacy

No accounts and no third-party analytics SDKs. Training data never leaves the device except through the export you trigger yourself. RPT Pro purchase and restore actions use StoreKit/App Store purchase services only.

Anonymous conversion-funnel events (`install`, `onboarding_complete`, `paywall_view`, `purchase_start`, `purchase_success`, `purchase_fail`, `restore`) stay in on-device storage. They do not include a user ID, IDFA, Apple ID, or workout contents.

The About screen exposes a support email action, the public [`SUPPORT.md`](SUPPORT.md) page, a public privacy-policy link, and Apple's Standard EULA so App Store reviewers and users can reach the release disclosures from inside the app.

RPT ships a privacy manifest that declares on-device UserDefaults access for onboarding, workout-state recovery, settings toggles, and local funnel counts.

The current app binary does not declare camera, photo library, contacts, location, notifications, or tracking permissions. See `Privacy Policy`.

## How to read the funnel

Open **Settings → About RPT → On-device funnel**. The screen shows raw counts for the last 7 days and the last 30 days, plus paid / paywall for each window.

Read it as a local conversion ladder, not a live user census:

1. **Install** — first launch of a fresh install (existing users who already finished onboarding are not counted).
2. **Onboarding complete** — first successful activation choice or "browse the app first".
3. **Paywall view** — each time the RPT Pro upgrade screen appears. `source` is settings/stats/templates/workout_detail; `gate_reason` is `template_limit`, `csv_export`, or `advanced_stats` when a Pro gate opened the screen.
4. **Purchase start / success / fail** — StoreKit purchase attempts. Fail includes user cancel. `price` is the App Store-localized display price when available.
5. **Restore** — the user tapped Restore Purchases.

These counts are **this device only**. They are the sanity-check and debug report. Cross-device product analytics need a TelemetryDeck app ID (see `FunnelRemoteConfig.telemetryDeckAppID`) plus linking that SDK; until then the remote sink is a no-op and nothing is uploaded.

A StoreKit test purchase or restore should emit `paywall_view` (if you opened the upgrade screen), then `purchase_start` plus `purchase_success` or `purchase_fail`, and `restore` when Restore is used. Unit tests in `FunnelAnalyticsTests` and `StoreKitEntitlementSessionTests` cover that sequence.

## Monetization Direction

RPT is now scoped as a freemium app. `RPT Free` keeps the core training loop free: workout logging, the starter template, and basic stats with no signup.

`RPT Pro` is the paid tier planned for the version 2.1 update to the existing App Store app (Apple ID `6745407020`) at a one-time `Lifetime unlock` price of `$9.99` with App Store Connect product ID `rpt.pro.lifetime`. The upgrade package is defined in code and surfaced in-app; purchase, restore, entitlement refresh, CSV export gating, unlimited-template gating, and advanced Stats analytics gating are wired through StoreKit 2.

A local StoreKit test product now lives at `RPT/Configuration/RPTPro.storekit`, with the Mac/Xcode smoke path documented in `docs/storekit-validation.md`. StoreKit purchase sheets, restore behavior, and entitlement persistence still need Mac/Xcode verification before release.
