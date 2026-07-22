import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "app-store-release.yml"
VALIDATOR = ROOT / "ci" / "validate-release-secrets.sh"


class RPTReleaseWorkflowStaticTests(unittest.TestCase):
    def test_validator_checks_the_runtime_environment_names_exposed_by_workflow(self):
        workflow = WORKFLOW.read_text()
        validator = VALIDATOR.read_text()

        required_runtime_names = [
            "ASC_KEY_ID",
            "ASC_ISSUER_ID",
            "ASC_KEY_P8",
            "IOS_DISTRIBUTION_CERTIFICATE_BASE64",
            "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD",
            "IOS_PROVISIONING_PROFILE_BASE64",
            "IOS_CI_KEYCHAIN_PASSWORD",
        ]

        for name in required_runtime_names:
            with self.subTest(name=name):
                self.assertIn(f"      {name}:", workflow)
                self.assertRegex(validator, rf"(?m)^  {name}$")

    def test_workflow_maps_documented_app_store_connect_secret_names(self):
        workflow = WORKFLOW.read_text()

        expected_mappings = {
            "ASC_KEY_ID": "APP_STORE_CONNECT_API_KEY_ID",
            "ASC_ISSUER_ID": "APP_STORE_CONNECT_ISSUER_ID",
            "ASC_KEY_P8": "APP_STORE_CONNECT_API_KEY_P8",
        }

        for runtime_name, secret_name in expected_mappings.items():
            with self.subTest(runtime_name=runtime_name):
                self.assertIn(
                    f"{runtime_name}: ${{{{ secrets.{secret_name} }}}}",
                    workflow,
                )


if __name__ == "__main__":
    unittest.main()
