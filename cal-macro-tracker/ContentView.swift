//
//  ContentView.swift
//  cal-macro-tracker
//
//  Created by Juan Martinez on 4/1/26.
//

import SwiftData
import SwiftUI

// periphery:ignore - preview-only wrapper used by SwiftUI previews
private struct ContentViewPreview: View {
    var body: some View {
        Group {
            if let modelContainer = try? AppModelContainerFactory.makePreviewContainer() {
                AppRootView()
                    .modelContainer(modelContainer)
                    .environment(AppDayContext())
            } else {
                AppLaunchErrorView(message: "Unable to create preview model container.")
            }
        }
    }
}

#Preview {
    ContentViewPreview()
}
