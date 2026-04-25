import Foundation

struct OpenFoodFactsProduct: Decodable, Identifiable, Hashable {
    let externalProductID: String?

    var id: String {
        externalProductIDOrNil
            ?? OpenFoodFactsIdentity.qualifiedExternalProductID(for: code)
            ?? [productName, brands, url].compactMap(OpenFoodFactsIdentity.trimmedText).joined(separator: "|")
    }

    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: Double?
    let servingQuantityUnit: String?
    let quantity: String?
    let nutriments: Nutriments?
    let url: String?

    var cacheLookupExternalProductIDs: [String] {
        var seen = Set<String>()
        return ([externalProductIDOrNil] + OpenFoodFactsIdentity.qualifiedExternalProductIDAliases(for: normalizedBarcode))
            .compactMap { $0 }
            .filter { seen.insert($0).inserted }
    }

    func resolvedExternalProductID(preferredBarcode: String? = nil) -> String? {
        OpenFoodFactsIdentity.qualifiedExternalProductID(for: preferredBarcode) ?? cacheLookupExternalProductIDs.first
    }

    var normalizedBarcode: String? {
        OpenFoodFactsIdentity.normalizedBarcode(
            barcode: code,
            externalProductID: externalProductID,
            sourceURL: url
        )
    }

    struct Nutriments: Decodable, Hashable {
        let caloriesPerServing: Double?
        let proteinPerServing: Double?
        let fatPerServing: Double?
        let carbsPerServing: Double?
        let saturatedFatPerServing: Double?
        let fiberPerServing: Double?
        let sugarsPerServing: Double?
        let addedSugarsPerServing: Double?
        let sodiumPerServing: Double?
        let cholesterolPerServing: Double?
        let saltPerServing: Double?
        let caloriesPer100g: Double?
        let proteinPer100g: Double?
        let fatPer100g: Double?
        let carbsPer100g: Double?
        let saturatedFatPer100g: Double?
        let fiberPer100g: Double?
        let sugarsPer100g: Double?
        let addedSugarsPer100g: Double?
        let sodiumPer100g: Double?
        let cholesterolPer100g: Double?
        let saltPer100g: Double?

        private enum CodingKeys: String, CodingKey {
            case caloriesPerServing = "energy-kcal_serving"
            case proteinPerServing = "proteins_serving"
            case fatPerServing = "fat_serving"
            case carbsPerServing = "carbohydrates_serving"
            case saturatedFatPerServing = "saturated-fat_serving"
            case fiberPerServing = "fiber_serving"
            case sugarsPerServing = "sugars_serving"
            case addedSugarsPerServing = "added-sugars_serving"
            case sodiumPerServing = "sodium_serving"
            case cholesterolPerServing = "cholesterol_serving"
            case saltPerServing = "salt_serving"
            case caloriesPer100g = "energy-kcal_100g"
            case proteinPer100g = "proteins_100g"
            case fatPer100g = "fat_100g"
            case carbsPer100g = "carbohydrates_100g"
            case saturatedFatPer100g = "saturated-fat_100g"
            case fiberPer100g = "fiber_100g"
            case sugarsPer100g = "sugars_100g"
            case addedSugarsPer100g = "added-sugars_100g"
            case sodiumPer100g = "sodium_100g"
            case cholesterolPer100g = "cholesterol_100g"
            case saltPer100g = "salt_100g"
        }

        static let empty = Self(
            caloriesPerServing: nil,
            proteinPerServing: nil,
            fatPerServing: nil,
            carbsPerServing: nil,
            saturatedFatPerServing: nil,
            fiberPerServing: nil,
            sugarsPerServing: nil,
            addedSugarsPerServing: nil,
            sodiumPerServing: nil,
            cholesterolPerServing: nil,
            saltPerServing: nil,
            caloriesPer100g: nil,
            proteinPer100g: nil,
            fatPer100g: nil,
            carbsPer100g: nil,
            saturatedFatPer100g: nil,
            fiberPer100g: nil,
            sugarsPer100g: nil,
            addedSugarsPer100g: nil,
            sodiumPer100g: nil,
            cholesterolPer100g: nil,
            saltPer100g: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case externalProductID
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case servingQuantityUnit = "serving_quantity_unit"
        case quantity
        case nutriments
        case url
    }

    private var externalProductIDOrNil: String? {
        OpenFoodFactsIdentity.trimmedText(from: externalProductID)
    }

    var nutrition: Nutriments {
        nutriments ?? .empty
    }
}

struct OpenFoodFactsResponse: Decodable {
    let product: OpenFoodFactsProduct?
}

enum OpenFoodFactsClientError: LocalizedError {
    case invalidBarcode
    case invalidResponse
    case requestFailed(statusCode: Int)
    case productNotFound

    var isRetryable: Bool {
        switch self {
        case .invalidBarcode, .productNotFound:
            return false
        case .invalidResponse:
            return true
        case let .requestFailed(statusCode):
            return statusCode == 429 || statusCode >= 500
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "The scanned barcode is invalid."
        case .invalidResponse:
            return "The food lookup service returned an invalid response."
        case let .requestFailed(statusCode):
            if statusCode == 503 {
                return "Open Food Facts is temporarily unavailable. You can still use on-device results or manual entry."
            }

            return "The food lookup service returned an error (\(statusCode))."
        case .productNotFound:
            return "No product was found for that barcode."
        }
    }
}

struct OpenFoodFactsClient {
    private let jsonClient: HTTPJSONClient

    init(session: URLSession = .shared) {
        jsonClient = HTTPJSONClient(session: session)
    }

    func fetchProduct(barcode: String) async throws -> OpenFoodFactsProduct {
        let normalizedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBarcode.isEmpty else {
            throw OpenFoodFactsClientError.invalidBarcode
        }

        for barcodeAlias in OpenFoodFactsIdentity.barcodeAliases(for: normalizedBarcode) {
            do {
                let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcodeAlias).json")!
                let decodedResponse: OpenFoodFactsResponse = try await sendRequest(url: url)

                guard let product = decodedResponse.product else {
                    throw OpenFoodFactsClientError.productNotFound
                }

                return product
            } catch OpenFoodFactsClientError.productNotFound {
                continue
            } catch {
                throw error
            }
        }

        throw OpenFoodFactsClientError.productNotFound
    }

    private func sendRequest<Response: Decodable>(url: URL) async throws -> Response {
        let request = jsonClient.makeRequest(url: url)
        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            (data, httpResponse) = try await jsonClient.data(for: request)
        } catch HTTPJSONClientError.invalidResponse {
            throw OpenFoodFactsClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenFoodFactsClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try jsonClient.decode(Response.self, from: data)
    }
}
