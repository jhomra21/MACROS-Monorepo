import Foundation

#if canImport(FoundationModels) && canImport(ImageIO)
import Darwin
import FoundationModels
import ImageIO

@Generable
enum MealStatus {
    case ok
    case not_food
    case unclear
    case packaged
}

@Generable(representNilExplicitlyInGeneratedContent: true)
struct MealEstimate {
    var status: MealStatus
    var foods: [EstimatedFood]
}

@Generable(representNilExplicitlyInGeneratedContent: true)
struct EstimatedFood {
    var name: String
    var grams: Double?
    var lowGrams: Double?
    var highGrams: Double?
    var preparation: String?
    var hiddenFatLikely: Bool
    var volumeMl: Double?
    var foodKey: String?
}

struct Record: Encodable {
    let photoId: String
    let arm: String
    let model: String
    let latencyMs: Double?
    let tokenUsage: TokenUsage
    let rawOutput: String
    let schemaValid: Bool
    let recordedAt: String
    let error: String?
}

struct TokenUsage: Encodable {
    let inputTokens: Int?
    let outputTokens: Int?
}

@available(macOS 27.0, *)
func run() async throws {
    let arguments = CommandLine.arguments
    let datasetIndex = arguments.firstIndex(of: "--dataset")
    let dataset = datasetIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "../dataset"
    let resultsIndex = arguments.firstIndex(of: "--results")
    let resultsPath = resultsIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "../results"
    let photoDirectory = URL(fileURLWithPath: dataset).appending(path: "photos")
    let outputDirectory = URL(fileURLWithPath: resultsPath)
    let promptURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "prompt.md")
    let prompt = try String(contentsOf: promptURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let photoEntries = (try? FileManager.default.contentsOfDirectory(at: photoDirectory, includingPropertiesForKeys: nil)) ?? []
    let photos = photoEntries
        .filter { ["jpg", "jpeg", "png", "heic", "webp"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard !photos.isEmpty else {
        print("No photos found in \(photoDirectory.path).")
        return
    }

    let localModel = SystemLanguageModel.default
    let privateModel = PrivateCloudComputeLanguageModel()
    let arms: [(String, any LanguageModel, Bool)] = [
        ("apple-on-device", localModel, localModel.availability == .available),
        ("apple-private-cloud", privateModel, privateModel.availability == .available)
    ]

    for (arm, model, available) in arms {
        for photo in photos {
            let photoId = photo.deletingPathExtension().lastPathComponent
            guard available else {
                try writeRecord(Record(
                    photoId: photoId, arm: arm, model: arm, latencyMs: nil,
                    tokenUsage: TokenUsage(inputTokens: nil, outputTokens: nil),
                    rawOutput: "", schemaValid: false, recordedAt: ISO8601DateFormatter().string(from: Date()),
                    error: "Model unavailable on this Mac."
                ), to: outputDirectory, arm: arm)
                continue
            }
            do {
                guard let source = CGImageSourceCreateWithURL(photo as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let session = LanguageModelSession(model: model)
                let started = ContinuousClock.now
                let response = try await session.respond(generating: MealEstimate.self) {
                    prompt
                    Attachment(image)
                }
                let elapsed = started.duration(to: .now)
                try writeRecord(Record(
                    photoId: photoId, arm: arm, model: arm,
                    latencyMs: Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15,
                    tokenUsage: TokenUsage(inputTokens: nil, outputTokens: nil),
                    rawOutput: response.rawContent.jsonString,
                    schemaValid: true,
                    recordedAt: ISO8601DateFormatter().string(from: Date()), error: nil
                ), to: outputDirectory, arm: arm)
            } catch {
                try writeRecord(Record(
                    photoId: photoId, arm: arm, model: arm, latencyMs: nil,
                    tokenUsage: TokenUsage(inputTokens: nil, outputTokens: nil),
                    rawOutput: "", schemaValid: false, recordedAt: ISO8601DateFormatter().string(from: Date()),
                    error: String(describing: error)
                ), to: outputDirectory, arm: arm)
                fputs("Failed \(arm)/\(photoId): \(error)\n", stderr)
            }
        }
    }
}

func writeRecord(_ record: Record, to root: URL, arm: String) throws {
    let folder = root.appending(path: arm)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(record)
    try data.write(to: folder.appending(path: "\(record.photoId).json"), options: .atomic)
}

Task {
    do {
        try await run()
        exit(EXIT_SUCCESS)
    } catch {
        fputs("FoodPhotoEval: \(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
dispatchMain()
#else
fputs("FoundationModels or ImageIO is unavailable. Build with Xcode 27 and the macOS 27 SDK.\n", stderr)
#endif
