import Foundation
import SwiftData

@Model
class Conversation {
    var id: UUID = UUID()
    var title: String = "New Chat"
    var summary: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]?

    var sortedMessages: [Message] {
        (messages ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
