//
//  WeightUnitTests.swift
//  RPTTests
//
//  Units: conversion, loadable rounding, what a lifter may type, how a
//  load is written, and how a set stores a load that is not whole pounds.
//

import XCTest
@testable import RPT

final class WeightUnitConversionTests: XCTestCase {
    func testConversionIsExactAndRoundTrips() {
        XCTAssertEqual(WeightUnit.kilograms.converting(100, from: .pounds), 45.359237, accuracy: 0.000_001)
        XCTAssertEqual(WeightUnit.pounds.converting(100, from: .kilograms), 220.462_262, accuracy: 0.000_001)
        XCTAssertEqual(WeightUnit.pounds.converting(225, from: .pounds), 225)
        XCTAssertEqual(WeightUnit.kilograms.converting(62.5, from: .kilograms), 62.5)

        let roundTrip = WeightUnit.kilograms.converting(
            WeightUnit.pounds.converting(102.5, from: .kilograms),
            from: .pounds
        )
        XCTAssertEqual(roundTrip, 102.5, accuracy: 0.000_000_1)
    }

    func testNonFiniteValuesConvertToZero() {
        XCTAssertEqual(WeightUnit.kilograms.converting(.nan, from: .pounds), 0)
        XCTAssertEqual(WeightUnit.pounds.converting(.infinity, from: .kilograms), 0)
    }

    func testSuggestionsRoundToALoadableStep() {
        XCTAssertEqual(WeightUnit.pounds.roundedToIncrement(182.4), 180)
        XCTAssertEqual(WeightUnit.pounds.roundedToIncrement(182.6), 185)
        XCTAssertEqual(WeightUnit.kilograms.roundedToIncrement(90.9), 90)
        XCTAssertEqual(WeightUnit.kilograms.roundedToIncrement(91.3), 92.5)
        XCTAssertEqual(WeightUnit.kilograms.roundedToIncrement(-5), 0)
        XCTAssertEqual(WeightUnit.pounds.roundedToIncrement(.nan), 0)
    }

    func testBarAndIncrementMatchTheEquipment() {
        XCTAssertEqual(WeightUnit.pounds.emptyBarLoad, 45)
        XCTAssertEqual(WeightUnit.kilograms.emptyBarLoad, 20)
        XCTAssertEqual(WeightUnit.pounds.loadIncrement, 5)
        XCTAssertEqual(WeightUnit.kilograms.loadIncrement, 2.5)
    }

    func testOnlyTheUnitedStatesDefaultsToPounds() {
        XCTAssertEqual(WeightUnit.suggested(for: Locale(identifier: "en_US")), .pounds)
        XCTAssertEqual(WeightUnit.suggested(for: Locale(identifier: "en_GB")), .kilograms)
        XCTAssertEqual(WeightUnit.suggested(for: Locale(identifier: "de_DE")), .kilograms)
        XCTAssertEqual(WeightUnit.suggested(for: Locale(identifier: "en_CA")), .kilograms)
    }

    func testStoredChoiceIsReadFromDefaults() throws {
        let suiteName = "rpt.tests.weight-unit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertNil(WeightUnit.stored(in: defaults), "No choice yet: callers fall back to pounds")

        defaults.set(WeightUnit.kilograms.rawValue, forKey: WeightUnit.defaultsKey)
        XCTAssertEqual(WeightUnit.stored(in: defaults), .kilograms)

        defaults.set("stone", forKey: WeightUnit.defaultsKey)
        XCTAssertNil(WeightUnit.stored(in: defaults), "An unknown value is treated as no choice")
    }
}

final class WeightUnitDisplayTests: XCTestCase {
    func testPoundsAreWrittenWhole() {
        XCTAssertEqual(WeightUnit.pounds.string(for: 225), "225")
        XCTAssertEqual(WeightUnit.pounds.string(for: 220.46), "220")
        XCTAssertEqual(WeightUnit.pounds.formatted(135), "135 lb")
    }

    func testKilogramPlateValuesAreWrittenExactly() {
        XCTAssertEqual(WeightUnit.kilograms.string(for: 100), "100")
        XCTAssertEqual(WeightUnit.kilograms.string(for: 62.5), "62.5")
        XCTAssertEqual(WeightUnit.kilograms.string(for: 61.25), "61.25")
        XCTAssertEqual(WeightUnit.kilograms.string(for: 20.75), "20.75")
        XCTAssertEqual(WeightUnit.kilograms.string(for: 0.5), "0.5")
        XCTAssertEqual(WeightUnit.kilograms.formatted(102.5), "102.5 kg")
    }

