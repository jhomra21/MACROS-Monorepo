import Foundation

nonisolated struct SharedPersonWidgetStorage: Sendable {
    let directory: URL?

    static var shared: Self {
        Self(
            directory: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedAppConfiguration.appGroupIdentifier
            )?.appending(path: "Library/Application Support/SharedPersonWidgets", directoryHint: .isDirectory)
        )
    }

    func loadControl() throws -> SharedPersonWidgetControl? {
        guard let directory,
            let record = try read(SharedPersonWidgetControl.self, from: directory.appending(path: "control.json"))
        else { return nil }
        guard record.version == 1, record.people.count <= 100 else { return nil }
        return record
    }

    /// Only the containing app publishes control state. Cache writers never call this.
    func writeControl(_ control: SharedPersonWidgetControl) throws {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        try write(control, to: directory.appending(path: "control.json"))
    }

    /// App-side invalidation for credential replacement or a newly denied Pro record.
    func invalidate(disabling: Bool = false) throws {
        let current = (try? loadControl()) ?? nil
        var control = current ?? SharedPersonWidgetControl()
        control.generation = UUID()
        if disabling {
            control.enabled = false
            control.people = []
            control.defaultProfileId = nil
        }
        try writeControl(control)
        purgeObsoleteCaches(generation: control.generation, day: SharedPersonWidgetClock.dayKey(for: .now))
    }

    func loadCache(generation: UUID, profileId: String, day: String) throws -> SharedPersonWidgetCache? {
        guard let url = cacheURL(generation: generation, profileId: profileId, day: day),
            let cache = try read(SharedPersonWidgetCache.self, from: url),
            cache.snapshot.day == day, cache.snapshot.isValid
        else { return nil }
        return cache
    }

    func writeCache(_ cache: SharedPersonWidgetCache, generation: UUID, profileId: String, day: String) throws {
        guard let url = cacheURL(generation: generation, profileId: profileId, day: day) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        // A late write remains inert: readers only use the app's current generation.
        try write(cache, to: url)
    }

    func purgeCache(generation: UUID, profileId: String, day: String) {
        guard let url = cacheURL(generation: generation, profileId: profileId, day: day) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func purgeObsoleteCaches(generation: UUID, day: String) {
        guard let directory,
            let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        let prefix = "\(generation.uuidString)-"
        let suffix = "-\(day).json"
        for file in files where file.lastPathComponent != "control.json" && file.pathExtension == "json" {
            if !file.lastPathComponent.hasPrefix(prefix) || !file.lastPathComponent.hasSuffix(suffix) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func purgeAllCaches() {
        guard let directory,
            let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        for file in files where file.lastPathComponent != "control.json" && file.pathExtension == "json" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func cacheURL(generation: UUID, profileId: String, day: String) -> URL? {
        guard !profileId.isEmpty,
            profileId.utf8.allSatisfy({
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
            }), day.count == 10, day.utf8.allSatisfy({ (48...57).contains($0) || $0 == 45 })
        else { return nil }
        return directory?.appending(path: "\(generation.uuidString)-\(profileId)-\(day).json")
    }

    private func read<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber, size.intValue <= 32768 else { return nil }
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
    }

    private func write<Value: Encodable>(_ value: Value, to url: URL) throws {
        let manager = FileManager.default
        var directory = url.deletingLastPathComponent()
        #if os(iOS)
        try manager.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        #else
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        #endif
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try directory.setResourceValues(resources)
        let data = try JSONEncoder().encode(value)
        guard data.count <= 32768 else { throw CocoaError(.fileWriteOutOfSpace) }
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        var file = url
        try file.setResourceValues(resources)
    }
}
