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
