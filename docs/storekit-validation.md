# RPT Pro StoreKit Validation

RPT includes a local StoreKit configuration at `RPT/Configuration/RPTPro.storekit` so the paid unlock can be exercised in Xcode before submitting the 2.1 update.

## Product under test

- Product ID: `rpt.pro.lifetime`
- Type: Non-consumable
- Launch price: `$9.99`
- Display name: `RPT Pro Lifetime`
- Unlock promise: advanced analytics, unlimited custom templates, and CSV export

## Xcode setup

1. Open `RPT.xcodeproj` on a Mac with Xcode.
2. Select the `RPT` scheme.
3. Choose **Product > Scheme > Edit Scheme…**.
4. In **Run > Options**, set **StoreKit Configuration** to `RPT/Configuration/RPTPro.storekit`.
5. Run the app in a simulator or device.

## Smoke path

1. Launch RPT with a clean install.
2. Open the upgrade surface that uses `StoreKitPurchaseManager`.
3. Confirm the button renders `Unlock RPT Pro for $9.99` from the loaded local product.
4. Complete the sandbox purchase sheet.
5. Confirm the app shows `RPT Pro Unlocked` and the gated CSV export flow becomes available.
6. Relaunch the app and confirm entitlement refresh still unlocks Pro.
7. Use **Debug > StoreKit > Manage Transactions** to revoke the transaction, relaunch, and confirm the app returns to the locked state.
8. Run **Restore Purchases** after revoking/no purchase and confirm the no-purchase copy is clear.

## Release handoff

Before the 2.1 TestFlight/App Store update, repeat the same smoke path with the real App Store Connect product available. The `.storekit` file is excluded from the app target and must not appear in the archived app bundle.
