import XCTest
@testable import RPT

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private final class MockSettingsManager: SettingsManaging {
        var settings: UserSettings
        var shouldFailSave = false

        init(settings: UserSettings = UserSettings()) {
            self.settings = settings
        }

        func updateSettings() throws {
            if shouldFailSave {
                throw SettingsManager.SettingsError.saveFailed
            }
        }

        func updateSettingsSafely() -> Bool {
            (try? updateSettings()) != nil
        }

        func updateRestTimerDuration(seconds: Int) throws {
            guard !shouldFailSave else { throw SettingsManager.SettingsError.saveFailed }
            settings.restTimerDuration = seconds
        }

        func updateRestTimerDurationSafely(seconds: Int) -> Bool {
            (try? updateRestTimerDuration(seconds: seconds)) != nil
        }

        func updateRPTPercentageDrops(drops: [Double]) throws {
            guard !shouldFailSave else { throw SettingsManager.SettingsError.saveFailed }
            settings.defaultRPTPercentageDrops = drops
        }

        func updateRPTPercentageDropsSafely(drops: [Double]) -> Bool {
            (try? updateRPTPercentageDrops(drops: drops)) != nil
        }

        func updateShowRPE(show: Bool) throws {
            guard !shouldFailSave else { throw SettingsManager.SettingsError.saveFailed }
            settings.showRPE = show
        }

        func updateShowRPESafely(show: Bool) -> Bool {
            (try? updateShowRPE(show: show)) != nil
        }

        func updateDarkModePreference(preference: DarkModePreference) throws {
            guard !shouldFailSave else { throw SettingsManager.SettingsError.saveFailed }
            settings.darkModePreference = preference
        }

        func updateDarkModePreferenceSafely(preference: DarkModePreference) -> Bool {
            (try? updateDarkModePreference(preference: preference)) != nil
        }

        func resetToDefaults() throws {
            guard !shouldFailSave else { throw SettingsManager.SettingsError.saveFailed }
            settings.restTimerDuration = UserSettings.defaultRestTimerDuration
            settings.defaultRPTPercentageDrops = UserSettings.defaultRPTPercentageDrops
            settings.showRPE = true
            settings.darkModePreference = .system
        }

        func resetToDefaultsSafely() -> Bool {
            (try? resetToDefaults()) != nil
        }

        func calculateRPTExample(firstSetWeight: Int) -> String {
            "202 → 190 lb"
        }
    }

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

    func testShowRPE_failedSaveRevertsAndSurfacesErrorMessage() {
        let mock = MockSettingsManager(settings: UserSettings(showRPE: true))
        mock.shouldFailSave = true
        let failingViewModel = SettingsViewModel(settingsManager: mock)

        failingViewModel.showRPE = false

        XCTAssertTrue(failingViewModel.showRPE)
        XCTAssertEqual(failingViewModel.saveErrorMessage, "RPE visibility changes could not be saved.")
    }

    func testResetToDefaults_failedSavePreservesSettingsAndSurfacesErrorMessage() {
        let mockSettings = UserSettings(restTimerDuration: 135)
        mockSettings.defaultRPTPercentageDrops = [0.0, 0.15, 0.20]
        mockSettings.showRPE = false
        mockSettings.darkModePreference = .dark

        let mock = MockSettingsManager(settings: mockSettings)
        mock.shouldFailSave = true
        let failingViewModel = SettingsViewModel(settingsManager: mock)

        failingViewModel.resetToDefaults()

        XCTAssertEqual(failingViewModel.restTimerDuration, 135)
        XCTAssertEqual(failingViewModel.defaultRPTPercentageDrops, [0.0, 0.15, 0.20])
        XCTAssertFalse(failingViewModel.showRPE)
        XCTAssertEqual(failingViewModel.darkModePreference, .dark)
        XCTAssertEqual(failingViewModel.saveErrorMessage, "Settings could not be reset right now.")
    }
}
