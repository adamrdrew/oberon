import Foundation

/// Bridges the Tool protocol (returns String) with rich UI metadata.
/// Tools populate this during `call()`, and ChatViewModel drains after each response.
actor ToolResultStore {
    static let shared = ToolResultStore()

    private(set) var citations: [Citation] = []
    private(set) var actions: [RichAction] = []
    private(set) var richContent: [RichContent] = []
    private(set) var suggestedReplies: [SuggestedReply] = []
    private(set) var pipelineSteps: [PipelineStep] = []

    /// Tracks which tools have already run this turn (prevents looping)
    private var toolsPerformed: Set<String> = []

    func hasToolPerformed(_ name: String) -> Bool {
        toolsPerformed.contains(name)
    }

    func markToolPerformed(_ name: String) {
        toolsPerformed.insert(name)
    }

    func addCitations(_ items: [Citation]) {
        citations.append(contentsOf: items)
    }

    func addActions(_ items: [RichAction]) {
        actions.append(contentsOf: items)
    }

    func addRichContent(_ items: [RichContent]) {
        richContent.append(contentsOf: items)
    }

    func addSuggestedReplies(_ items: [SuggestedReply]) {
        suggestedReplies.append(contentsOf: items)
    }

    func addPipelineStep(_ step: PipelineStep) {
        pipelineSteps.append(step)
    }

    func completePipelineStep(id: UUID) {
        if let idx = pipelineSteps.firstIndex(where: { $0.id == id }) {
            pipelineSteps[idx].status = .completed
            pipelineSteps[idx].completedAt = Date()
        }
    }

    func failPipelineStep(id: UUID) {
        if let idx = pipelineSteps.firstIndex(where: { $0.id == id }) {
            pipelineSteps[idx].status = .failed
            pipelineSteps[idx].completedAt = Date()
        }
    }

    /// Runs a tool's work inside a managed pipeline step, handling completion/failure automatically.
    /// Returns nil if the tool was already performed this turn (caller should return early message).
    func withPipelineStep(
        toolName: String,
        category: StepCategory,
        label: String,
        work: (UUID) async throws -> String
    ) async -> String? {
        guard !hasToolPerformed(toolName) else { return nil }
        markToolPerformed(toolName)

        let step = PipelineStep(category: category, label: label)
        addPipelineStep(step)

        do {
            let result = try await work(step.id)
            completePipelineStep(id: step.id)
            return result
        } catch {
            failPipelineStep(id: step.id)
            return nil
        }
    }

    struct ToolResults: Sendable {
        let citations: [Citation]
        let actions: [RichAction]
        let richContent: [RichContent]
        let suggestedReplies: [SuggestedReply]
        let pipelineSteps: [PipelineStep]
    }

    func takeAll() -> ToolResults {
        let results = ToolResults(
            citations: citations,
            actions: actions,
            richContent: richContent,
            suggestedReplies: suggestedReplies,
            pipelineSteps: pipelineSteps
        )
        citations = []
        actions = []
        richContent = []
        suggestedReplies = []
        pipelineSteps = []
        toolsPerformed = []
        return results
    }
}
