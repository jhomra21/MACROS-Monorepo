//
//  cal_macro_trackerApp.swift
//  cal-macro-tracker
//
//  Created by Juan Martinez on 4/1/26.
//

import Foundation
import SwiftData
import SwiftUI
#if os(iOS)
import Combine
import UIKit
#endif

@main
struct cal_macro_trackerApp: App {
    private enum GoalSetupDisplayMode {
        case normal
        case forceOnLaunch
    }

    private let goalSetupDisplayMode: GoalSetupDisplayMode = .normal

    @AppStorage("hasCompletedGoalSetup") private var hasCompletedGoalSetup = false
    @State private var launchState = AppLaunchState()
    @State private var dayContext = AppDayContext()
    @State private var pendingOpenRequest: AppOpenRequest?
    @State private var didCompleteForcedGoalSetup = false
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @UIApplicationDelegateAdaptor(HomeScreenQuickActionAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                switch launchState.phase {
                case .launching:
                    ProgressView("Starting app…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .ready(modelContainer):
                    ZStack {
                        if shouldShowAppRoot {
                            AppRootView(pendingOpenRequest: $pendingOpenRequest)
                                .modelContainer(modelContainer)
                                .transition(.opacity.animation(.easeOut(duration: 0.15).delay(0.15)))
                        } else {
                            GoalSetupScreen {
                                completeGoalSetup()
                            }
                            .modelContainer(modelContainer)
                            .transition(.opacity.animation(.easeOut(duration: 0.15)))
                        }
                    }
                case let .failed(message):
                    AppLaunchErrorView(message: message)
                }
            }
            .environment(dayContext)
            .task {
                #if os(iOS)
                consumePendingQuickActionIfNeeded()
                #endif
                await launchState.start()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                dayContext.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                dayContext.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                dayContext.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                dayContext.refresh()
            }
            .onOpenURL { url in
                pendingOpenRequest = AppOpenRequest(url: url)
            }
            #if os(iOS)
            .onReceive(appDelegate.$requestToken.dropFirst()) { _ in
                consumePendingQuickActionIfNeeded()
            }
            #endif
            .animation(.easeOut(duration: 0.15), value: hasCompletedGoalSetup)
            .animation(.easeOut(duration: 0.15), value: didCompleteForcedGoalSetup)
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

    private func completeGoalSetup() {
        withAnimation(.easeOut(duration: 0.15)) {
            hasCompletedGoalSetup = true
            didCompleteForcedGoalSetup = true
        }
    }

    #if os(iOS)
    private func consumePendingQuickActionIfNeeded() {
        if let request = appDelegate.consumePendingRequest() {
            pendingOpenRequest = request
        }
    }
    #endif
}
