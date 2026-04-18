import Foundation

enum OpenFoodFactsIdentity {
    nonisolated static func barcodeAliases(for barcode: String?) -> [String] {
        guard let barcode = trimmedText(from: barcode) else {
            return []
        }

        if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: barcode)) {
            if barcode.count == 12 {
                return [barcode, "0\(barcode)"]
            }

            if barcode.count == 13, barcode.hasPrefix("0") {
                return [String(barcode.dropFirst()), barcode]
            }
        }

        return [barcode]
    }

    nonisolated static func qualifiedExternalProductID(for barcode: String?) -> String? {
        qualifiedExternalProductID(forRawIdentifier: barcodeAliases(for: barcode).first)
    }

    nonisolated static func qualifiedExternalProductIDAliases(for barcode: String?) -> [String] {
        var seen = Set<String>()
        return barcodeAliases(for: barcode)
            .compactMap { qualifiedExternalProductID(forRawIdentifier: $0) }
            .filter { seen.insert($0).inserted }
    }

    nonisolated static func qualifiedExternalProductID(forRawIdentifier identifier: String?) -> String? {
        guard let identifier = trimmedText(from: identifier) else {
            return nil
        }

        return "openfoodfacts:\(identifier)"
    }

    nonisolated static func normalizedBarcode(
        barcode: String?,
        externalProductID: String?,
        sourceURL: String?
    ) -> String? {
        normalizedDigitBarcode(from: barcode)
            ?? normalizedDigitBarcode(from: barcodeFromProductURL(sourceURL))
            ?? normalizedExternalProductIDBarcode(from: externalProductID)
    }

    nonisolated static func productURL(for barcode: String?) -> URL? {
        guard let normalizedBarcode = barcodeAliases(for: barcode).first else {
            return nil
        }

        return URL(string: "https://world.openfoodfacts.org/product/\(normalizedBarcode)")
    }

    nonisolated static func persistedProductURL(
        barcode: String?,
        sourceURL: String?
    ) -> String? {
        productURL(for: barcode)?.absoluteString ?? trimmedText(from: sourceURL)
    }

    nonisolated static func barcodeFromProductURL(_ sourceURL: String?) -> String? {
        guard
            let sourceURL = trimmedText(from: sourceURL),
            let components = URLComponents(string: sourceURL),
            let host = components.host?.lowercased(),
            host == "openfoodfacts.org" || host.hasSuffix(".openfoodfacts.org")
        else {
            return nil
        }

        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)
        guard let productIndex = pathComponents.lastIndex(of: "product"),
            pathComponents.indices.contains(productIndex + 1)
        else {
            return nil
        }

        return pathComponents[productIndex + 1]
    }

    nonisolated static func rawIdentifier(fromQualifiedExternalProductID externalProductID: String?) -> String? {
        guard let externalProductID = trimmedText(from: externalProductID) else {
            return nil
        }

        let normalizedExternalProductID = externalProductID.lowercased()
        let prefix = "openfoodfacts:"
        guard normalizedExternalProductID.hasPrefix(prefix) else {
            return nil
        }

        return String(externalProductID.dropFirst(prefix.count))
    }

    nonisolated private static func normalizedDigitBarcode(from value: String?) -> String? {
        guard let value = trimmedText(from: value) else {
            return nil
        }

        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: value)) else {
            return nil
        }

        return barcodeAliases(for: value).first
    }

    nonisolated private static func normalizedExternalProductIDBarcode(from externalProductID: String?) -> String? {
        guard
            let rawIdentifier = rawIdentifier(fromQualifiedExternalProductID: externalProductID),
            isSupportedBarcodeLength(rawIdentifier.count)
        else {
            return nil
        }

        return normalizedDigitBarcode(from: rawIdentifier)
    }

    nonisolated private static func isSupportedBarcodeLength(_ count: Int) -> Bool {
        switch count {
        case 8, 12, 13:
            return true
        default:
            return false
        }
    }

    nonisolated static func trimmedText(from value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }
}
