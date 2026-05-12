import Foundation
import SwiftData

@MainActor
struct FoodItemRepository {
    let modelContext: ModelContext

    func fetchReusableFood(id: UUID) throws -> FoodItem? {
        try fetchReusableFood(id: id, in: modelContext)
    }

    func fetchReusableFood(source: FoodSource, externalProductID: String) throws -> FoodItem? {
        try fetchReusableFood(source: source, externalProductID: externalProductID, in: modelContext)
    }

    func fetchCachedBarcodeFood(barcode: String) throws -> FoodItem? {
        try fetchBarcodeFood(
            barcode: barcode,
            preferredSources: [.barcodeLookup, .searchLookup],
            in: modelContext
        )
    }

    func fetchBarcodeLookupFood(barcode: String) throws -> FoodItem? {
        try fetchBarcodeFood(
            barcode: barcode,
            preferredSources: [.barcodeLookup],
            in: modelContext
        )
    }
}
