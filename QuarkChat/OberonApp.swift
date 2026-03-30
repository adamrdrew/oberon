import SwiftUI
import SwiftData
import os

#if DEBUG
private let ckBootstrapVersion = 1
private let ckBootstrapKey = "oberon.ck.bootstrap.version"
#endif

@main
struct OberonApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager.shared

    let container: ModelContainer?
    let containerError: String?

    init() {
        let logger = Logger(subsystem: "com.adamdrew.oberon", category: "App")

        #if DEBUG
        CloudKitBootstrapper.bootstrapIfNeeded(
            modelTypes: [Conversation.self, Message.self],
            containerID: "iCloud.com.adamrdrew.QuarkChat",
            userDefaultsKey: ckBootstrapKey,
            currentVersion: ckBootstrapVersion,
            logger: logger
        )
        #endif

        let syncedSchema = Schema([Conversation.self, Message.self])
        let localSchema = Schema([UserProfile.self])

        let syncedConfig = ModelConfiguration(
            "Synced",
            schema: syncedSchema,
            cloudKitDatabase: .automatic
        )

        let localConfig = ModelConfiguration(
            "Local",
            schema: localSchema,
            cloudKitDatabase: .none
        )

        do {
            container = try ModelContainer(
                for: Conversation.self, Message.self, UserProfile.self,
                configurations: syncedConfig, localConfig
            )
            containerError = nil
        } catch {
            logger.error("Could not create ModelContainer: \(error)")
            container = nil
            containerError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .environment(appState)
                    .environment(themeManager)
                    .modelContainer(container)
            } else {
                DataErrorView(errorDescription: containerError)
            }
        }
    }
}

// MARK: - Data Error View

private struct DataErrorView: View {
    let errorDescription: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Oberon")
                .font(.largeTitle.bold())

            Text("Something went wrong setting up your data. Please try restarting the app.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            #if DEBUG
            if let errorDescription {
                Text(errorDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .padding(.top, 8)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
