import SwiftUI
import SwiftData

@main
struct QuarkChatApp: App {
    @State private var appState = AppState()

    let container: ModelContainer = {
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
            return try ModelContainer(
                for: Conversation.self, Message.self, UserProfile.self,
                configurations: syncedConfig, localConfig
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(container)
    }
}
