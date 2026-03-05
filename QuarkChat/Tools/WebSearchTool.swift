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
        // Prevent multiple searches per turn — one fan-out is enough
        if await ToolResultStore.shared.hasToolPerformed(name) {
            return "Search already completed. Use the results provided."
        }
        await ToolResultStore.shared.markToolPerformed(name)

        let step = PipelineStep(category: .webSearch, label: "Searching the web")
        await ToolResultStore.shared.addPipelineStep(step)

        let results = await searchService.search(query: arguments.query, maxResults: 5)

        if results.isEmpty {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "No results found for '\(arguments.query)'. Try a different search."
        }

        // Store citations for all results
        let citations = results.compactMap { result -> Citation? in
            guard !result.url.isEmpty else { return nil }
            return Citation(title: result.title, url: result.url)
        }
        await ToolResultStore.shared.addCitations(citations)
        await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forWebSearch())

        // Fan out: fetch all results in parallel
        let summaries = await fetchAllResults(results)

        // Store Wikipedia rich card if we got one
        if let wikiData = summaries.compactMap({ $0.wikiData }).first {
            await ToolResultStore.shared.addRichContent([.wikipedia(wikiData)])
        }

        await ToolResultStore.shared.completePipelineStep(id: step.id)

        // Build labeled multi-source result
        let labeled = summaries.compactMap { entry -> String? in
            guard let summary = entry.summary, !summary.isEmpty else { return nil }
            return "From \(entry.title): \(summary)"
        }

        if labeled.isEmpty {
            // Fallback to DDG snippets
            return results.prefix(3).map { "\($0.title): \($0.snippet)" }.joined(separator: "\n")
        }

        return labeled.joined(separator: "\n\n")
    }

    // MARK: - Parallel Fan-Out

    private struct FetchResult: Sendable {
        let index: Int
        let title: String
        let summary: String?
        let wikiData: WikipediaData?
    }

    private func fetchAllResults(_ results: [WebSearchService.SearchResult]) async -> [FetchResult] {
        let service = searchService
        let wikiService = WikipediaService()

        return await withTaskGroup(of: FetchResult.self, returning: [FetchResult].self) { group in
            for (index, result) in results.enumerated() {
                let title = result.title
                let url = result.url
                let isWiki = isWikipediaURL(url)

                group.addTask {
                    if isWiki, let wikiTitle = extractWikipediaTitle(from: url) {
                        let baseURL = extractWikipediaBaseURL(from: url)
                        let data = await wikiService.fetchArticleData(title: wikiTitle, baseURL: baseURL)
                        return FetchResult(
                            index: index,
                            title: title,
                            summary: data?.extract,
                            wikiData: data
                        )
                    } else {
                        let summary = await service.fetchAndExtract(url: url)
                        return FetchResult(index: index, title: title, summary: summary, wikiData: nil)
                    }
                }
            }

            var collected: [FetchResult] = []
            for await result in group {
                collected.append(result)
            }
            return collected.sorted { $0.index < $1.index }
        }
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