    func testConvertedLoadsAreWrittenToOneDecimal() {
        // 225 lb is 102.058 kg: not a plate value, so do not pretend to
        // hundredths of a kilogram.
        XCTAssertEqual(WeightUnit.kilograms.string(forPounds: 225), "102.1")
        XCTAssertEqual(WeightUnit.kilograms.string(forPounds: 135), "61.2")
        XCTAssertEqual(WeightUnit.kilograms.formatted(pounds: 45), "20.4 kg")
        XCTAssertEqual(WeightUnit.kilograms.string(for: 99.96), "100")
    }

    func testPoundTotalsConvertOnceForDisplay() {
        XCTAssertEqual(WeightUnit.pounds.formatted(pounds: 1_102.31), "1102 lb")
        XCTAssertEqual(WeightUnit.kilograms.formatted(pounds: 1_102.311_31), "500 kg")
    }

    func testNothingIsWrittenForNoLoad() {
        XCTAssertEqual(WeightUnit.pounds.string(for: 0), "0")
        XCTAssertEqual(WeightUnit.kilograms.string(for: -3), "0")
        XCTAssertEqual(WeightUnit.kilograms.string(for: .nan), "0")
    }

    func testSameWrittenLoadIsTheSameLoad() {
        XCTAssertTrue(WeightUnit.pounds.displaysSameLoad(220, 220.46))
        XCTAssertFalse(WeightUnit.pounds.displaysSameLoad(220, 225))
        XCTAssertTrue(WeightUnit.kilograms.displaysSameLoad(102.1, 102.058))
        XCTAssertFalse(WeightUnit.kilograms.displaysSameLoad(100, 100.25))
    }
}

final class LoadEntryTests: XCTestCase {
    func testPoundsAcceptWholeNumbersOnly() {
        XCTAssertEqual(SetInputParser.load(from: "225", unit: .pounds), 225)
        XCTAssertEqual(SetInputParser.load(from: "  45 ", unit: .pounds), 45)
        XCTAssertNil(SetInputParser.load(from: "187.5", unit: .pounds))
        XCTAssertNil(SetInputParser.load(from: "10000", unit: .pounds))
    }

    func testKilogramsAcceptPlateFractions() {
        XCTAssertEqual(SetInputParser.load(from: "100", unit: .kilograms), 100)
        XCTAssertEqual(SetInputParser.load(from: "62.5", unit: .kilograms), 62.5)
        XCTAssertEqual(SetInputParser.load(from: "61,25", unit: .kilograms), 61.25, "Decimal comma is how most of the metric world types it")
        XCTAssertEqual(SetInputParser.load(from: "٦٢٫٥", unit: .kilograms), 62.5)
        XCTAssertEqual(SetInputParser.load(from: "100.", unit: .kilograms), 100)
    }

    func testKilogramsRejectWhatCannotBeALoad() {
        XCTAssertNil(SetInputParser.load(from: "61.255", unit: .kilograms), "Finer than any plate")
        XCTAssertNil(SetInputParser.load(from: "1.2.3", unit: .kilograms))
        XCTAssertNil(SetInputParser.load(from: "-60", unit: .kilograms))
        XCTAssertNil(SetInputParser.load(from: "4501", unit: .kilograms))
        XCTAssertNil(SetInputParser.load(from: "abc", unit: .kilograms))
    }

    func testClearedFieldIsZeroInEitherUnit() {
        XCTAssertEqual(SetInputParser.load(from: "", unit: .pounds), 0)
        XCTAssertEqual(SetInputParser.load(from: "   ", unit: .kilograms), 0)
    }
}

final class ExerciseSetLoadTests: XCTestCase {
    private func makeSet(weight: Int = 0, category: ExerciseCategory = .compound) -> ExerciseSet {
        let exercise = Exercise(name: "Bench", category: category, primaryMuscleGroups: [.chest])
        return ExerciseSet(weight: weight, reps: 5, exercise: exercise)
    }

    func testSetLoggedBeforeUnitsExistedIsWholePounds() {
        let set = makeSet(weight: 225)

        XCTAssertNil(set.loadValue)
        XCTAssertNil(set.loadUnitRaw)
        XCTAssertEqual(set.loadUnit, .pounds)
        XCTAssertEqual(set.load(in: .pounds), 225)
        XCTAssertEqual(set.exactPounds, 225)
        XCTAssertEqual(set.load(in: .kilograms), 102.058, accuracy: 0.001)
    }

    func testWholePoundLoadIsStoredExactlyAsBefore() {
        let set = makeSet()

        set.setLoad(185, in: .pounds)

        XCTAssertEqual(set.weight, 185)
        XCTAssertNil(set.loadValue, "Pound users' stores must not change shape")
        XCTAssertNil(set.loadUnitRaw)
    }

    func testKilogramLoadKeepsExactlyWhatWasTyped() {
        let set = makeSet()

        set.setLoad(102.5, in: .kilograms)

        XCTAssertEqual(set.loadValue, 102.5)
        XCTAssertEqual(set.loadUnit, .kilograms)
        XCTAssertEqual(set.load(in: .kilograms), 102.5)
        XCTAssertEqual(set.weight, 226, "Nearest whole pound, for everything that only needs heavier-or-lighter")
        XCTAssertEqual(set.exactPounds, 225.974, accuracy: 0.001)
    }

