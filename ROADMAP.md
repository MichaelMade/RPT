# RPT Roadmap

Last updated: 2026-06-17

RPT already has solid training depth: templates, exercise library, live workout logging, progression guidance, stats, export, and a basic three-screen onboarding flow. The biggest gaps are not more calculators or search polish; they are the release and revenue blockers that still stand between a good training app and a shippable product.

Audit summary:
- Core flows look substantially complete on paper: first launch, template browsing, workout start/resume, exercise library, stats, settings, and CSV export all exist, with meaningful unit-test coverage around data integrity and workout math.
- Crash-safety looks better than average for this stage because the app centralizes persistence through shared managers and already has rollback/error-path tests, but UI-flow correctness is still largely unverified in this Linux runner.
- Onboarding now gets users into action faster via a starter-template, custom-template, or empty-workout handoff, but the post-first-workout retention and monetization path is still undefined.
- Monetization is not implemented yet. There is no StoreKit/paywall/subscription code, and the paid tier is not defined in product terms.
- Release assets/compliance are incomplete: the project generates a launch screen and has an app icon, but there is no privacy manifest, no explicit App Store metadata/screenshots plan, and UI tests are still placeholder-level.

## Now (release/revenue-critical)

- [x] Define the paid tier and shipping business model.
  RPT is now defined as freemium in code and product copy: `RPT Free` keeps workout logging, the starter template, and basic stats free, while `RPT Pro` is planned as a one-time `$9.99` lifetime unlock for advanced analytics, unlimited custom templates, and CSV export. This gives StoreKit/paywall work a concrete target instead of a moving product question.

- [ ] Add a release-grade monetization entry path.
  The first StoreKit 2 slice is now wired against App Store Connect product ID `rpt.pro.lifetime`: RPT loads the lifetime product, listens for transaction updates, purchases/restores the unlock, refreshes entitlement state, and gates CSV export behind `RPT Pro`. A local Mac validation product now exists at `RPT/Configuration/RPTPro.storekit`, and `docs/storekit-validation.md` defines the purchase, restore, revoke, and relaunch smoke path. The remaining release work is Mac/Xcode validation with that local configuration, then App Store Connect product validation, and then extending entitlement checks to unlimited templates and advanced analytics.

- [ ] Define the App Store privacy answers and release disclosures.
  `PrivacyInfo.xcprivacy` now exists and declares on-device `UserDefaults` access only. The next compliance pass should generate the Xcode privacy report, answer App Store Connect's data-collection questions from the built binary, confirm the generated Info.plist still ships with no unexpected permission strings, and confirm StoreKit-only purchase traffic does not require additional privacy disclosures.

- [x] Upgrade onboarding from explanation to activation.
  First-run now ends with a concrete handoff: start the built-in `Upper Body RPT` template, open template creation, or launch an empty first workout. The remaining release risk is UI validation in a real build to confirm the handoff, tab routing, and workout presentation feel correct on device.

- [x] Build the App Store packaging plan.
  First-pass launch metadata now lives in `AppStoreReleasePlan`: subtitle, promo copy, keyword phrases capped under App Store Connect's 100-character limit, a five-shot screenshot story, support URL, and privacy URL. `AboutView` also exposes Support and Privacy links so the app has a real launch-facing help/legal surface instead of burying those assets outside the product.

- [ ] Define the starter-template growth path after first workout.
  The current first-run flow gets users into action faster, but the next monetizable retention pass should decide what happens immediately after that first logged session: save-as-template prompts, follow-up workout nudges, or premium upgrade education.
  Progress: completed workouts now offer `Save as Template` (rep ranges and back-off percentages seeded from the logged sets, name de-duplicated automatically), joining the existing follow-up workout card. Remaining: decide whether to surface a proactive post-completion prompt versus the current pull-based menu action.

## Next

- [x] Add GitHub-backed release automation.
  The repo now has a shared `RPT` scheme, `iOS CI` workflow, manual `App Store Release Candidate` workflow, Fastlane `ci/archive/beta` lanes, signing-secret validation, archive export options, and an App Store submission packet. Publishing is blocked only on Apple signing/App Store Connect secrets from Michael's Apple account.

- [ ] Validate the bundled privacy manifest in a real archive.
  Confirm `PrivacyInfo.xcprivacy` is copied into the app bundle/archive, inspect the generated privacy report in Xcode, and make sure App Store Connect accepts the manifest without additional required-reason entries from future code or SDK changes.

- [ ] Replace placeholder UI tests with one real smoke path.
  Cover first launch, onboarding completion, template/workout entry, and resume of an in-progress workout so the most important user journey has at least one regression net.
  Progress: `RPTUITests` now covers first launch → onboarding → empty-workout activation → save-for-later → resume-from-Home, plus a returning-user tab-bar check. Needs a first run on a Mac/simulator to confirm the element queries.

- [ ] Add productized premium hooks before the paywall lands.
  CSV export now has the first feature-level upgrade affordance and unlock gate. Next candidates are unlimited custom templates and advanced analytics/progression views so the paid tier matches its launch promise.
  Progress: template creation and duplication now enforce a free-tier limit (`MonetizationPlan.freeTemplateLimit`, currently 3) with an upgrade sheet at every entry point, matching the "unlimited custom templates" Pro promise. Remaining: gate advanced analytics, and revisit the limit value before launch.

- [ ] Tighten empty-state and no-data experiences across Home, Stats, and Templates.
  The app has depth for active users; the next pass should make the zero-workout and zero-template state feel intentional and confidence-building.

- [ ] Prepare support/legal surfaces for a public launch.
  About now links to live support and privacy URLs from `AppStoreReleasePlan`, plus a direct Contact Support email path. Remaining: add Terms/EULA if App Store review or the paid unlock requires it, and verify the external pages match the in-app privacy copy.

## Later

- [ ] Expand retention features after the release path is stable.
  Consider reminders, streak coaching, saved goal presets, or richer training insights only after release and monetization fundamentals are in place.

- [ ] Explore broader platform fit.
  iPad is enabled today; revisit whether that experience is intentionally designed enough to market, and whether Apple Watch/widgets are worth the cost later.

- [ ] Refine brand and merchandising polish.
  App icon variants, screenshot styling, and visual brand upgrades matter, but they should follow the business model and core release package rather than lead it.

## Verify on Mac (needs Xcode/device)

- Confirm `PrivacyInfo.xcprivacy` is bundled in the archive and that the Xcode privacy report matches the manifest's "no data collected, no tracking, UserDefaults only" expectation.
- Validate the full first-run path: onboarding completion, app relaunch behavior, and whether users land in the right place after onboarding.
- Validate the new onboarding activation choices in simulator/device: starter-template launch, empty-workout launch, and one-time template-composer deep link.
- Run the core workout journey on device/simulator: start workout, edit sets, rest timer, save/discard handoff, complete workout, and follow-up workout flow.
- Confirm Stats, CSV export share sheet, and Settings mutations behave correctly in a real build.
- Inspect the generated launch screen, app icon rendering, tab bar layout, and iPad presentation in Xcode/simulator.
- Replace placeholder `RPTUITests` coverage with an actual smoke test and run it in Xcode.
- Validate the `rpt.pro.lifetime` StoreKit 2 flow in Xcode: product loading, purchase sheet, pending state, transaction updates, restore purchases, CSV export unlocked state, and entitlement persistence after relaunch.
- Validate the new `RPT Pro` upgrade screen, Stats promo card, and Settings entry point in simulator/device so copy, navigation, and pricing presentation feel intentional before App Store screenshots are captured.
