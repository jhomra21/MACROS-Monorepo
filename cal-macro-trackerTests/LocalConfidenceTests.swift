import SwiftData
import UIKit
import XCTest
@testable import cal_macro_tracker

@MainActor
final class LocalConfidenceTests: XCTestCase {
    func testSyntheticLabelImageThroughVisionAndParser() async throws {
        let lines = [
            "QA Oats", "Nutrition Facts", "Serving size 1 cup (40g)", "Calories 150",
            "Total Fat 3g", "Total Carbohydrate 27g", "Protein 5g"
        ]
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1_200, height: 700)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 700))
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(
                    at: CGPoint(x: 70, y: 40 + index * 85),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 46), .foregroundColor: UIColor.black]
                )
            }
        }
        attach(image, name: "synthetic-nutrition-label")
        let text = try await NutritionLabelTextRecognizer().recognizeText(in: image)
        let result = NutritionLabelParser.parse(recognizedText: text)
        XCTAssertEqual(result.draft.caloriesPerServing, 150)
        XCTAssertEqual(result.draft.proteinPerServing, 5)
        XCTAssertEqual(result.draft.fatPerServing, 3)
        XCTAssertEqual(result.draft.carbsPerServing, 27)
        XCTAssertEqual(result.draft.gramsPerServing, 40)
        XCTAssertTrue(result.missingRequiredNutrients.isEmpty)
    }

    func testMissingNutritionRemainsExplicitlyReviewable() {
        let result = NutritionLabelParser.parse(
            recognizedText: NutritionLabelRecognizedText(lines: ["Nutrition Facts", "Calories 150"])
        )
        XCTAssertEqual(result.missingRequiredNutrients.count, 3)
        XCTAssertNil(result.draft.gramsPerServing)
        XCTAssertFalse(result.notes.isEmpty)
        XCTAssertFalse(NutritionLabelParser.reviewRequiredNutrientsMessage(result.missingRequiredNutrients).isEmpty)
    }

    func testCorruptCommonFoodManifestDoesNotBlockContainerBootstrap() async throws {
        let manifestURL = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "CorruptCommonFoodManifest",
                withExtension: "json"
            )
        )
        let previousVersion = UserDefaults.standard.string(forKey: AppStorageKeys.commonFoodSeedVersion)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.commonFoodSeedVersion)
        defer {
            if let previousVersion {
                UserDefaults.standard.set(previousVersion, forKey: AppStorageKeys.commonFoodSeedVersion)
            } else {
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.commonFoodSeedVersion)
            }
        }

        let container = try makeContainer(
            ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        try await AppBootstrap.bootstrapIfNeeded(in: container, seedManifestURL: manifestURL)

        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<DailyGoals>()), 1)
        XCTAssertNil(UserDefaults.standard.string(forKey: AppStorageKeys.commonFoodSeedVersion))
    }

    func testBarcodeImageThroughVision() async throws {
        // Fixed EAN-13 fixture, 4006381333931, including its supplied check digit.
        let bits = "10100011010100111010111101111010001001011001101010100001010000101000010111010010000101100110101"
        // Scale 1 pins the bitmap to 1,200 x 600 px so bar widths do not depend on the display.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1_200, height: 600), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 600))
            UIColor.black.setFill()
            for (index, bit) in bits.enumerated() where bit == "1" {
                context.fill(CGRect(x: 100 + index * 10, y: 80, width: 10, height: 400))
            }
        }
        attach(image, name: "synthetic-ean13-4006381333931")
        let barcode = try await BarcodeImageScanner().scanBarcode(from: image)
        XCTAssertEqual(barcode, "4006381333931")
    }

    func testBlankBarcodeAndInvalidImageHaveControlledErrors() async throws {
        XCTAssertThrowsError(try ScanImageLoading.loadUIImage(from: Data("not an image".utf8)))
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
        }
        do {
            _ = try await BarcodeImageScanner().scanBarcode(from: blank)
            XCTFail("A blank image must not resolve a barcode.")
        } catch {
            XCTAssertTrue(error is BarcodeImageScannerError)
        }
    }

    func testCancellationClassificationDoesNotHideOtherErrors() {
        XCTAssertTrue(ScanCancellation.isCancellation(CancellationError()))
        XCTAssertTrue(ScanCancellation.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(ScanCancellation.isCancellation(URLError(.notConnectedToInternet)))
    }

    func testCurrentSchemaLocalStoreReopenAndDayBoundarySnapshot() throws {
        // A new private fixture, never the app-group or an existing user's database.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AppleQA-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("fixture.store"), cloudKitDatabase: .none)
        let day = CalendarDay(date: .now)
        do {
            let container = try makeContainer(configuration)
            let context = ModelContext(container)
            context.insert(DailyGoals(calorieGoal: 1_800))
            try context.save()
            var draft = FoodDraft()
            draft.name = "QA local food"
            draft.caloriesPerServing = 100
            draft.proteinPerServing = 5
            draft.fatPerServing = 2
            draft.carbsPerServing = 15
            let repository = LogEntryRepository(modelContext: context)
            for date in [day.dayInterval.start, day.dayInterval.end] {
                try repository.logFood(
                    draft: draft, reusableFoodPersistenceMode: .none, loggedAt: date,
                    quantityMode: .servings, quantityAmount: 1, operation: "Apple QA local fixture"
                )
            }
        }
        let reopened = try makeContainer(configuration)
        XCTAssertEqual(try ModelContext(reopened).fetchCount(FetchDescriptor<LogEntry>()), 2)
        let snapshot = try DailyMacroSnapshotLoader.load(for: day.startDate, in: reopened)
        XCTAssertEqual(snapshot.totals.calories, 100)
        XCTAssertEqual(snapshot.goals.calorieGoal, 1_800)
        let nutrition = try DailyMacroSnapshotLoader.loadNutrition(for: day.startDate, in: reopened)
        XCTAssertEqual(nutrition.entryCount, 1)
    }

    private func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: DailyGoals.self, FoodItem.self, Meal.self, MealComponent.self,
            LoggedMealComponentSnapshot.self, LogEntry.self, configurations: configuration
        )
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
