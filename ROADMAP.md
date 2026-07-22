# RPT Roadmap

Last updated: 2026-07-22

RPT already has solid training depth: templates, exercise library, live workout logging, progression guidance, stats, export, and a basic three-screen onboarding flow. The biggest gaps are not more calculators or search polish; they are the release and revenue blockers that still stand between a good training app and a shippable product.

Audit summary:
- Core flows are implemented and covered by unit, static, and simulator UI tests: first launch, onboarding, template browsing, workout start/save/resume, exercise library, stats, settings, appearance persistence, and CSV export.
- SwiftData startup failures now block normal editing behind a recovery screen instead of silently switching to disposable storage.
- RPT Pro is implemented as a StoreKit 2 lifetime unlock for advanced analytics, unlimited templates, and CSV export. Pricing is always sourced from the user's App Store storefront.
- The release bundle contains the privacy manifest and encryption declaration, excludes the local StoreKit configuration, and has an App Store metadata/submission packet.
- Remaining release blockers are external: signing and App Store Connect setup, current screenshots, a signed TestFlight candidate, and real purchase/restore/revocation validation.

## Now (release/revenue-critical)

- [x] Define the paid tier and shipping business model.
  RPT is now defined as freemium in code and product copy: `RPT Free` keeps workout logging, the starter template, and basic stats free, while `RPT Pro` is planned as a one-time `$9.99` lifetime unlock for advanced analytics, unlimited custom templates, and CSV export. This gives StoreKit/paywall work a concrete target instead of a moving product question.

- [x] Add a release-grade monetization entry path.
  StoreKit 2 product loading, purchase, pending, restore, revocation, relaunch entitlement hydration, localized pricing, and all three Pro gates are implemented for `rpt.pro.lifetime`. Local validation uses `RPT/Configuration/RPTPro.storekit`; `docs/storekit-validation.md` defines the smoke path. The external gate is creating and attaching the real non-consumable in App Store Connect, then validating it on TestFlight.

- [ ] Define the App Store privacy answers and release disclosures.
  `PrivacyInfo.xcprivacy` now exists and declares on-device `UserDefaults` access only. `docs/app-store-privacy-answers.md` captures the current App Store Connect stance: no developer-collected data, no tracking, no analytics, user-initiated CSV export, and Apple-handled StoreKit purchases. The remaining compliance pass should generate the Xcode privacy report from the archived binary, confirm the generated Info.plist still ships with no unexpected permission strings, and verify App Store Connect accepts the answers.

- [x] Upgrade onboarding from explanation to activation.
  First-run now ends with a concrete handoff: start the built-in `Upper Body RPT` template, open template creation, or launch an empty first workout. Simulator UI tests validate onboarding, tab routing, save-for-later, resume, and returning-user behavior.

- [x] Build the App Store packaging plan.
  Version 2.1 update metadata now lives in `AppStoreReleasePlan`: subtitle, promo copy, keyword phrases capped under App Store Connect's 100-character limit, a five-shot screenshot story, support URL, and privacy URL. `AboutView` also exposes Support and Privacy links so the app has a real release-facing help/legal surface instead of burying those assets outside the product.

- [ ] Define the starter-template growth path after first workout.
  The current first-run flow gets users into action faster, but the next monetizable retention pass should decide what happens immediately after that first logged session: save-as-template prompts, follow-up workout nudges, or premium upgrade education.
  Progress: completed workouts now offer `Save as Template` (rep ranges and back-off percentages seeded from the logged sets, name de-duplicated automatically), joining the existing follow-up workout card. That action now respects the free-tier template limit and routes over-limit users to the RPT Pro upgrade, closing a bypass of the "unlimited custom templates" paid promise. Remaining: decide whether to surface a proactive post-completion prompt versus the current pull-based menu action.

## Next

- [x] Add GitHub-backed release automation.
  The repo has a shared `RPT` scheme, `iOS CI` workflow, manual `App Store Release Candidate` workflow, Fastlane `ci/archive/beta` lanes, signing-secret validation, archive export options, and an App Store submission packet. The current candidate still needs to be committed and pushed; GitHub secrets must be configured before archive/TestFlight jobs can run.

