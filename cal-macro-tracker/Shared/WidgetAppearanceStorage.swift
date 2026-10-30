import Foundation

nonisolated enum WidgetBackgroundSelection: Codable, Equatable, Sendable {
    case native
    case color(hex: String)
    case photo(identifier: UUID)

    var photoIdentifier: UUID? {
        guard case let .photo(identifier) = self else { return nil }
        return identifier
    }

    static func validatedColor(_ hex: String) -> Self? {
        guard hex.count == 7, hex.first == "#",
            Int(hex.dropFirst(), radix: 16) != nil
        else { return nil }
        return .color(hex: hex.uppercased())
    }
}

nonisolated struct WidgetAppearanceRecord: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let background: WidgetBackgroundSelection

    init(background: WidgetBackgroundSelection) {
        version = Self.currentVersion
        self.background = background
    }
}

nonisolated enum WidgetProAccess: String, Codable, Equatable, Sendable {
    case unknown
    case allowed
    case denied

    static func projected(hasPro: Bool) -> Self {
        hasPro ? .allowed : .denied
    }
}

nonisolated struct WidgetProAccessRecord: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let access: WidgetProAccess

    init(access: WidgetProAccess) {
        version = Self.currentVersion
        self.access = access
    }
}

nonisolated struct WidgetAppearanceStorage {
    static let backgroundKey = "widgetAppearance.selection.v1"
    static let proAccessKey = "widgetAppearance.proAccess.v1"
    static let maximumRecordBytes = 4_096
    static let maximumPhotoBytes = 2 * 1_024 * 1_024

    @MainActor static let shared = WidgetAppearanceStorage(
        defaults: UserDefaults(suiteName: SharedAppConfiguration.appGroupIdentifier)
    )

    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    var background: WidgetBackgroundSelection {
        guard let data = defaults?.data(forKey: Self.backgroundKey),
            let record = Self.decodeRecord(data),
            record.version == WidgetAppearanceRecord.currentVersion
        else { return .native }
        return record.background
    }

    var appearanceRecord: WidgetAppearanceRecord? {
        guard let data = defaults?.data(forKey: Self.backgroundKey) else { return nil }
        return Self.decodeRecord(data)
    }

    var proAccess: WidgetProAccess {
        guard let data = defaults?.data(forKey: Self.proAccessKey),
            data.count <= 128,
            let record = try? JSONDecoder().decode(WidgetProAccessRecord.self, from: data),
            record.version == WidgetProAccessRecord.currentVersion
        else { return .unknown }
        return record.access
    }

    @discardableResult
    func writeBackground(_ selection: WidgetBackgroundSelection) -> Bool {
        let validatedSelection: WidgetBackgroundSelection
        switch selection {
        case .native, .photo:
            validatedSelection = selection
        case let .color(hex):
            guard let color = WidgetBackgroundSelection.validatedColor(hex) else { return false }
            validatedSelection = color
        }
        guard let defaults, let data = try? JSONEncoder().encode(WidgetAppearanceRecord(background: validatedSelection))
        else { return false }
        defaults.set(data, forKey: Self.backgroundKey)
        return defaults.data(forKey: Self.backgroundKey) == data
    }

    @discardableResult
    func writeProAccess(_ access: WidgetProAccess) -> Bool {
        guard let defaults,
            let data = try? JSONEncoder().encode(WidgetProAccessRecord(access: access))
        else { return false }
        defaults.set(data, forKey: Self.proAccessKey)
        return defaults.data(forKey: Self.proAccessKey) == data
    }

    static func decodeRecord(_ data: Data?) -> WidgetAppearanceRecord? {
        guard let data,
            data.count <= maximumRecordBytes,
            let record = try? JSONDecoder().decode(WidgetAppearanceRecord.self, from: data),
            record.version == WidgetAppearanceRecord.currentVersion
        else { return nil }
        if case let .color(hex) = record.background,
            WidgetBackgroundSelection.validatedColor(hex) == nil
        {
            return nil
        }
        return record
    }

    @MainActor func photoURL(for identifier: UUID) -> URL? {
        guard
            let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedAppConfiguration.appGroupIdentifier
            )
        else { return nil }
        return
            groupURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("WidgetAppearance", isDirectory: true)
            .appendingPathComponent("\(identifier.uuidString).jpg", isDirectory: false)
    }
}
