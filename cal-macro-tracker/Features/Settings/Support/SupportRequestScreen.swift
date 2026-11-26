import Darwin
import SwiftUI

struct SupportRequestScreen: View {
    @State private var category = SupportCategory.question
    @State private var message = ""
    @State private var email = ""
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    private var request: SupportRequest {
        let info = Bundle.main.infoDictionary
        return .make(
            category: category,
            message: message,
            email: email,
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            osVersion: Self.osVersion,
            deviceModel: Self.deviceModel
        )
    }

    var body: some View {
        Group {
            if didSend {
                ContentUnavailableView("Thanks — we got it", systemImage: "checkmark.circle")
            } else {
                form
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var form: some View {
        Form {
            Section {
                Picker("Category", selection: $category) {
                    ForEach(SupportCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                TextEditor(text: $message)
                    .frame(minHeight: 150)
                    .accessibilityLabel("Message")
                HStack {
                    Spacer()
                    Text("\(message.count) / 4000")
                        .foregroundStyle(message.count < 10 || message.count > 4_000 ? .secondary : .primary)
                }
                TextField("Email (optional, so we can reply)", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Please include at least 10 characters.")
            }

            Section("Included with your message") {
                LabeledContent("App version", value: "\(request.appVersion) (\(request.build))")
                LabeledContent("iOS version", value: request.osVersion)
                LabeledContent("Device model", value: request.deviceModel)
            }

            Section {
                Link("Help on the web", destination: ProLegalLinks.support)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(errorMessage == nil ? "Send" : "Retry")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!request.isValid || isSending)
            }
        }
        .onChange(of: message) { _, newValue in
            if newValue.count > 4_000 { message = String(newValue.prefix(4_000)) }
        }
        .onChange(of: email) { _, newValue in
            errorMessage = nil
            if newValue.count > 254 { email = String(newValue.prefix(254)) }
        }
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await SupportRequestClient.send(request, endpoint: Self.endpoint)
            didSend = true
        } catch {
            errorMessage = "Couldn’t send your request. Check your connection and try again."
        }
    }

    private static var endpoint: URL {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["MACROS_SUPPORT_ENDPOINT"],
            let url = URL(string: value)
        {
            return url
        }
        #endif
        return SupportRequestClient.endpoint
    }

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: systemInfo.machine) { bytes in
            String(cString: bytes.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
    }

    private static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
