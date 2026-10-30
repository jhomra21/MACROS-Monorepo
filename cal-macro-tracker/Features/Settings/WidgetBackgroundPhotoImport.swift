#if os(iOS)
import CoreTransferable
import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct WidgetPhotoTransfer: Transferable {
    let jpegData: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            Self(jpegData: try await WidgetBackgroundPhotoImport.makeJPEG(from: received.file))
        }
    }
}

nonisolated enum WidgetBackgroundPhotoImport {
    static let maximumInputBytes = 25 * 1_024 * 1_024
    static let maximumSourcePixels: UInt64 = 100_000_000
    static let maximumOutputPixels = 1_024
    static let maximumJPEGBytes = WidgetAppearanceStorage.maximumPhotoBytes

    nonisolated enum ImportError: LocalizedError {
        case unsupportedImage
        case inputTooLarge
        case imageTooLarge
        case processingFailed
        case outputTooLarge
        case unavailableStorage
        case writeFailed
        case oldPhotoCouldNotBeRemoved

        var errorDescription: String? {
            switch self {
            case .unsupportedImage: "This file isn’t a supported still image."
            case .inputTooLarge: "Choose an image smaller than 25 MB."
            case .imageTooLarge: "This image has too many pixels to use as a widget background."
            case .processingFailed: "This image couldn’t be prepared. Choose another image."
            case .outputTooLarge: "This image couldn’t be compressed enough for a widget."
            case .unavailableStorage: "Widget photo storage is unavailable."
            case .writeFailed: "The widget photo couldn’t be saved."
            case .oldPhotoCouldNotBeRemoved: "The new widget background is active, but the previous photo couldn’t be removed."
            }
        }
    }

    static func jpegData(from item: PhotosPickerItem) async throws -> Data {
        do {
            guard let transfer = try await item.loadTransferable(type: WidgetPhotoTransfer.self) else {
                throw ImportError.unsupportedImage
            }
            return transfer.jpegData
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.processingFailed
        }
    }

    @concurrent
    fileprivate static func makeJPEG(from url: URL) async throws -> Data {
        try Task.checkCancellation()
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else { throw ImportError.processingFailed }
        guard size.uint64Value <= UInt64(maximumInputBytes) else { throw ImportError.inputTooLarge }
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary),
            let sourceType = CGImageSourceGetType(source),
            UTType(sourceType as String)?.conforms(to: .image) == true,
            CGImageSourceGetCount(source) == 1,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.uint64Value,
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.uint64Value,
            width > 0, height > 0
        else { throw ImportError.unsupportedImage }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, pixels <= maximumSourcePixels else { throw ImportError.imageTooLarge }

        try Task.checkCancellation()
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumOutputPixels,
            kCGImageSourceShouldCache: false
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw ImportError.processingFailed
        }
        let output = NSMutableData()
        let jpegType = UTType.jpeg.identifier as CFString
        guard let outputDestination = CGImageDestinationCreateWithData(output, jpegType, 1, nil) else {
            throw ImportError.processingFailed
        }
        let outputOptions: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.86]
        CGImageDestinationAddImage(outputDestination, image, outputOptions as CFDictionary)
        guard CGImageDestinationFinalize(outputDestination), output.length <= maximumJPEGBytes else {
            throw ImportError.outputTooLarge
        }
        try Task.checkCancellation()
        return output as Data
    }

    @MainActor
    static func commit(_ jpegData: Data, storage: WidgetAppearanceStorage? = nil) throws -> UUID {
        let storage = storage ?? WidgetAppearanceStorage.shared
        guard storage.proAccess == .allowed else { throw ImportError.unavailableStorage }
        let previousIdentifier = storage.background.photoIdentifier
        let identifier = try write(jpegData, storage: storage)
        guard storage.writeBackground(.photo(identifier: identifier)) else {
            try? remove(identifier, storage: storage)
            throw ImportError.writeFailed
        }
        if let previousIdentifier, previousIdentifier != identifier {
            do {
                try remove(previousIdentifier, storage: storage)
            } catch {
                throw ImportError.oldPhotoCouldNotBeRemoved
            }
        }
        return identifier
    }

    @MainActor
    static func writeSelection(
        _ selection: WidgetBackgroundSelection,
        storage: WidgetAppearanceStorage? = nil
    ) throws {
        let storage = storage ?? WidgetAppearanceStorage.shared
        let oldIdentifier = storage.background.photoIdentifier
        guard storage.writeBackground(selection) else { throw ImportError.writeFailed }
        if let oldIdentifier, oldIdentifier != selection.photoIdentifier {
            do {
                try remove(oldIdentifier, storage: storage)
            } catch {
                throw ImportError.oldPhotoCouldNotBeRemoved
            }
        }
    }

    @MainActor
    private static func write(_ data: Data, storage: WidgetAppearanceStorage) throws -> UUID {
        guard data.count <= maximumJPEGBytes,
            let parent = storage.photoURL(for: UUID())?.deletingLastPathComponent()
        else { throw ImportError.unavailableStorage }
        let fileManager = FileManager.default
        var ownedFileURL: URL?
        var didWrite = false
        defer {
            if !didWrite, let ownedFileURL {
                try? fileManager.removeItem(at: ownedFileURL)
            }
        }
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            var directoryValues = URLResourceValues()
            directoryValues.isExcludedFromBackup = true
            var mutableParent = parent
            try mutableParent.setResourceValues(directoryValues)
            let identifier = UUID()
            guard let destination = storage.photoURL(for: identifier) else { throw ImportError.unavailableStorage }
            guard !fileManager.fileExists(atPath: destination.path) else { throw ImportError.writeFailed }
            let staging = parent.appendingPathComponent("\(identifier.uuidString).tmp")
            let protection: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            guard fileManager.createFile(atPath: staging.path, contents: nil, attributes: protection) else {
                throw ImportError.writeFailed
            }
            ownedFileURL = staging
            try data.write(
                to: staging,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            var stagingURL = staging
            stagingURL.removeAllCachedResourceValues()
            let stagedValues = try stagingURL.resourceValues(forKeys: [.fileSizeKey, .fileProtectionKey])
            guard stagedValues.fileSize == data.count,
                stagedValues.fileProtection == .completeUntilFirstUserAuthentication
            else {
                throw ImportError.writeFailed
            }
            var stagingValues = URLResourceValues()
            stagingValues.isExcludedFromBackup = true
            var mutableStaging = staging
            try mutableStaging.setResourceValues(stagingValues)
            let values = try staging.resourceValues(forKeys: [.isExcludedFromBackupKey])
            guard values.isExcludedFromBackup == true else {
                throw ImportError.writeFailed
            }
            try fileManager.moveItem(at: staging, to: destination)
            ownedFileURL = destination
            var destinationURL = destination
            destinationURL.removeAllCachedResourceValues()
            let destinationValues = try destinationURL.resourceValues(
                forKeys: [.fileSizeKey, .fileProtectionKey, .isExcludedFromBackupKey]
            )
            guard destinationValues.fileSize == data.count,
                destinationValues.fileProtection == .completeUntilFirstUserAuthentication,
                destinationValues.isExcludedFromBackup == true
            else { throw ImportError.writeFailed }
            didWrite = true
            return identifier
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.writeFailed
        }
    }

    @MainActor
    private static func remove(_ identifier: UUID, storage: WidgetAppearanceStorage) throws {
        guard let url = storage.photoURL(for: identifier) else { throw ImportError.unavailableStorage }
        try FileManager.default.removeItem(at: url)
    }
}
#endif
