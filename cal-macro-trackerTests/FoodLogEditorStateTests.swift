import XCTest
@testable import cal_macro_tracker

@MainActor
final class FoodLogEditorStateTests: XCTestCase {
    // Failure modes are recorded in docs/evidence/camera-inline-details/failure-modes.md.
    func testOpeningIsClean() {
        XCTAssertFalse(editor().isDirty)
    }

    func testNameEditAndRevert() {
        var state = editor()
        state.draft.name = "Changed"
        XCTAssertTrue(state.isDirty)
        state.draft.name = "Oats"
        XCTAssertFalse(state.isDirty)
    }

    func testWhitespaceOnlyNameIsClean() {
        var state = editor()
        state.draft.name = " Oats\n"
        XCTAssertFalse(state.isDirty)
    }

    func testNutrientEditAndRevert() {
        var state = editor()
        state.numericText.calories = "200"
        XCTAssertTrue(state.isDirty)
        state.numericText.calories = "160"
        XCTAssertFalse(state.isDirty)
    }

    func testInvalidNumericTokenIsDirtyEvenWhenParsedValueMatches() {
        var state = editor()
        state.numericText.protein = "not a number"
        XCTAssertTrue(state.isDirty)
        XCTAssertFalse(state.canSave)
    }

    func testServingsOnlyChangeAndRevert() {
        var state = editor()
        state.servingsAmount = 2
        XCTAssertTrue(state.isDirty)
        state.servingsAmount = 1
        XCTAssertFalse(state.isDirty)
    }

    func testModeAndGramsChangesAreDirty() {
        var state = editor()
        state.quantityMode = .grams
        XCTAssertTrue(state.isDirty)
        state.quantityMode = .servings
        XCTAssertFalse(state.isDirty)
        state.gramsAmount = 80
        XCTAssertTrue(state.isDirty)
    }

    func testConfirmedZeroAndReusableToggleAreDirty() {
        var state = editor()
        state.confirmedZeroRequiredNutrients.insert(.protein)
        XCTAssertTrue(state.isDirty)
        state.confirmedZeroRequiredNutrients.remove(.protein)
        XCTAssertFalse(state.isDirty)
        state.draft.saveAsCustomFood.toggle()
        XCTAssertTrue(state.isDirty)
    }

    func testRenamedLabelBaselineIsSeparateFromOriginalDraft() {
        var original = FoodDraft()
        original.name = "Original"
        original.source = .labelScan
        var renamed = original
        renamed.name = "Renamed before opening"
        var state = FoodLogEditorState(initialDraft: renamed)
        XCTAssertFalse(state.isDirty)
        state.draft.name = original.name
        XCTAssertTrue(state.isDirty)
    }

    func testPruningKeepsOnlyUnresolvedConfirmations() {
        var state = editor()
        state.confirmedZeroRequiredNutrients = [.protein, .calories]
        state.pruneResolvedZeroConfirmations()
        XCTAssertEqual(state.confirmedZeroRequiredNutrients, [.protein])
    }

    private func editor() -> FoodLogEditorState {
        var draft = FoodDraft()
        draft.name = "Oats"
        draft.gramsPerServing = 40
        draft.caloriesPerServing = 160
        return FoodLogEditorState(initialDraft: draft)
    }
}
