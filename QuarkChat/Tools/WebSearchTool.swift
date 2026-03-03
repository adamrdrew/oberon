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

        // Check for Wikipedia source and fetch rich card data
        if let wikiResult = results.first(where: { isWikipediaURL($0.url) }),
           let wikiTitle = extractWikipediaTitle(from: wikiResult.url) {
            let baseURL = extractWikipediaBaseURL(from: wikiResult.url)
            let wikiService = WikipediaService()
            if let wikiData = await wikiService.fetchArticleData(title: wikiTitle, baseURL: baseURL) {
                await ToolResultStore.shared.addRichContent([.wikipedia(wikiData)])
            }
        }

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

    // MARK: - Wikipedia Detection

    private func isWikipediaURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host() else { return false }
        return host.contains("wikipedia.org")
    }

    private func extractWikipediaTitle(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let path = url.path()
        guard path.hasPrefix("/wiki/") else { return nil }
        let rawTitle = String(path.dropFirst(6))
        return rawTitle.removingPercentEncoding ?? rawTitle
    }

    private func extractWikipediaBaseURL(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              let host = url.host() else {
            return "https://en.wikipedia.org"
        }
        return "\(scheme)://\(host)"
    }
}
