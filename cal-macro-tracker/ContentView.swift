//
//  ContentView.swift
//  cal-macro-tracker
//
//  Created by Juan Martinez on 4/1/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Binding private var pendingOpenRequest: AppOpenRequest?

    init(pendingOpenRequest: Binding<AppOpenRequest?> = .constant(nil)) {
        _pendingOpenRequest = pendingOpenRequest
    }

    var body: some View {
        AppRootView(pendingOpenRequest: $pendingOpenRequest)
    }
}

// periphery:ignore - preview-only wrapper used by SwiftUI previews
private struct ContentViewPreview: View {
    var body: some View {
        Group {
            if let modelContainer = try? AppModelContainerFactory.makePreviewContainer() {
                ContentView()
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
