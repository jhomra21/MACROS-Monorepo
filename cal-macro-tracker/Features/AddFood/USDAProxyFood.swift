import Foundation

struct USDAProxyFood: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let servingDescription: String
    let gramsPerServing: Double?
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let fatPerServing: Double
    let carbsPerServing: Double
    let saturatedFatPerServing: Double?
    let fiberPerServing: Double?
    let sugarsPerServing: Double?
    let addedSugarsPerServing: Double?
    let sodiumPerServing: Double?
    let cholesterolPerServing: Double?
    let sourceName: String
    let sourceURL: String
    let barcode: String?
}

extension USDAProxyFood: FoodDraftImportedDataConvertible {
    var source: FoodSource { .searchLookup }
    var externalProductID: String? { id }
}
