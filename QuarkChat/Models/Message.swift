import Foundation
import SwiftData

@Model
class Message {
    var id: UUID = UUID()
    var content: String = ""
    var role: String = "user"
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var isComplete: Bool = true

    // Tool tracking
    var toolName: String?
    var toolInput: String?
    var toolOutput: String?
    var citationsJSON: String?
    var pipelineStepsJSON: String?

    var citations: [Citation] {
        guard let json = citationsJSON, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Citation].self, from: data)) ?? []
    }

    var pipelineSteps: [PipelineStep] {
        guard let json = pipelineStepsJSON, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([PipelineStep].self, from: data)) ?? []
    }

    var conversation: Conversation?

    init(content: String, role: String, sortIndex: Int = 0) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.createdAt = Date()
        self.sortIndex = sortIndex
    }
}
