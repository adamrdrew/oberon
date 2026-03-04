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

    /// Tracks whether web search has already run this turn (prevents double-search)
    private(set) var webSearchPerformed: Bool = false

    func markWebSearchPerformed() {
        webSearchPerformed = true
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
        webSearchPerformed = false
        return results
    }
}
