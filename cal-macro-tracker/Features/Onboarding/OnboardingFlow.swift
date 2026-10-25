import SwiftData
import SwiftUI

struct OnboardingFlow: View {
    let onComplete: () -> Void
    @State private var profile = BodyProfileDraft()
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcomeScreen {
                path.append(.choice)
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .choice:
                    OnboardingChoiceScreen(onComplete: onComplete)
                case .aboutYou:
                    BodyProfileFormScreen(profile: $profile) {
                        path.append(.targets)
                    }
                case .targets:
                    TargetReviewScreen(profile: $profile, onComplete: onComplete)
                }
            }
        }
    }
}

enum OnboardingStep: Hashable {
    case choice
    case aboutYou
    case targets
}

private struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Calorie Tracker")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Label("No account needed", systemImage: "person.crop.circle.badge.checkmark")
                Label("Scan or add any food", systemImage: "barcode.viewfinder")
                Label("Your data stays on your phone", systemImage: "iphone")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            Spacer()
            BottomPinnedActionBar(title: "Get started", systemImage: nil, isDisabled: false, action: onContinue)
                .padding(.bottom, 8)
        }
        .padding(.top, 32)
        .background(PlatformColors.groupedBackground)
        .navigationBarBackButtonHidden()
    }
}

struct OnboardingChoiceScreen: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("How would you like to set your targets?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            choiceRows
            Spacer()
        }
        .padding(.top, 32)
        .navigationTitle("Set your goals")
        .inlineNavigationTitle()
    }

    @ViewBuilder
    private var choiceRows: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: 14) {
                rows
            }
        } else {
            rows
        }
    }

    private var rows: some View {
        VStack(spacing: 14) {
            NavigationLink(value: OnboardingStep.aboutYou) {
                choiceRow("Calculate my targets", subtitle: "Get a starting point based on your routine", symbol: "sparkles")
            }
            NavigationLink {
                GoalSetupScreen(onComplete: onComplete)
            } label: {
                choiceRow("I already know my numbers", subtitle: "Enter your daily goals directly", symbol: "slider.horizontal.3")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func choiceRow(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassRoundedRect(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}
