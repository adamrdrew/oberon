import SwiftUI

struct WelcomeView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("What's New in Oberon")
                .font(OTheme.displayLarge)
                .foregroundStyle(OTheme.primary)

            WelcomeRow(
                title: "Private AI",
                text: "Everything runs on-device. Your conversations never leave your phone.",
                systemImage: "lock.shield"
            )
            WelcomeRow(
                title: "Web Search",
                text: "Ask anything and Oberon can search the web for up-to-date answers.",
                systemImage: "globe"
            )
            WelcomeRow(
                title: "Weather",
                text: "Get current conditions and forecasts for any location.",
                systemImage: "cloud.sun"
            )
            WelcomeRow(
                title: "Nearby Places",
                text: "Find restaurants, shops, and services near you with directions.",
                systemImage: "map"
            )
            WelcomeRow(
                title: "Voice Mode",
                text: "Talk to Oberon and hear responses spoken aloud.",
                systemImage: "waveform"
            )

            Button("Continue", action: onDone)
                .keyboardShortcut(.defaultAction)
                .foregroundStyle(OTheme.accent)
                .font(OTheme.label)
                .padding(.top, 8)
        }
        .padding(40)
    }
}
