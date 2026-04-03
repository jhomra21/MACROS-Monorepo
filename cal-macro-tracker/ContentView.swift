//
//  ContentView.swift
//  cal-macro-tracker
//
//  Created by Juan Martinez on 4/1/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        AppRootView()
    }
}

private struct ContentViewPreview: View {
    var body: some View {
        Group {
            if let modelContainer = try? AppModelContainerFactory.makePreviewContainer() {
                ContentView()
                    .modelContainer(modelContainer)
            } else {
                AppLaunchErrorView(message: "Unable to create preview model container.")
            }
        }
    }
}

#Preview {
    ContentViewPreview()
}
