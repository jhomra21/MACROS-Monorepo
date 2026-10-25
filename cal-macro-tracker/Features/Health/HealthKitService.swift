import Foundation
import HealthKit
import Observation
import SwiftData

enum HealthNutritionAuthorization {
    static func isAuthorized(_ status: HKAuthorizationStatus) -> Bool {
        status == .sharingAuthorized
    }

    static func authorizedIdentifiers(
        statuses: [HKQuantityTypeIdentifier: HKAuthorizationStatus]
    ) -> Set<HKQuantityTypeIdentifier> {
        Set(statuses.compactMap { identifier, status in
            isAuthorized(status) ? identifier : nil
        })
    }
}

@MainActor
@Observable
final class HealthKitService {
    private(set) var statusText =
        HKHealthStore.isHealthDataAvailable() ? "Apple Health is available." : "Apple Health is not available on this device."
    private let store = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var isObservingWeight = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(readWeight: Bool = false) async throws {
        guard isAvailable else { return }
        let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)
        try await store.requestAuthorization(
            toShare: nutritionTypes,
            read: readWeight ? Set(bodyMass.map { [$0] } ?? []) : []
        )
        statusText = "Health access updated. Manage permissions in the Health app."
    }

    func writeNutrition(for entry: LogEntry) async {
        guard isAvailable else { return }
        let values: [(HKQuantityTypeIdentifier, Double?, HKUnit)] = [
            (.dietaryEnergyConsumed, entry.caloriesConsumed, .kilocalorie()),
            (.dietaryProtein, entry.proteinConsumed, .gram()),
            (.dietaryCarbohydrates, entry.carbsConsumed, .gram()),
            (.dietaryFatTotal, entry.fatConsumed, .gram()),
            (.dietaryFatSaturated, entry.saturatedFatConsumed, .gram()),
            (.dietaryFiber, entry.fiberConsumed, .gram()),
            (.dietarySugar, entry.sugarsConsumed, .gram()),
            (.dietarySodium, entry.sodiumConsumed, .gramUnit(with: .milli)),
            (.dietaryCholesterol, entry.cholesterolConsumed, .gramUnit(with: .milli))
        ]
        let authorizationStatuses = Dictionary(
            uniqueKeysWithValues: values.compactMap { identifier, _, _ in
                HKObjectType.quantityType(forIdentifier: identifier).map { (identifier, store.authorizationStatus(for: $0)) }
            })
        let authorizedIdentifiers = HealthNutritionAuthorization.authorizedIdentifiers(statuses: authorizationStatuses)
        let hasUnauthorizedTypes = authorizedIdentifiers.count < values.count
        var samples: [HKQuantitySample] = []
        var deletionFailed = false
        for (identifier, amount, unit) in values {
            guard authorizedIdentifiers.contains(identifier) else { continue }
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let syncIdentifier = "\(entry.id.uuidString).\(identifier.rawValue)"
            guard let amount, amount.isFinite else {
                let predicate = HKQuery.predicateForObjects(
                    withMetadataKey: HKMetadataKeySyncIdentifier, operatorType: .equalTo, value: syncIdentifier)
                do {
                    try await store.deleteObjects(of: type, predicate: predicate)
                } catch {
                    deletionFailed = true
                }
                continue
            }
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: syncIdentifier,
                HKMetadataKeySyncVersion: Int(entry.updatedAt.timeIntervalSince1970)
            ]
            samples.append(
                HKQuantitySample(
                    type: type, quantity: HKQuantity(unit: unit, doubleValue: amount), start: entry.dateLogged, end: entry.dateLogged,
                    metadata: metadata))
        }
        guard !samples.isEmpty else {
            statusText = deletionFailed
                ? "Could not update nutrition in Apple Health."
                : hasUnauthorizedTypes ? "No enabled Health nutrition categories to update. Review access in the Health app."
                : "Nutrition updated in Apple Health."
            return
        }
        do {
            try await store.save(samples)
            statusText = if deletionFailed {
                "Some nutrition could not be updated in Apple Health."
            } else if hasUnauthorizedTypes {
                "Nutrition saved for enabled categories. Enable others in the Health app to sync all values."
            } else {
                "Nutrition saved to Apple Health."
            }
        } catch {
            statusText = "Could not save nutrition to Apple Health."
        }
    }

    func deleteNutrition(for entryID: UUID) async {
        for type in nutritionTypes {
            guard HealthNutritionAuthorization.isAuthorized(store.authorizationStatus(for: type)) else { continue }
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier, operatorType: .beginsWith, value: entryID.uuidString)
            do { try await store.deleteObjects(of: type, predicate: predicate) } catch { continue }
        }
    }

    func backfill(days: Int, container: ModelContainer) async {
        guard isAvailable, days > 0 else { return }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let entries = (try? container.mainContext.fetch(FetchDescriptor<LogEntry>())) ?? []
        for entry in entries where entry.dateLogged >= start {
            if Task.isCancelled { return }
            await writeNutrition(for: entry)
        }
    }

    func startWeightObservation(container: ModelContainer) {
        guard isAvailable, observerQuery == nil,
            let type = HKObjectType.quantityType(forIdentifier: .bodyMass)
        else { return }
        isObservingWeight = true
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                await self?.importWeights(into: container, type: type)
                completion()
            }
        }
        observerQuery = query
        store.execute(query)
        Task { await importWeights(into: container, type: type) }
    }

    func stopWeightObservation() {
        isObservingWeight = false
        guard let observerQuery else { return }
        store.stop(observerQuery)
        self.observerQuery = nil
    }

    private func importWeights(into container: ModelContainer, type: HKQuantityType) async {
        guard isObservingWeight, UserDefaults.standard.bool(forKey: AppStorageKeys.healthWeightReadEnabled) else { return }
        let anchor = UserDefaults.standard.data(forKey: "healthWeightAnchor")
            .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) {
                _, samples, deletedObjects, newAnchor, error in
                guard error == nil else {
                    Task { @MainActor in
                        self.statusText = "Could not import weight from Apple Health."
                        continuation.resume()
                    }
                    return
                }
                let imported =
                    (samples as? [HKQuantitySample])?.map {
                        HealthWeightSample(
                            uuid: $0.uuid.uuidString, date: $0.endDate, kilograms: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                    } ?? []
                let deletedUUIDs = (deletedObjects ?? []).map { $0.uuid.uuidString }
                Task { @MainActor in
                    if self.isObservingWeight,
                        UserDefaults.standard.bool(forKey: AppStorageKeys.healthWeightReadEnabled)
                    {
                        do {
                            try WeightRepository(modelContext: container.mainContext)
                                .applyHealthChanges(imported, deletedUUIDs: deletedUUIDs)
                            if let newAnchor,
                                let data = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                            {
                                UserDefaults.standard.set(data, forKey: "healthWeightAnchor")
                            }
                        } catch {
                            self.statusText = "Could not import weight from Apple Health."
                        }
                    }
                    continuation.resume()
                }
            }
            store.execute(query)
        }
    }

    private var nutritionTypes: Set<HKSampleType> {
        Set(
            [
                HKQuantityTypeIdentifier.dietaryEnergyConsumed,
                .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryFatSaturated,
                .dietaryFiber, .dietarySugar, .dietarySodium, .dietaryCholesterol
            ].compactMap(HKObjectType.quantityType(forIdentifier:)))
    }
}
