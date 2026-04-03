//
//  cal_macro_trackerApp.swift
//  cal-macro-tracker
//
//  Created by Juan Martinez on 4/1/26.
//

import SwiftData
import SwiftUI

@main
struct cal_macro_trackerApp: App {
    @State private var launchState = AppLaunchState()

    var body: some Scene {
        WindowGroup {
            Group {
                switch launchState.phase {
                case .launching:
                    ProgressView("Starting app…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .ready(modelContainer):
                    ContentView()
                        .modelContainer(modelContainer)
                case let .failed(message):
                    AppLaunchErrorView(message: message)
                }
            }
            .task {
                await launchState.start()
            }
        }
    }
}
