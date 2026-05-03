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
    private let usdaSourceName: String
    private let usdaSourceURL: String
    let barcode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case servingDescription
        case gramsPerServing
        case caloriesPerServing
        case proteinPerServing
        case fatPerServing
        case carbsPerServing
        case saturatedFatPerServing
        case fiberPerServing
        case sugarsPerServing
        case addedSugarsPerServing
        case sodiumPerServing
        case cholesterolPerServing
        case usdaSourceName = "sourceName"
        case usdaSourceURL = "sourceURL"
        case barcode
    }
}

extension USDAProxyFood: FoodDraftImportedDataConvertible {
    var source: FoodSource { .searchLookup }
    var externalProductID: String? { id }
    var sourceName: String? { usdaSourceName }
    var sourceURL: String? { usdaSourceURL }
}
