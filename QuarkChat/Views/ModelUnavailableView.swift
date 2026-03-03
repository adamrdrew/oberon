import SwiftUI
import FoundationModels

struct ModelUnavailableView: View {
    let availability: SystemLanguageModel.Availability
    let onRetry: () -> Void

    @State private var appeared = false

    private var isDeviceIneligible: Bool {
        if case .unavailable(.deviceNotEligible) = availability { return true }
        return false
    }

    private var isDisabled: Bool {
        if case .unavailable(.appleIntelligenceNotEnabled) = availability { return true }
        return false
    }

    private var isModelNotReady: Bool {
        if case .unavailable(.modelNotReady) = availability { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48, design: .monospaced))
                    .foregroundStyle(iconColor)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                StripeAccentView()
                    .frame(width: 120)
                    .opacity(appeared ? 1 : 0)

                Text(headline)
                    .font(OTheme.displayLarge)
                    .foregroundStyle(OTheme.primary)
                    .multilineTextAlignment(.center)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(OTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)

                if isDisabled {
                    #if os(iOS)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(OTheme.label)
                    }
                    .buttonStyle(.glass)
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    #else
                    Text("Open System Settings > Apple Intelligence & Siri")
                        .font(OTheme.caption)
                        .foregroundStyle(OTheme.tertiary)
                        .padding(.top, 4)
                        .opacity(appeared ? 1 : 0)
                    #endif
                }

                if isModelNotReady {
                    ProgressView()
                        .padding(.top, 8)
                        .opacity(appeared ? 1 : 0)
                }

                if !isDeviceIneligible {
                    Button {
                        onRetry()
                    } label: {
                        Text("Check Again")
                            .font(OTheme.label)
                    }
                    .buttonStyle(.glass)
                    .padding(.top, 12)
                    .opacity(appeared ? 1 : 0)
                }
            }

            Spacer()

            // Bottom branding
            VStack(spacing: 4) {
                Text("OBERON")
                    .font(OTheme.sectionHeader)
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundStyle(OTheme.tertiary)
                Text("On-device AI chat")
                    .font(OTheme.caption)
                    .foregroundStyle(OTheme.tertiary.opacity(0.6))
            }
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: appeared)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
        .task {
            // Auto-retry for transient "model not ready" state
            guard isModelNotReady else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                onRetry()
            }
        }
    }

    // MARK: - Content per state

    private var icon: String {
        if isDeviceIneligible { return "iphone.slash" }
        if isDisabled { return "brain" }
        return "arrow.down.circle"
    }

    private var iconColor: Color {
        if isDeviceIneligible { return OTheme.signalRed }
        if isDisabled { return OTheme.accent }
        return OTheme.teal
    }

    private var headline: String {
        if isDeviceIneligible { return "Not Supported" }
        if isDisabled { return "Turn On Apple Intelligence" }
        return "Almost Ready"
    }

    private var subtitle: String {
        if isDeviceIneligible {
            return "Oberon requires Apple Intelligence, which isn't available on this device."
        }
        if isDisabled {
            return "Oberon needs Apple Intelligence to work. Enable it in Settings to get started."
        }
        return "Apple Intelligence is downloading. This usually takes a few minutes."
    }
}
