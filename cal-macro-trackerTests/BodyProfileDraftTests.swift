import SwiftData
import XCTest
@testable import cal_macro_tracker

final class BodyProfileDraftTests: XCTestCase {
    func testLosePacesMapToNegativeOffsetsInsideCalculatorRange() {
        var draft = BodyProfileDraft()
        draft.goalDirection = .lose

        for (pace, offset) in [(0.25, -250.0), (0.5, -500.0), (0.75, -750.0)] {
            draft.weeklyRate = pace
            XCTAssertEqual(draft.offset, offset)
        }
    }

    func testGainPacesStayWithinOffsetCeilingAndRoundTrip() {
        var draft = BodyProfileDraft()
        draft.goalDirection = .gain

        for (pace, offset) in [(0.25, 250.0), (0.5, 500.0)] {
            draft.weeklyRate = pace
            XCTAssertEqual(draft.offset, offset)

            let restored = BodyProfileDraft(profile: draft.makeProfile(preset: .balanced))
            XCTAssertEqual(restored.goalDirection, .gain)
            XCTAssertEqual(restored.weeklyRate, pace)
            XCTAssertEqual(restored.offset, offset)
        }
    }

    func testSavedLoseProfileRestoresDirectionPaceAndOffset() {
        var draft = BodyProfileDraft()
        draft.goalDirection = .lose
        draft.weeklyRate = 0.75

        let restored = BodyProfileDraft(profile: draft.makeProfile(preset: .lowCarb))

        XCTAssertEqual(restored.goalDirection, .lose)
        XCTAssertEqual(restored.weeklyRate, 0.75)
        XCTAssertEqual(restored.offset, -750)
    }

    func testEveryLosePaceAndSupportedGainPaceIsAcceptedByCalculator() throws {
        var draft = BodyProfileDraft()
        let pacesByDirection: [(GoalDirection, [Double])] = [
            (.lose, [0.25, 0.5, 0.75]),
            (.gain, [0.25, 0.5]),
        ]
        for (direction, paces) in pacesByDirection {
            draft.goalDirection = direction
            for pace in paces {
                draft.weeklyRate = pace
                XCTAssertNoThrow(try GoalCalculator.targetCalories(tdee: 2_000, offset: draft.offset, sex: .female))
            }
        }
    }

    func testNumericFieldsParseThroughNumericTextIncludingFractionalInches() throws {
        var draft = BodyProfileDraft()
        draft.ageText = "34.0"
        draft.setHeightText("172")
        draft.setWeightText("70.5")

        XCTAssertEqual(draft.age, 34)
        XCTAssertEqual(draft.heightCm, 172)
        XCTAssertEqual(draft.weightKg, 70.5)

        draft.ageText = "34.5"
        draft.setWeightText("heavy")
        XCTAssertNil(draft.age)
        XCTAssertNil(draft.weightKg)

        draft.changeUnitSystem(to: .imperial)
        draft.setHeightText("5")
        draft.setHeightInchesText("7.5")
        XCTAssertEqual(try XCTUnwrap(draft.heightCm), try GoalCalculator.cm(fromFeet: 5, inches: 7.5), accuracy: 0.000_1)
    }

    func testUnitToggleKeepsCanonicalMetricValuesAndRoundsOnlyForDisplay() {
        var draft = BodyProfileDraft()
        draft.setHeightText("170.4")
        draft.setWeightText("70.04")

        draft.changeUnitSystem(to: .imperial)
        XCTAssertEqual(draft.heightText, "5")
        XCTAssertEqual(draft.heightInchesText, "7")
        XCTAssertEqual(draft.weightText, "154")

        draft.changeUnitSystem(to: .metric)
        draft.changeUnitSystem(to: .imperial)
        draft.changeUnitSystem(to: .metric)

        XCTAssertEqual(draft.heightCm, 170.4)
        XCTAssertEqual(draft.weightKg, 70.04)
        XCTAssertEqual(draft.heightText, "170")
        XCTAssertEqual(draft.weightText, "70")
    }

    func testImperialInputStoresFullPrecisionMetricValues() throws {
        var draft = BodyProfileDraft()
        draft.changeUnitSystem(to: .imperial)
        draft.setHeightText("5")
        draft.setHeightInchesText("7.25")
        draft.setWeightText("154.5")

        XCTAssertEqual(try XCTUnwrap(draft.heightCm), (5 * 12 + 7.25) * 2.54, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(draft.weightKg), 154.5 * 0.45359237, accuracy: 1e-9)
    }

    @MainActor
    func testManualSaveUpdatesSingleActiveBodyProfileAndKeepsPreset() throws {
        let container = try ModelContainer(
            for: BodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let repository = BodyProfileRepository(modelContext: container.mainContext)
        var draft = BodyProfileDraft()
        draft.ageText = "34"
        draft.setHeightText("172")
        draft.setWeightText("70")
        draft.goalDirection = .lose

        try repository.save(draft.makeProfile(preset: .highProtein), operation: "Save body profile")
        try repository.save(draft.makeProfile(preset: .lowCarb), operation: "Save body profile")

        let profiles = try container.mainContext.fetch(FetchDescriptor<BodyProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.macroPreset, .lowCarb)
        XCTAssertEqual(profiles.first?.heightCm, 172)
        XCTAssertEqual(profiles.first?.weightKg, 70)
        XCTAssertEqual(profiles.first?.goalCalorieOffset, -500)
    }
}
