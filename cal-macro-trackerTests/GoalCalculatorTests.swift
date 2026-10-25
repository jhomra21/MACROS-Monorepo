import XCTest
@testable import cal_macro_tracker

final class GoalCalculatorTests: XCTestCase {
    func testRejectsNonPositiveAndOutOfRangeMeasurements() {
        XCTAssertThrowsError(try GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 0, weightKg: 70))
        XCTAssertThrowsError(try GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 165, weightKg: -1))
        XCTAssertThrowsError(try GoalCalculator.bmr(sex: .female, ageYears: 0, heightCm: 165, weightKg: 70))
        XCTAssertThrowsError(try GoalCalculator.bmr(sex: .female, ageYears: 121, heightCm: 165, weightKg: 70))
    }

    func testRejectsNonFiniteMeasurements() {
        XCTAssertThrowsError(try GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: .nan, weightKg: 70))
        XCTAssertThrowsError(try GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 165, weightKg: .infinity))
        XCTAssertThrowsError(try GoalCalculator.tdee(bmr: .infinity, activity: .moderate))
        XCTAssertThrowsError(try GoalCalculator.targetCalories(tdee: 2_000, offset: .infinity, sex: .female))
        XCTAssertThrowsError(try GoalCalculator.macroGrams(calories: .nan, preset: .balanced))
    }

    func testUnspecifiedSexUsesMidpointMifflinStJeorConstant() throws {
        let female = try GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 170, weightKg: 70)
        let male = try GoalCalculator.bmr(sex: .male, ageYears: 30, heightCm: 170, weightKg: 70)
        let unspecified = try GoalCalculator.bmr(sex: .unspecified, ageYears: 30, heightCm: 170, weightKg: 70)

        XCTAssertEqual(unspecified, (female + male) / 2, accuracy: 0.0001)
    }

    func testBmrMatchesHandCalculatedMifflinStJeorReferences() throws {
        // Mifflin-St Jeor: BMR = 10 * kg + 6.25 * cm - 5 * years + s
        // s = +5 male, -161 female, -78 unspecified (midpoint of +5 and -161).

        // Female, 60 kg, 165 cm, 30 y: 600 + 1031.25 - 150 - 161 = 1320.25
        XCTAssertEqual(
            try GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 165, weightKg: 60), 1_320.25, accuracy: 0.5)
        // Female, 72 kg, 170 cm, 45 y: 720 + 1062.5 - 225 - 161 = 1396.5
        XCTAssertEqual(
            try GoalCalculator.bmr(sex: .female, ageYears: 45, heightCm: 170, weightKg: 72), 1_396.5, accuracy: 0.5)
        // Male, 80 kg, 180 cm, 35 y: 800 + 1125 - 175 + 5 = 1755
        XCTAssertEqual(
            try GoalCalculator.bmr(sex: .male, ageYears: 35, heightCm: 180, weightKg: 80), 1_755, accuracy: 0.5)
        // Male, 65 kg, 175 cm, 50 y: 650 + 1093.75 - 250 + 5 = 1498.75
        XCTAssertEqual(
            try GoalCalculator.bmr(sex: .male, ageYears: 50, heightCm: 175, weightKg: 65), 1_498.75, accuracy: 0.5)
        // Unspecified, 70 kg, 170 cm, 30 y: 700 + 1062.5 - 150 - 78 = 1534.5
        XCTAssertEqual(
            try GoalCalculator.bmr(sex: .unspecified, ageYears: 30, heightCm: 170, weightKg: 70), 1_534.5, accuracy: 0.5)
        // Unspecified, 55 kg, 160 cm, 25 y: 550 + 1000 - 125 - 78 = 1347
        XCTAssertEqual(
            try GoalCalculator.bmr(sex: .unspecified, ageYears: 25, heightCm: 160, weightKg: 55), 1_347, accuracy: 0.5)
    }

    func testClampsBelowSafeMinimumForEachSex() throws {
        let female = try GoalCalculator.targetCalories(tdee: 1_000, offset: -750, sex: .female)
        let male = try GoalCalculator.targetCalories(tdee: 1_000, offset: -750, sex: .male)
        let unspecified = try GoalCalculator.targetCalories(tdee: 1_000, offset: -750, sex: .unspecified)

        XCTAssertEqual(female.calories, 1_200)
        XCTAssertEqual(male.calories, 1_500)
        XCTAssertEqual(unspecified.calories, 1_200)
        XCTAssertTrue(female.isBelowSafeMinimum)
        XCTAssertTrue(male.isBelowSafeMinimum)
        XCTAssertTrue(unspecified.isBelowSafeMinimum)
    }

    func testActivityMultipliersAndMacroPresetPercentages() throws {
        let bmr = 1_500.0
        XCTAssertEqual(try GoalCalculator.tdee(bmr: bmr, activity: .sedentary), 1_800)
        XCTAssertEqual(try GoalCalculator.tdee(bmr: bmr, activity: .light), 2_062.5)
        XCTAssertEqual(try GoalCalculator.tdee(bmr: bmr, activity: .moderate), 2_325)
        XCTAssertEqual(try GoalCalculator.tdee(bmr: bmr, activity: .active), 2_587.5)
        XCTAssertEqual(try GoalCalculator.tdee(bmr: bmr, activity: .veryActive), 2_850)

        for preset in GoalMacroPreset.allCases where preset != .custom {
            XCTAssertEqual(preset.proteinPercent + preset.carbPercent + preset.fatPercent, 100)
        }
    }

    func testRoundedMacroGramsRecomputeCaloriesWithinTwoPercent() throws {
        for preset in GoalMacroPreset.allCases where preset != .custom {
            let draft = try GoalCalculator.macroGrams(calories: 2_137, preset: preset)
            let recomputedCalories = draft.proteinGoalGrams * 4
                + draft.carbGoalGrams * 4
                + draft.fatGoalGrams * 9

            XCTAssertEqual(draft.calorieGoal, recomputedCalories)
            XCTAssertEqual(draft.proteinGoalGrams / 5, (draft.proteinGoalGrams / 5).rounded())
            XCTAssertEqual(draft.carbGoalGrams / 5, (draft.carbGoalGrams / 5).rounded())
            XCTAssertEqual(draft.fatGoalGrams / 5, (draft.fatGoalGrams / 5).rounded())
            XCTAssertLessThanOrEqual(abs(recomputedCalories - 2_137) / 2_137, 0.02)
        }
    }

    func testMacroCaloriesStayAtOrAboveClampedTargetWithinTwoPercent() throws {
        let safeMinimums = [
            try GoalCalculator.targetCalories(tdee: 1_000, offset: -750, sex: .female).calories,
            try GoalCalculator.targetCalories(tdee: 1_000, offset: -750, sex: .unspecified).calories,
            try GoalCalculator.targetCalories(tdee: 1_000, offset: -750, sex: .male).calories,
        ]
        let typicalTargets = [1_437.5, 1_673, 1_872, 2_137, 2_463, 3_011]

        for calories in safeMinimums + typicalTargets {
            for preset in GoalMacroPreset.allCases where preset != .custom {
                let draft = try GoalCalculator.macroGrams(calories: calories, preset: preset)
                let recomputedCalories = draft.proteinGoalGrams * 4
                    + draft.carbGoalGrams * 4
                    + draft.fatGoalGrams * 9

                XCTAssertEqual(draft.calorieGoal, recomputedCalories)
                XCTAssertGreaterThanOrEqual(recomputedCalories, calories, "\(preset) at \(calories) kcal")
                XCTAssertLessThanOrEqual(recomputedCalories, calories * 1.02, "\(preset) at \(calories) kcal")
            }
        }
    }

    func testUnitConversionsUseExactConstantsWithoutIntermediateRounding() throws {
        XCTAssertEqual(try GoalCalculator.kg(fromPounds: 100), 100 * 0.45359237, accuracy: 1e-12)
        XCTAssertEqual(GoalCalculator.pounds(fromKg: 45.359237), 100, accuracy: 1e-12)
        XCTAssertEqual(try GoalCalculator.cm(fromFeet: 5, inches: 7.25), 170.815, accuracy: 1e-12)

        for pounds in [1.0, 154.3, 201.37] {
            let kilograms = try GoalCalculator.kg(fromPounds: pounds)
            XCTAssertEqual(GoalCalculator.pounds(fromKg: kilograms), pounds, accuracy: 1e-12)
        }
    }

    func testImperialConversionsRoundTrip() throws {
        let kilograms = try GoalCalculator.kg(fromPounds: 154)
        let pounds = GoalCalculator.pounds(fromKg: kilograms)
        let centimeters = try GoalCalculator.cm(fromFeet: 5, inches: 7)
        let (feet, inches) = GoalCalculator.feetAndInches(fromCm: centimeters)

        XCTAssertEqual(pounds, 154, accuracy: 0.2)
        XCTAssertEqual(feet, 5)
        XCTAssertEqual(inches, 7, accuracy: 0.2)
    }
}
