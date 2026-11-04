#if os(iOS)
import AppIntents

nonisolated struct SharedWidgetPersonEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Person")
    static let defaultQuery = SharedWidgetPersonQuery()
    static let defaultPerson = Self(id: "default", name: "Default")

    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

nonisolated struct SharedWidgetPersonQuery: EntityQuery, Sendable {
    func entities(for identifiers: [String]) async throws -> [SharedWidgetPersonEntity] {
        // A removed or unreadable person must stay selected so the widget reports it as unavailable.
        let people = (try? allPeople()) ?? [.defaultPerson]
        let byId = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return identifiers.map { byId[$0] ?? SharedWidgetPersonEntity(id: $0, name: "Unavailable") }
    }

    func suggestedEntities() async throws -> [SharedWidgetPersonEntity] { try allPeople() }
    func defaultResult() async -> SharedWidgetPersonEntity? { .defaultPerson }

    private func allPeople() throws -> [SharedWidgetPersonEntity] {
        let people = try SharedPersonWidgetStorage.shared.loadControl()?.people ?? []
        return [.defaultPerson]
            + people.sorted {
                let comparison = $0.name.localizedStandardCompare($1.name)
                return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
            }.map { SharedWidgetPersonEntity(id: $0.id, name: $0.name) }
    }
}

// Sendable prevents MainActor inference. Type-level nonisolated incorrectly
// propagates onto the SDK's reference-backed @Parameter storage.
struct SharedPersonWidgetIntent: WidgetConfigurationIntent, Sendable {
    nonisolated static let title: LocalizedStringResource = "Choose Shared Person"
    nonisolated static let description = IntentDescription("Choose the person whose shared macros appear.")

    @Parameter(title: "Person")
    var person: SharedWidgetPersonEntity?

    nonisolated init() {}
}
#endif
