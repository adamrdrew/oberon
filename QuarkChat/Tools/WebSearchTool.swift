import Foundation
import FoundationModels

struct WebSearchTool: Tool {
    let name = "web_search"
    let description = "Search the web for current information, news, facts, or anything you don't know. Use when the user asks about recent events, specific data, or anything that requires up-to-date info."

    private let searchService = WebSearchService()

    @Generable
    struct Arguments {
        @Guide(description: "Search query")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let step = PipelineStep(category: .webSearch, label: "Searching the web")
        await ToolResultStore.shared.addPipelineStep(step)

        let results = await searchService.search(query: arguments.query, maxResults: 3)

        if results.isEmpty {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "No results found for '\(arguments.query)'. Try a different search."
        }

        // Store citations for UI
        let citations = results.compactMap { result -> Citation? in
            guard !result.url.isEmpty else { return nil }
            return Citation(title: result.title, url: result.url)
        }
        await ToolResultStore.shared.addCitations(citations)
        await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forWebSearch())

        // Try to fetch and summarize the top result
        if let topURL = results.first?.url, !topURL.isEmpty,
           let summary = await searchService.fetchAndSummarize(url: topURL) {
            let source = results.first?.title ?? "web"
            await ToolResultStore.shared.completePipelineStep(id: step.id)
            return "From \(source): \(summary)"
        }

        // Fallback: return snippets
        await ToolResultStore.shared.completePipelineStep(id: step.id)
        return results.prefix(2).map { result in
            "\(result.title): \(result.snippet)"
        }.joined(separator: "\n")
    }
}
