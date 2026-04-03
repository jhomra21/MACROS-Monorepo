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
            if let modelContainer = launchState.modelContainer {
                ContentView()
                    .modelContainer(modelContainer)
            } else {
                AppLaunchErrorView(
                    message: launchState.launchErrorMessage ?? "The app could not initialize its local data store."
                )
            }
        }
    }
}
