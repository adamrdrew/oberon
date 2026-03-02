import Foundation
import FoundationModels

struct WebSearchProcessor: Sendable {

    private let searchService = WebSearchService()

    /// Maximum total searches (initial + follow-ups).
    private let maxSearchRounds = 3

    func process(query: String) async -> DomainResult {
        // --- Round 1: initial search ---
        let initialResults = await searchService.search(query: query, maxResults: 3)
        guard !initialResults.isEmpty else { return .empty }

        var allResults = initialResults
        var pageExcerpts: [(source: String, text: String)] = []
        var searchQueries: [String] = [query]

        // Fetch page content from the top result
        if let topURL = initialResults.first?.url, !topURL.isEmpty {
            if let text = await searchService.fetchPageText(url: topURL) {
                pageExcerpts.append((
                    source: initialResults.first?.title ?? "top result",
                    text: String(text.prefix(1500))
                ))
            }
        }

        // --- Rounds 2-3: LLM-guided follow-ups ---
        for round in 2...maxSearchRounds {
            let currentSummary = buildCurrentSummary(
                query: query,
                results: allResults,
                excerpts: pageExcerpts
            )

            guard let followUp = await evaluateNeedForMoreSearch(
                originalQuery: query,
                currentSummary: currentSummary,
                previousQueries: searchQueries
            ) else {
                break // LLM says we have enough, or evaluation failed
            }

            // Execute the follow-up search
            let followUpResults = await searchService.search(query: followUp, maxResults: 2)
            guard !followUpResults.isEmpty else { break }

            // Deduplicate by URL
            let existingURLs = Set(allResults.map(\.url))
            let newResults = followUpResults.filter { !existingURLs.contains($0.url) }
            allResults.append(contentsOf: newResults)
            searchQueries.append(followUp)

            // Fetch page content from the best new result
            if let newTop = newResults.first, !newTop.url.isEmpty {
                if let text = await searchService.fetchPageText(url: newTop.url) {
                    pageExcerpts.append((
                        source: newTop.title,
                        text: String(text.prefix(1000))
                    ))
                }
            }
        }

        // --- Build final result ---
        let citations = allResults.compactMap { result -> Citation? in
            guard !result.url.isEmpty else { return nil }
            return Citation(title: result.title, url: result.url)
        }

        var lines: [String] = []

        if searchQueries.count > 1 {
            lines.append("Searched: \(searchQueries.joined(separator: " → "))")
            lines.append("")
        }

        for result in allResults {
            if !result.snippet.isEmpty {
                lines.append("\(result.title): \(result.snippet)")
            } else {
                lines.append(result.title)
            }
        }

        for excerpt in pageExcerpts {
            lines.append("\nFrom \(excerpt.source):\n\(excerpt.text)")
        }

        return DomainResult(
            enrichmentText: lines.joined(separator: "\n"),
            citations: citations,
            actions: [],
            richContent: [],
            suggestedReplies: SuggestedReply.forWebSearch()
        )
    }

    // MARK: - Multi-hop Evaluation

    /// Asks a lightweight LLM session whether more searching is needed.
    /// Returns a follow-up query if yes, nil if the information is sufficient.
    private func evaluateNeedForMoreSearch(
        originalQuery: String,
        currentSummary: String,
        previousQueries: [String]
    ) async -> String? {
        do {
            let session = LanguageModelSession(
                instructions: """
                You evaluate whether web search results fully answer a user's question. \
                If key facts are missing or the answer would be incomplete, suggest one \
                specific follow-up search query that would fill the gap. The follow-up \
                query must be DIFFERENT from previous searches.
                """
            )

            let prompt = """
            User question: \(originalQuery)
            Previous searches: \(previousQueries.joined(separator: ", "))

            Current findings (abbreviated):
            \(String(currentSummary.prefix(800)))

            Do we have enough info to answer well?
            """

            let response = try await session.respond(
                to: prompt,
                generating: SearchEvaluation.self
            )

            let evaluation = response.content

            if evaluation.hasSufficientInfo == "no",
               !evaluation.followUpQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return evaluation.followUpQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return nil
        } catch {
            // If evaluation fails, don't do follow-ups — just use what we have
            return nil
        }
    }

    /// Builds a concise summary of what we've found so far for the evaluation prompt.
    private func buildCurrentSummary(
        query: String,
        results: [WebSearchService.SearchResult],
        excerpts: [(source: String, text: String)]
    ) -> String {
        var parts: [String] = []

        for result in results.prefix(5) {
            if !result.snippet.isEmpty {
                parts.append("• \(result.title): \(result.snippet)")
            }
        }

        for excerpt in excerpts {
            parts.append("• [\(excerpt.source)] \(String(excerpt.text.prefix(300)))")
        }

        return parts.joined(separator: "\n")
    }
}