    func testKilogramTotalsSurviveTheTripThroughPounds() {
        let set = makeSet()
        set.setLoad(100, in: .kilograms)

        let volumeInPounds = set.exactPounds * 5
        XCTAssertEqual(WeightUnit.kilograms.formatted(pounds: volumeInPounds), "500 kg")
    }

    func testSmallKilogramLoadNeverReadsAsNoLoad() {
        let set = makeSet()

        set.setLoad(0.25, in: .kilograms)

        XCTAssertEqual(set.weight, 1)
        XCTAssertTrue(set.hasCompletedValues)
        XCTAssertEqual(set.load(in: .kilograms), 0.25)
    }

    func testClearingALoadClearsTheExactValueToo() {
        let set = makeSet()
        set.setLoad(60, in: .kilograms)

        set.setLoad(0, in: .kilograms)

        XCTAssertEqual(set.weight, 0)
        XCTAssertNil(set.loadValue)
        XCTAssertNil(set.loadUnitRaw)
        XCTAssertEqual(set.load(in: .kilograms), 0)
    }

    func testSwitchingAKilogramSetToPoundsDropsTheExactValue() {
        let set = makeSet()
        set.setLoad(100, in: .kilograms)

        set.setLoad(225, in: .pounds)

        XCTAssertEqual(set.weight, 225)
        XCTAssertNil(set.loadValue)
        XCTAssertEqual(set.loadUnit, .pounds)
    }

    func testSavingTheSameWrittenLoadInAnotherUnitDoesNotDegradeIt() {
        let kilogramSet = makeSet()
        kilogramSet.setLoad(100, in: .kilograms)

        // Shown to a pound user as 220 lb; they save reps only.
        kilogramSet.setLoad(220, in: .pounds)

        XCTAssertEqual(kilogramSet.load(in: .kilograms), 100, "Still exactly what was lifted")

        let poundSet = makeSet(weight: 225)
        // Shown to a kilogram user as 102.1 kg; they save reps only.
        poundSet.setLoad(102.1, in: .kilograms)

        XCTAssertEqual(poundSet.weight, 225)
        XCTAssertNil(poundSet.loadValue)
    }

    func testLoadAboveTheCeilingIsClamped() {
        let set = makeSet()

        set.setLoad(50_000, in: .kilograms)

        XCTAssertEqual(set.load(in: .kilograms), WeightUnit.kilograms.maximumLoad)
    }

    func testStoredLoadRestoresEverythingAfterAFailedSave() {
        let set = makeSet()
        set.setLoad(102.5, in: .kilograms)
        let stored = set.storedLoad

        set.setLoad(185, in: .pounds)
        set.restoreLoad(stored)

        XCTAssertEqual(set.load(in: .kilograms), 102.5)
        XCTAssertEqual(set.weight, 226)
        XCTAssertEqual(set.storedLoad, stored)
    }

    func testWholePoundWriteClearsAStaleExactValue() {
        let set = makeSet()
        set.setLoad(100, in: .kilograms)

        set.setWholePounds(135)

        XCTAssertEqual(set.exactPounds, 135)
        XCTAssertNil(set.loadValue)
    }

    func testHeavierMeansHeavierEvenWithinOnePound() {
        let lighter = makeSet()
        lighter.setLoad(100.5, in: .kilograms)   // 221.56 lb, rounds to 222
        let heavier = makeSet()
        heavier.setLoad(100.75, in: .kilograms)  // 222.12 lb, rounds to 222

        XCTAssertEqual(lighter.weight, heavier.weight, "The whole-pound shadows collide here")
        XCTAssertTrue(heavier.isBetterPerformance(than: lighter))
        XCTAssertFalse(lighter.isBetterPerformance(than: heavier))
    }

    func testSetIsWrittenInTheLiftersUnit() {
        let poundSet = makeSet(weight: 225)
        XCTAssertEqual(poundSet.formattedLoadReps(in: .pounds), "225 lb × 5 reps")
        XCTAssertEqual(poundSet.formattedLoadReps(in: .kilograms), "102.1 kg × 5 reps")

        let kilogramSet = makeSet()
        kilogramSet.setLoad(62.5, in: .kilograms)
        XCTAssertEqual(kilogramSet.formattedLoadReps(in: .kilograms), "62.5 kg × 5 reps")
        XCTAssertEqual(kilogramSet.formattedLoadReps(in: .pounds), "138 lb × 5 reps")

        let bodyweight = makeSet(category: .bodyweight)
        XCTAssertEqual(bodyweight.formattedLoadReps(in: .kilograms), "BW × 5 reps")
    }
}
