#if os(iOS)
import Foundation
import OSLog
import Security
import WidgetKit

nonisolated enum SharedPersonWidgetStatus: Sendable {
    case shared, noData, openApp, invalidated, disabled, proLocked, proUnknown, reconnect, locked
    case noPeople, noDefault, unavailable, paused, notShared, failed

    var message: String {
        switch self {
        case .shared, .noData: "No macros shared today"
        case .openApp, .invalidated: "Open MACROS"
        case .disabled: "Sharing is off on this device"
        case .proLocked: "Shared widgets need MACROS Pro"
        case .proUnknown: "Open MACROS to check Pro"
        case .reconnect: "Open MACROS to reconnect"
        case .locked: "Unlock to update"
        case .noPeople: "No people connected"
        case .noDefault: "Choose a default person"
        case .unavailable: "Person unavailable"
        case .paused: "Sharing paused"
        case .notShared: "Isn't sharing with you"
        case .failed: "Couldn't update"
        }
    }

    var compactMessage: String {
        switch self {
        case .proLocked: "MACROS Pro"
        case .disabled: "Sharing off"
        case .noPeople: "No people"
        case .noDefault: "Choose person"
        case .unavailable, .failed: "Unavailable"
        case .paused: "Paused"
        case .notShared: "Not shared"
        case .noData, .shared: "No data"
        default: message
        }
    }
}

nonisolated struct SharedPersonWidgetEntry: TimelineEntry, Sendable {
    var date: Date
    var person: SharedWidgetPerson?
    var status: SharedPersonWidgetStatus
    var snapshot: SharedWidgetSnapshot?
    var offline = false
    var isPlaceholder = false
    var layoutEntry: DailyMacroWidgetEntry?

    @MainActor func prepared(includesAppearance: Bool, proAccess: WidgetProAccess? = nil) -> Self {
        var entry = self
        let storage = WidgetAppearanceStorage.shared
        let appearance = includesAppearance ? storage.appearanceRecord : nil
        let access = proAccess ?? (includesAppearance ? storage.proAccess : .unknown)
        entry.layoutEntry = DailyMacroWidgetEntry(
            date: date, snapshot: snapshot?.dailySnapshot ?? DailyMacroSnapshot(totals: .zero, goals: .empty),
            customRingPalette: includesAppearance ? MacroRingColorStorage.storedPalette() : nil,
            appearance: appearance, proAccess: access,
            backgroundPhotoData: includesAppearance ? storage.backgroundPhotoData(for: appearance, access: access) : nil,
            isPlaceholder: isPlaceholder
        )
        return entry
    }

    var url: URL {
        if let person {
            return AppOpenRequest.sharingPerson(profileId: person.id).url
        }
        return AppOpenRequest.sharing(inviteInput: nil).url
    }
}

