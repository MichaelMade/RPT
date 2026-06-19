# GitHub Release Setup for RPT

This repo now has two GitHub Actions workflows:

| Workflow | Trigger | Purpose |
|---|---|---|
| `iOS CI` | PR, push to `master`, manual | Simulator build + test gate with code signing disabled |
| `App Store Release Candidate` | Manual | Signed archive/export and optional TestFlight upload |

## One-time repository secrets

Add these in **GitHub → RPT → Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Value |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | Raw `.p8` private key text for the App Store Connect API key |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-encoded `.p12` Apple Distribution certificate |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` certificate |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store provisioning profile for `com.MichaelMade.RPT` |
| `IOS_CI_KEYCHAIN_PASSWORD` | Random CI-only keychain password |

## Generate the base64 values on Michael's Mac

```bash
base64 -i Certificates.p12 | pbcopy
base64 -i RPT_AppStore.mobileprovision | pbcopy
```

Paste each copied value into the matching GitHub secret.

## Manual release flow

1. Push this branch and open/merge the PR.
2. Confirm `iOS CI` passes on GitHub-hosted macOS.
3. In App Store Connect, create/verify:
   - App record for bundle ID `com.MichaelMade.RPT`
   - Non-consumable IAP product ID `rpt.pro.lifetime`
   - Privacy answers from `release/AppStoreSubmission.md`
4. Run **Actions → App Store Release Candidate** with `upload_to_testflight=false`.
5. Download and inspect the artifact: `RPT-release-candidate-<build>`.
6. Re-run the workflow with `upload_to_testflight=true`.
7. Test the TestFlight build on device before App Store review.

## Local Mac validation commands

```bash
# Build/test without signing
xcodebuild test \
  -project RPT.xcodeproj \
  -scheme RPT \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO

# Signed archive from Xcode Organizer remains acceptable if CI signing is not ready.
```

## Current non-automatable gates

These require Michael's Apple account/Mac context, not Linux:

- Apple Developer/App Store Connect API key creation
- Distribution certificate export
- App Store provisioning profile download
- Simulator/device validation of StoreKit purchase sheets
- Final screenshots and App Review submission click
