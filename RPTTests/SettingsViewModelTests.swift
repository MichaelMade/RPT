import XCTest
@testable import RPT

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var viewModel: SettingsViewModel!
    private var settingsManager: SettingsManager!

    private var originalRestTimerDuration: Int!
    private var originalRPTDrops: [Double]!
    private var originalShowRPE: Bool!
    private var originalDarkModePreference: DarkModePreference!

    override func setUp() {
        super.setUp()

        settingsManager = SettingsManager.shared
        originalRestTimerDuration = settingsManager.settings.restTimerDuration
        originalRPTDrops = settingsManager.settings.defaultRPTPercentageDrops
        originalShowRPE = settingsManager.settings.showRPE
        originalDarkModePreference = settingsManager.settings.darkModePreference

        viewModel = SettingsViewModel(settingsManager: settingsManager)
    }

    override func tearDown() {
        _ = settingsManager.updateRestTimerDurationSafely(seconds: originalRestTimerDuration)
        _ = settingsManager.updateRPTPercentageDropsSafely(drops: originalRPTDrops)
        _ = settingsManager.updateShowRPESafely(show: originalShowRPE)
        _ = settingsManager.updateDarkModePreferenceSafely(preference: originalDarkModePreference)

        viewModel = nil
        settingsManager = nil
        originalRestTimerDuration = nil
        originalRPTDrops = nil
        originalShowRPE = nil
        originalDarkModePreference = nil

        super.tearDown()
    }

    func testDefaultRPTPercentageDrops_invalidUpdateRevertsToPersistedValues() {
        let persistedDrops = settingsManager.settings.defaultRPTPercentageDrops

        viewModel.defaultRPTPercentageDrops = [0.0, 0.25, 0.10]

        XCTAssertEqual(
            viewModel.defaultRPTPercentageDrops,
            persistedDrops,
            "When SettingsManager rejects invalid drop values, SettingsViewModel should revert UI state to persisted settings"
        )
        XCTAssertEqual(
            settingsManager.settings.defaultRPTPercentageDrops,
            persistedDrops,
            "Invalid RPT drop edits should not mutate persisted settings"
        )
    }

    func testDefaultRPTPercentageDrops_validUpdatePersists() {
        let validDrops = [0.0, 0.15, 0.20]

        viewModel.defaultRPTPercentageDrops = validDrops

        XCTAssertEqual(viewModel.defaultRPTPercentageDrops, validDrops)
        XCTAssertEqual(settingsManager.settings.defaultRPTPercentageDrops, validDrops)
    }

    func testRestTimerDuration_invalidUpdateRevertsToPersistedValue() {
        let persistedDuration = settingsManager.settings.restTimerDuration

        viewModel.restTimerDuration = 0

        XCTAssertEqual(
            viewModel.restTimerDuration,
            persistedDuration,
            "When SettingsManager rejects invalid timer values, SettingsViewModel should restore the persisted duration"
        )
        XCTAssertEqual(settingsManager.settings.restTimerDuration, persistedDuration)
    }

    func testUpdateDropPercentage_clampsSecondBackoffToThirdBackoffMaximum() {
        viewModel.defaultRPTPercentageDrops = [0.0, 0.10, 0.15]

        viewModel.updateDropPercentage(at: 1, to: 25)

        XCTAssertEqual(viewModel.defaultRPTPercentageDrops, [0.0, 0.15, 0.15])
        XCTAssertEqual(settingsManager.settings.defaultRPTPercentageDrops, [0.0, 0.15, 0.15])
    }

    func testUpdateDropPercentage_clampsThirdBackoffToSecondBackoffMinimum() {
        viewModel.defaultRPTPercentageDrops = [0.0, 0.10, 0.15]

        viewModel.updateDropPercentage(at: 2, to: 5)

        XCTAssertEqual(viewModel.defaultRPTPercentageDrops, [0.0, 0.10, 0.10])
        XCTAssertEqual(settingsManager.settings.defaultRPTPercentageDrops, [0.0, 0.10, 0.10])
    }

    func testAllowedDropPercentageRange_tracksAdjacentSetConstraints() {
        viewModel.defaultRPTPercentageDrops = [0.0, 0.10, 0.20]

        XCTAssertEqual(viewModel.allowedDropPercentageRange(for: 1), 0...20)
        XCTAssertEqual(viewModel.allowedDropPercentageRange(for: 2), 10...30)
    }
}
