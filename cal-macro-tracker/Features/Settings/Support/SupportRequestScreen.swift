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

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMessageFocused: Bool

    private var messageLength: Int { message.trimmingCharacters(in: .whitespacesAndNewlines).count }

    var body: some View {
        Group {
            if didSend {
                sentConfirmation
            } else {
                form
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sentConfirmation: some View {
        ContentUnavailableView {
            Label {
                Text("Message Sent")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
            }
        } description: {
            Text(request.email == nil ? "Thanks for writing. We read every message." : "Thanks for writing. We’ll reply by email.")
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .sensoryFeedback(.success, trigger: didSend)
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
                    .focused($isMessageFocused)
                    .frame(minHeight: 150)
                    .overlay(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("How can we help?")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Message")
            } footer: {
                messageFooter
            }

            Section {
                TextField("Email (optional)", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text(emailIsInvalid ? "That email address doesn’t look right." : "Add your email if you’d like a reply.")
                    .foregroundStyle(emailIsInvalid ? Color.red : Color.secondary)
            }

            Section("Included with your message") {
                LabeledContent("App version", value: "\(request.appVersion) (\(request.build))")
                LabeledContent("iOS version", value: request.osVersion)
                LabeledContent("Device model", value: request.deviceModel)
            }

            Section {
                Link("Help on the web", destination: ProLegalLinks.support)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSending {
                    ProgressView()
                } else {
                    Button("Send") { Task { await send() } }
                        .disabled(!request.isValid)
                }
            }
        }
        .errorBanner(message: $errorMessage, title: "Couldn’t Send", retryTitle: "Retry") {
            Task { await send() }
        }
        .onChange(of: message) { _, newValue in
            if newValue.count > 4_000 { message = String(newValue.prefix(4_000)) }
        }
        .onChange(of: email) { _, newValue in
            if newValue.count > 254 { email = String(newValue.prefix(254)) }
        }
    }

    @ViewBuilder
    private var messageFooter: some View {
        if messageLength > 0 && messageLength < 10 {
            Text("Add a little more detail. Messages need at least 10 characters.")
        } else if message.count >= 3_500 {
            Text("\(message.count) / 4000")
                .monospacedDigit()
        }
    }

    private var emailIsInvalid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && messageLength >= 10 && !request.isValid
    }

    private func send() async {
        guard request.isValid, !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await SupportRequestClient.send(request, endpoint: Self.endpoint)
            didSend = true
        } catch {
            errorMessage = "Your message wasn’t sent. Check your connection and try again. Nothing was lost."
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
        #if targetEnvironment(simulator)
        if let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return model
        }
        #endif

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