nonisolated struct SharedPersonWidgetProvider: AppIntentTimelineProvider, Sendable {
    private static let logger = Logger(subsystem: "juan-test.cal-macro-tracker", category: "SharedWidget")
    var includesAppearance = true

    func placeholder(in context: Context) -> SharedPersonWidgetEntry {
        var entry = sample
        entry.isPlaceholder = true
        entry.layoutEntry = DailyMacroWidgetEntry(
            date: entry.date,
            snapshot: DailyMacroSnapshot(
                totals: NutritionSnapshot(calories: 1840, protein: 132, fat: 58, carbs: 176),
                goals: MacroGoalsSnapshot(calorieGoal: 2100, proteinGoalGrams: 145, fatGoalGrams: 65, carbGoalGrams: 230)
            ),
            customRingPalette: nil, appearance: nil, proAccess: .unknown, backgroundPhotoData: nil, isPlaceholder: true
        )
        return entry
    }

    func snapshot(for configuration: SharedPersonWidgetIntent, in context: Context) async -> SharedPersonWidgetEntry {
        let entry = context.isPreview ? sample : await load(configuration).entry
        return await entry.prepared(includesAppearance: includesAppearance)
    }

    func timeline(for configuration: SharedPersonWidgetIntent, in context: Context) async -> Timeline<SharedPersonWidgetEntry> {
        let result = await load(configuration)
        let entry = await result.entry.prepared(includesAppearance: includesAppearance)
        let midnight = SharedPersonWidgetClock.nextMidnight(after: entry.date)
        var newDay = entry
        newDay.date = midnight
        newDay.snapshot = nil
        newDay.offline = false
        if entry.status == .shared { newDay.status = .noData }
        newDay = await newDay.prepared(includesAppearance: includesAppearance)
        let refresh: Date
        switch entry.status {
        case .openApp, .disabled, .proLocked, .proUnknown, .noPeople, .noDefault, .unavailable, .reconnect:
            refresh = midnight
        default:
            refresh = SharedPersonWidgetClock.refreshDate(after: entry.date)
        }
        var requested = min(
            midnight,
            max(
                refresh,
                result.retryAfter ?? .distantPast
            ))
        var entries = [entry, newDay]
        let storage = WidgetAppearanceStorage(defaults: UserDefaults(suiteName: SharedAppConfiguration.appGroupIdentifier))
        if let expiration = storage.proAccessRecord?.expiration, expiration > entry.date, expiration < midnight {
            requested = min(requested, expiration)
            entries = [
                entry,
                await SharedPersonWidgetEntry(date: expiration, status: .proUnknown)
                    .prepared(includesAppearance: includesAppearance, proAccess: .unknown)
            ]
        }
        Self.logger.info(
            "Timeline entry \(entry.date.timeIntervalSince1970, privacy: .public), requested refresh \(requested.timeIntervalSince1970, privacy: .public)"
        )
        return Timeline(entries: entries, policy: .after(requested))
    }

    private func load(_ configuration: SharedPersonWidgetIntent) async -> (entry: SharedPersonWidgetEntry, retryAfter: Date?) {
        let storage = SharedPersonWidgetStorage.shared
        let now = Date.now
        let day = SharedPersonWidgetClock.dayKey(for: now)
        var entry = SharedPersonWidgetEntry(date: now, status: .openApp)
        var retryAfter: Date?
        do {
            guard let control = try storage.loadControl() else { return (entry, nil) }
            storage.purgeObsoleteCaches(generation: control.generation, day: day)
            guard control.enabled else {
                entry.status = .disabled
                await SharedPersonWidgetClient.shared.clearToken()
                return (entry, nil)
            }
            let access = proAccess
            guard access == .allowed else {
                storage.purgeAllCaches()
                await SharedPersonWidgetClient.shared.clearToken()
                entry.status = access == .denied ? .proLocked : .proUnknown
                return (entry, nil)
            }
            let selection = configuration.person?.id ?? "default"
            let selectedId = selection == "default" ? control.defaultProfileId : selection
            guard !control.people.isEmpty else {
                entry.status = .noPeople
                return (entry, nil)
            }
            guard let selectedId else {
                entry.status = .noDefault
                return (entry, nil)
            }
            guard let person = control.people.first(where: { $0.id == selectedId }) else {
                entry.status = .unavailable
                return (entry, nil)
            }
            entry.person = person
            do {
                Self.logger.info("Extension personDay request \(Date.now.timeIntervalSince1970, privacy: .public)")
                let value = try await SharedPersonWidgetClient.shared.personDay(
                    profileId: person.id, day: day, generation: control.generation
                )
                guard try isCurrent(control, storage: storage, day: day) else { return (invalidatedEntry(), nil) }
                switch value.visibility {
                case .shared:
                    entry.snapshot = value.snapshot
                    entry.status = value.snapshot == nil ? .noData : .shared
                    if let snapshot = value.snapshot {
                        try? storage.writeCache(
                            SharedPersonWidgetCache(snapshot: snapshot, fetchedAt: .now),
                            generation: control.generation, profileId: person.id, day: day
                        )
                    } else {
                        storage.purgeCache(generation: control.generation, profileId: person.id, day: day)
                    }
                case .notShared, .paused:
                    storage.purgeCache(generation: control.generation, profileId: person.id, day: day)
                    entry.status = value.visibility == .paused ? .paused : .notShared
                }
            } catch SharedWidgetFetchError.unavailable {
                storage.purgeCache(generation: control.generation, profileId: person.id, day: day)
                entry.person = nil
                entry.status = .unavailable
            } catch SharedWidgetFetchError.reconnect {
                storage.purgeCache(generation: control.generation, profileId: person.id, day: day)
                entry.person = nil
                entry.status = .reconnect
            } catch {
                if case SharedWidgetFetchError.transient(let date) = error { retryAfter = date }
                guard try isCurrent(control, storage: storage, day: day) else { return (invalidatedEntry(), nil) }
                if case SharingIdentityStoreError.keychainFailure(errSecInteractionNotAllowed) = error {
                    entry.person = nil
                    entry.status = .locked
                } else if let cached = try? storage.loadCache(generation: control.generation, profileId: person.id, day: day) {
                    entry.snapshot = cached.snapshot
                    entry.offline = true
                    entry.status = .shared
                } else {
                    entry.status = .failed
                }
            }
            guard try isCurrent(control, storage: storage, day: day) else { return (invalidatedEntry(), nil) }
        } catch {
            entry.person = nil
            entry.snapshot = nil
            entry.status = .locked
        }
        entry.date = .now
        return (entry, retryAfter)
    }

    private var proAccess: WidgetProAccess {
        let storage = WidgetAppearanceStorage(defaults: UserDefaults(suiteName: SharedAppConfiguration.appGroupIdentifier))
        guard let record = storage.proAccessRecord,
            record.expiration.map({ $0 > .now }) ?? true
        else { return .unknown }
        return record.access
    }

    private func isCurrent(_ control: SharedPersonWidgetControl, storage: SharedPersonWidgetStorage, day: String) throws -> Bool {
        guard let current = try storage.loadControl() else { return false }
        return current.generation == control.generation && current.enabled && proAccess == .allowed
            && current.defaultProfileId == control.defaultProfileId && current.people == control.people
            && day == SharedPersonWidgetClock.dayKey(for: .now)
    }

    private func invalidatedEntry() -> SharedPersonWidgetEntry {
        SharedPersonWidgetEntry(date: .now, status: .invalidated)
    }

    private var sample: SharedPersonWidgetEntry {
        SharedPersonWidgetEntry(
            date: .now, person: SharedWidgetPerson(id: "preview", name: "Alex"), status: .shared,
            snapshot: SharedWidgetSnapshot(
                day: SharedPersonWidgetClock.dayKey(for: .now), calories: 1840, protein: 132, carbs: 176, fat: 58,
                entryCount: 4, updatedAt: Date.now.timeIntervalSince1970 * 1000,
                calorieGoal: 2100, proteinGoal: 145, carbsGoal: 230, fatGoal: 65
            )
        )
    }
}
#endif
