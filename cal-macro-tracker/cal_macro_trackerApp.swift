//
//  cal_macro_trackerApp.swift
//  cal-macro-tracker
//
//  Created by Juan Martinez on 4/1/26.
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications
#if os(iOS)
import Combine
import UIKit
#endif

private struct ProServiceEntitlements: Equatable {
    let canImportHealthWeight: Bool
    let canUseMultipleReminders: Bool
}

@main
struct cal_macro_trackerApp: App {
    private enum GoalSetupDisplayMode {
        case normal
        case forceOnLaunch
    }

    private let goalSetupDisplayMode: GoalSetupDisplayMode = .normal

    @AppStorage(AppStorageKeys.hasCompletedGoalSetup) private var hasCompletedGoalSetup = false
    @AppStorage(AppStorageKeys.isSharingDeviceEnabled) private var isSharingDeviceEnabled = false
    @State private var entitlements: AppEntitlements
    @State private var purchaseStore: PurchaseStore
    @State private var sharingAuthService: SharingAuthService
    @State private var sharingSyncService: SharingSyncService
    @State private var healthKitService = HealthKitService()
    @State private var reminderRefreshCoordinator = ReminderRefreshCoordinator()
    @State private var launchState = AppLaunchState()
    @State private var dayContext = AppDayContext()
    @State private var pendingOpenRequest: AppOpenRequest?
    @State private var didCompleteForcedGoalSetup = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @UIApplicationDelegateAdaptor(HomeScreenQuickActionAppDelegate.self) private var appDelegate
    #endif

    init() {
        MacroRingColorStorage.migrateLegacyStandardDefaultsToAppGroup()
        let entitlements = AppEntitlements()
        let sharingAuthService = SharingAuthService()
        _entitlements = State(initialValue: entitlements)
        _purchaseStore = State(initialValue: PurchaseStore(entitlements: entitlements))
        _sharingAuthService = State(initialValue: sharingAuthService)
        _sharingSyncService = State(initialValue: SharingSyncService(authService: sharingAuthService))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch launchState.phase {
                case .launching:
                    PlatformColors.groupedBackground
                case let .ready(modelContainer):
                    ZStack {
                        if shouldShowAppRoot {
                            AppRootView(pendingOpenRequest: $pendingOpenRequest)
                                .modelContainer(modelContainer)
                                .transition(.opacity.animation(.easeOut(duration: 0.2).delay(0.12)))
                                .zIndex(0)
                        } else {
                            OnboardingFlow {
                                completeGoalSetup()
                            }
                            .modelContainer(modelContainer)
                            .transition(
                                .asymmetric(
                                    insertion: .identity,
                                    removal: reduceMotion ? .opacity : .move(edge: .bottom)
                                )
                                .animation(.easeOut(duration: 0.22))
                            )
                            .zIndex(1)
                        }
                    }
                    .background(PlatformColors.groupedBackground)
                case let .failed(message):
                    AppLaunchErrorView(message: message)
                }
            }
            .environment(dayContext)
            .environment(entitlements)
            .environment(purchaseStore)
            .environment(sharingAuthService)
            .environment(sharingSyncService)
            .environment(healthKitService)
            .task {
                #if os(iOS)
                consumePendingQuickActionIfNeeded()
                #endif
                await launchState.start()
                refreshDayAndStartSharingDashboardSubscription()
                await purchaseStore.start()
                requestServiceRefresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                refreshDayAndStartSharingDashboardSubscription()
                Task { await purchaseStore.refreshEntitlements() }
                requestServiceRefresh()
            }
            .onChange(of: proServiceEntitlements) { _, _ in
                requestServiceRefresh()
            }
            .onChange(of: isSharingDeviceEnabled) { _, _ in
                sharingSyncService.startDashboardSubscription(for: dayContext.today)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshDayAndStartSharingDashboardSubscription()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                refreshDayAndStartSharingDashboardSubscription()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                refreshDayAndStartSharingDashboardSubscription()
            }
            .onReceive(NotificationCenter.default.publisher(for: .logEntryDidMutate)) { notification in
                Task {
                    if UserDefaults.standard.bool(forKey: AppStorageKeys.healthNutritionWriteEnabled),
                        case let .ready(container) = launchState.phase,
                        let id = notification.object as? String,
                        let uuid = UUID(uuidString: id),
                        let entries = try? container.mainContext.fetch(FetchDescriptor<LogEntry>()),
                        let entry = entries.first(where: { $0.id == uuid })
                    {
                        await healthKitService.writeNutrition(for: entry)
                    }
                    requestServiceRefresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .logEntryDidDelete)) { notification in
                Task {
                    if let id = notification.object as? String, let uuid = UUID(uuidString: id) {
                        await healthKitService.deleteNutrition(for: uuid)
                    }
                    requestServiceRefresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .remindersDidChange)) { _ in
                requestServiceRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthSettingsDidChange)) { _ in
                requestServiceRefresh()
            }
            .onOpenURL { url in
                pendingOpenRequest = nil
                DispatchQueue.main.async {
                    pendingOpenRequest = AppOpenRequest(url: url)
                }
            }
            #if os(iOS)
            .onReceive(appDelegate.$requestToken.dropFirst()) { _ in
                consumePendingQuickActionIfNeeded()
            }
            #endif
        }
    }

    private var shouldShowAppRoot: Bool {
        switch goalSetupDisplayMode {
        case .normal:
            hasCompletedGoalSetup
        case .forceOnLaunch:
            hasCompletedGoalSetup && didCompleteForcedGoalSetup
        }
    }

    private var proServiceEntitlements: ProServiceEntitlements {
        ProServiceEntitlements(
            canImportHealthWeight: entitlements.canUse(.healthWeightImport),
            canUseMultipleReminders: entitlements.canUse(.multipleReminders)
        )
    }

    private func completeGoalSetup() {
        withAnimation(.easeOut(duration: 0.22)) {
            hasCompletedGoalSetup = true
            didCompleteForcedGoalSetup = true
        }
    }

    private func refreshDayAndStartSharingDashboardSubscription() {
        dayContext.refresh()
        sharingSyncService.startDashboardSubscription(for: dayContext.today)
        if case let .ready(container) = launchState.phase {
            sharingSyncService.syncAfterDailyTotalsChange(container: container)
        }
    }

    private func refreshReminders() async {
        guard case let .ready(container) = launchState.phase else { return }
        await ReminderScheduler.refresh(container: container, hasPro: entitlements.canUse(.multipleReminders), calendar: .current)
        if entitlements.canUse(.healthWeightImport),
            UserDefaults.standard.bool(forKey: AppStorageKeys.healthWeightReadEnabled)
        {
            healthKitService.startWeightObservation(container: container)
        } else {
            healthKitService.stopWeightObservation()
        }
    }

    private func requestServiceRefresh() {
        reminderRefreshCoordinator.request { await refreshReminders() }
    }

    #if os(iOS)
    private func consumePendingQuickActionIfNeeded() {
        if let request = appDelegate.consumePendingRequest() {
            pendingOpenRequest = request
        }
    }
    #endif
}