- [ ] Validate the bundled privacy manifest in a real archive.
  Confirm `PrivacyInfo.xcprivacy` is copied into the app bundle/archive, inspect the generated privacy report in Xcode, and make sure App Store Connect accepts the manifest without additional required-reason entries from future code or SDK changes.

- [x] Replace placeholder UI tests with real smoke paths.
  Cover first launch, onboarding completion, template/workout entry, and resume of an in-progress workout so the most important user journey has at least one regression net.
  `RPTUITests` covers first launch → onboarding → empty-workout activation → save-for-later → resume-from-Home, returning-user tab navigation, Light/Dark appearance persistence, a full design tour, and launch performance. These paths pass on the iOS simulator.

- [x] Add productized premium hooks before the paywall lands.
  CSV export now has the first feature-level upgrade affordance and unlock gate. Next candidates are unlimited custom templates and advanced analytics/progression views so the paid tier matches its launch promise.
  Template creation and duplication enforce six total free templates (three built-in plus three custom slots) with an upgrade sheet at every entry point. Stats reserves weekly volume charts, muscle-balance breakdowns, and personal-record leaderboards for Pro while keeping summary stats and consistency visible in the free tier. CSV export is also gated consistently.

- [ ] Tighten empty-state and no-data experiences across Home, Stats, and Templates.
  The app has depth for active users; the next pass should make the zero-workout and zero-template state feel intentional and confidence-building.
  Progress: Home's first-run hero now offers a Browse Templates path beside Start Workout, and the Stats zero state routes back to training with a Go Train action. The app also has a first VoiceOver pass: labeled set/exercise controls, steppers, overflow menus, and a summarized consistency heatmap. Remaining: a VoiceOver walkthrough on device and Dynamic Type spot checks.

- [x] Prepare support/legal surfaces for a public launch.
  About now links to the live support, privacy, and Apple Standard EULA URLs from `AppStoreReleasePlan`, a direct developer email path, and a plain-language privacy summary matching the release disclosures: no accounts, analytics, ads, tracking SDKs, or developer-run workout-data servers. Re-check final public support URL and App Store Connect's EULA setting before paid App Store submission.

## Later

- [ ] Expand retention features after the release path is stable.
  Consider reminders, streak coaching, saved goal presets, or richer training insights only after release and monetization fundamentals are in place.

- [ ] Explore broader platform fit.
  iPad is enabled today; revisit whether that experience is intentionally designed enough to market, and whether Apple Watch/widgets are worth the cost later.

- [ ] Refine brand and merchandising polish.
  App icon variants, screenshot styling, and visual brand upgrades matter, but they should follow the business model and core release package rather than lead it.

## Final release gates (needs Apple account/device)

- Confirm `PrivacyInfo.xcprivacy` is bundled in the archive and that the Xcode privacy report matches the manifest's "no data collected, no tracking, UserDefaults only" expectation.
- Validate the full first-run path: onboarding completion, app relaunch behavior, and whether users land in the right place after onboarding.
- Validate the new onboarding activation choices in simulator/device: starter-template launch, empty-workout launch, and one-time template-composer deep link.
- Run the core workout journey on device/simulator: start workout, edit sets, rest timer, save/discard handoff, complete workout, and follow-up workout flow.
- Confirm Stats, CSV export share sheet, and Settings mutations behave correctly in a real build.
- Inspect the generated launch screen, app icon rendering, tab bar layout, and iPad presentation in Xcode/simulator.
- Configure the seven GitHub Actions secrets and run the current candidate through `iOS CI`, archive-only release, and TestFlight workflows.
- Confirm the Paid Apps Agreement, banking, and tax setup; create `rpt.pro.lifetime` as a real non-consumable and attach it to version 2.1.
- Validate the real StoreKit purchase, pending, restore, revocation, and relaunch flow on device/TestFlight.
- Capture current iPhone and 13-inch iPad storefront screenshots plus the separate IAP review screenshot.
- Decide whether existing 2.0 users should be grandfathered into Pro; the current implementation requires the lifetime entitlement for all users.
