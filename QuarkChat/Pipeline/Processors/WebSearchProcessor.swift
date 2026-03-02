import Foundation

struct WebSearchProcessor: Sendable {

    private let searchService = WebSearchService()

    func process(query: String) async -> DomainResult {
        let results = await searchService.search(query: query, maxResults: 3)

        guard !results.isEmpty else { return .empty }

        // Build citations from search results
        let citations = results.compactMap { result -> Citation? in
            guard !result.url.isEmpty else { return nil }
            return Citation(title: result.title, url: result.url)
        }

        // Try to fetch actual page content from the top result for richer context
        var pageExcerpt = ""
        if let topURL = results.first?.url, !topURL.isEmpty {
            if let text = await searchService.fetchPageText(url: topURL) {
                pageExcerpt = String(text.prefix(1500))
            }
        }

        // Build enrichment from search snippets + page content
        var lines: [String] = []
        for result in results {
            if !result.snippet.isEmpty {
                lines.append("\(result.title): \(result.snippet)")
            } else {
                lines.append(result.title)
            }
        }

        if !pageExcerpt.isEmpty {
            lines.append("\nFrom \(results.first?.title ?? "top result"):\n\(pageExcerpt)")
        }

        return DomainResult(
            enrichmentText: lines.joined(separator: "\n"),
            citations: citations,
            actions: []
        )
    }
}
