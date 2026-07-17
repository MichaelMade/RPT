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
- **Release packaging plan** — App Store subtitle, promo copy, keyword set, screenshot story, support URL, and privacy URL now live in `AppStoreReleasePlan` with regression tests so launch metadata stays aligned with the freemium product promise.
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

## Testing

`RPTTests/` covers manager logic, persistence/rollback behavior, model invariants, RPT back-off math (including the top-set anchoring regression test), warm-up planning, progression suggestions, plate math, CSV export, and name normalization. Run with **⌘U** in Xcode.

The repo now includes a shared `RPT` Xcode scheme plus GitHub Actions release automation:

- `.github/workflows/ios-ci.yml` builds and tests the app on GitHub-hosted macOS with code signing disabled.
- `.github/workflows/app-store-release.yml` creates a signed App Store release-candidate archive/IPA and can upload it to TestFlight once Apple signing/App Store Connect secrets are added.
- `fastlane/` contains `ci`, `archive`, and `beta` lanes.
- `docs/GitHubReleaseSetup.md` lists the exact repository secrets and Mac-side setup steps.
- `release/AppStoreSubmission.md` is the App Store Connect metadata/privacy/reviewer-notes packet.

## Privacy

No accounts and no analytics. Training data never leaves the device except through the export you trigger yourself. RPT Pro purchase and restore actions use StoreKit/App Store purchase services only.

The About screen now exposes a support email action, a public privacy-policy link, and Apple's Standard EULA so App Store reviewers and users can reach the release disclosures from inside the app.

RPT ships a privacy manifest that declares on-device UserDefaults access for onboarding, workout-state recovery, and settings toggles.

The current app binary does not declare camera, photo library, contacts, location, notifications, or tracking permissions. See `Privacy Policy`.

## Monetization Direction

RPT is now scoped as a freemium app. `RPT Free` keeps the core training loop free: workout logging, the starter template, and basic stats with no signup.

`RPT Pro` is the paid tier planned for the first App Store release at a one-time `Lifetime unlock` launch price of `$9.99` with App Store Connect product ID `rpt.pro.lifetime`. The upgrade package is defined in code and surfaced in-app; purchase, restore, entitlement refresh, CSV export gating, unlimited-template gating, and advanced Stats analytics gating are wired through StoreKit 2.

A local StoreKit test product now lives at `RPT/Configuration/RPTPro.storekit`, with the Mac/Xcode smoke path documented in `docs/storekit-validation.md`. StoreKit purchase sheets, restore behavior, and entitlement persistence still need Mac/Xcode verification before release.
