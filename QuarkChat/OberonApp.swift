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

    let container: ModelContainer

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
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(themeManager)
        }
        .modelContainer(container)
    }
}
