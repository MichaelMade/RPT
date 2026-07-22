import json
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
STOREKIT_PATH = REPO_ROOT / "RPT" / "Configuration" / "RPTPro.storekit"
MONETIZATION_PLAN_PATH = REPO_ROOT / "RPT" / "App" / "MonetizationPlan.swift"
DOC_PATH = REPO_ROOT / "docs" / "storekit-validation.md"
README_PATH = REPO_ROOT / "README.md"
ROADMAP_PATH = REPO_ROOT / "ROADMAP.md"
PROJECT_PATH = REPO_ROOT / "RPT.xcodeproj" / "project.pbxproj"


class RPTStoreKitConfigurationStaticTests(unittest.TestCase):
    def setUp(self):
        self.config = json.loads(STOREKIT_PATH.read_text())
        self.monetization_plan = MONETIZATION_PLAN_PATH.read_text()
        self.doc = DOC_PATH.read_text()

    def test_local_storekit_config_defines_rpt_pro_lifetime_product(self):
        products = self.config.get("products", [])
        self.assertEqual(len(products), 1)
        product = products[0]

        self.assertEqual(product["productID"], "rpt.pro.lifetime")
        self.assertEqual(product["type"], "NonConsumable")
        self.assertEqual(product["displayPrice"], "9.99")
        self.assertEqual(product["referenceName"], "RPT Pro Lifetime Unlock")
        self.assertFalse(product["familyShareable"])

    def test_storekit_config_matches_monetization_plan(self):
        product_id = self.config["products"][0]["productID"]
        self.assertIn(f'static let proProductID = "{product_id}"', self.monetization_plan)
        purchase_manager = (REPO_ROOT / "RPT" / "App" / "StoreKitPurchaseManager.swift").read_text()
        self.assertIn("Product.products(for: MonetizationPlan.proProductIDs)", purchase_manager)
        self.assertNotIn("?? MonetizationPlan", purchase_manager)
        self.assertIn("transaction.revocationDate == nil", purchase_manager)
        load_products = re.search(
            r"func loadProducts\(\) async \{.*?\n    \}",
            purchase_manager,
            re.DOTALL,
        )
        self.assertIsNotNone(load_products)
        load_products_body = load_products.group(0)
        for protected_state in [".purchasing", ".restoring", ".pendingApproval"]:
            self.assertIn(protected_state, load_products_body)
        self.assertNotIn("guard !state.isBusy", load_products_body)
        update_handler = re.search(
            r"private func handle\(transactionUpdate.*?\n    \}",
            purchase_manager,
            re.DOTALL,
        )
        self.assertIsNotNone(update_handler)
        handler_body = update_handler.group(0)
        self.assertIn("grantProEntitlement()", handler_body)
        self.assertIn("await refreshPurchasedState()", handler_body)
        self.assertIn("if !hasEntitlement", handler_body)
        self.assertIn("revokeProEntitlement()", handler_body)
        self.assertLess(
            handler_body.index("grantProEntitlement()"),
            handler_body.index("await transaction.finish()"),
        )
        self.assertLess(
            handler_body.index("await transaction.finish()"),
            handler_body.index("await refreshPurchasedState()"),
        )

    def test_localized_product_copy_covers_paid_tier_promise(self):
        localization = self.config["products"][0]["localizations"][0]
        description = localization["description"]

        self.assertEqual(localization["locale"], "en_US")
        self.assertEqual(localization["displayName"], "RPT Pro Lifetime")
        self.assertLessEqual(len(description), 45)
        plan_lower = self.monetization_plan.lower()
        description_lower = description.lower()
        for promise in ["analytics", "templates", "csv export"]:
            self.assertIn(promise, description_lower)
            self.assertIn(promise, plan_lower)

    def test_local_storekit_config_is_excluded_from_app_resources(self):
        project = PROJECT_PATH.read_text()
        self.assertIn("PBXFileSystemSynchronizedBuildFileExceptionSet", project)
        self.assertIn("Configuration/RPTPro.storekit", project)
        self.assertRegex(
            project,
            r"membershipExceptions = \(\s*Configuration/RPTPro\.storekit,\s*\);",
        )

    def test_validation_doc_includes_full_mac_smoke_path(self):
        required_steps = [
            "Product > Scheme > Edit Scheme",
            "StoreKit Configuration",
            "RPT/Configuration/RPTPro.storekit",
            "Unlock RPT Pro for $9.99",
            "RPT Pro Unlocked",
            "Relaunch the app",
            "Manage Transactions",
            "Restore Purchases",
        ]

        for step in required_steps:
            self.assertIn(step, self.doc)

    def test_release_docs_point_to_storekit_validation_artifacts(self):
        readme = README_PATH.read_text()
        roadmap = ROADMAP_PATH.read_text()

        for text in [readme, roadmap]:
            self.assertIn("RPT/Configuration/RPTPro.storekit", text)
            self.assertIn("docs/storekit-validation.md", text)

    def test_storekit_json_has_expected_top_level_shape(self):
        self.assertEqual(self.config["version"], {"major": 4, "minor": 0})
        self.assertEqual(self.config["subscriptionGroups"], [])
        self.assertEqual(self.config["nonRenewingSubscriptions"], [])
        self.assertIn("settings", self.config)
        self.assertFalse(self.config["settings"].get("_failTransactionsEnabled"))


if __name__ == "__main__":
    unittest.main()
