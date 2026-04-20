import Foundation
import SwiftData

extension FoodItemRepository {
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

    func reusableFood(for draft: FoodDraft, in context: ModelContext) throws -> FoodItem? {
        if let existingID = draft.foodItemID,
            let existingFood = try fetchReusableFood(id: existingID, in: context)
        {
            return existingFood
        }

        if let externalProductID = draft.externalProductIDOrNil {
            let lookupSources: [FoodSource]
            switch draft.source {
            case .searchLookup:
                lookupSources = [.searchLookup, .barcodeLookup]
            default:
                lookupSources = [draft.source]
            }

            for source in lookupSources {
                if let externalFood = try fetchReusableFood(
                    source: source,
                    externalProductID: externalProductID,
                    in: context
                ) {
                    return externalFood
                }
            }
        }

        if draft.source == .barcodeLookup,
            let barcode = draft.barcodeOrNil,
            let barcodeFood = try fetchBarcodeFood(
                barcode: barcode,
                preferredSources: [.barcodeLookup],
                in: context
            )
        {
            return barcodeFood
        }

        return nil
    }

    func fetchReusableFood(id: UUID, in context: ModelContext) throws -> FoodItem? {
        let commonSource = FoodSource.common.rawValue
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.id == id && food.source != commonSource
            },
            sortBy: [SortDescriptor(\FoodItem.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }

    func fetchReusableFood(
        source: FoodSource,
        externalProductID: String,
        in context: ModelContext
    ) throws -> FoodItem? {
        let commonSource = FoodSource.common.rawValue
        let sourceValue = source.rawValue
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.source == sourceValue && food.externalProductID == externalProductID && food.source != commonSource
            },
            sortBy: [SortDescriptor(\FoodItem.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }

    func fetchBarcodeFood(
        barcode: String,
        preferredSources: [FoodSource],
        in context: ModelContext
    ) throws -> FoodItem? {
        for source in preferredSources {
            for barcodeAlias in OpenFoodFactsIdentity.barcodeAliases(for: barcode) {
                if let food = try fetchBarcodeFood(barcode: barcodeAlias, source: source, in: context) {
                    return food
                }
            }
        }

        return nil
    }

    func fetchBarcodeFood(
        barcode: String,
        source: FoodSource,
        in context: ModelContext
    ) throws -> FoodItem? {
        let sourceValue = source.rawValue
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.barcode == barcode && food.source == sourceValue
            },
            sortBy: [SortDescriptor(\FoodItem.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }
}
