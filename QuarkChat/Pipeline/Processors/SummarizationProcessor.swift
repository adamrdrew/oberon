import Foundation
import FoundationModels

struct SummarizationProcessor: Sendable {

    private let searchService = WebSearchService()

    func process(query: String) async -> DomainResult {
        // Check if query contains a URL
        if let url = extractURL(from: query) {
            return await summarizeURL(url, originalQuery: query)
        }

        // Otherwise, treat the text after "summarize" as the content to summarize
        let textToSummarize = extractText(from: query)
        guard !textToSummarize.isEmpty else { return .empty }

        return await summarizeText(textToSummarize)
    }

    // MARK: - URL Summarization

    private func summarizeURL(_ url: String, originalQuery: String) async -> DomainResult {
        guard let pageText = await searchService.fetchPageText(url: url) else {
            return DomainResult(
                enrichmentText: "Couldn't fetch content from that URL.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        let truncated = String(pageText.prefix(2000))

        do {
            let session = LanguageModelSession(
                instructions: "Summarize the following text in 3-5 concise bullet points. Focus on the key information."
            )
            let response = try await session.respond(to: truncated)
            let summary = response.content

            let domain = URL(string: url)?.host ?? url
            let linkPreview = LinkPreviewData(
                url: url,
                title: domain,
                description: String(summary.prefix(100))
            )

            let openAction = RichAction(
                type: .openWebsite,
                label: "Open Original",
                subtitle: domain,
                urlString: url
            )

            return DomainResult(
                enrichmentText: summary,
                citations: [Citation(title: domain, url: url)],
                actions: [openAction],
                richContent: [.linkPreview(linkPreview)],
                suggestedReplies: SuggestedReply.forSummarization()
            )
        } catch {
            return .empty
        }
    }

    // MARK: - Text Summarization

    private func summarizeText(_ text: String) async -> DomainResult {
        let truncated = String(text.prefix(2000))

        do {
            let session = LanguageModelSession(
                instructions: "Summarize the following text in 3-5 concise bullet points. Focus on the key information."
            )
            let response = try await session.respond(to: truncated)

            return DomainResult(
                enrichmentText: response.content,
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: SuggestedReply.forSummarization()
            )
        } catch {
            return .empty
        }
    }

    // MARK: - Helpers

    private func extractURL(from query: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(query.startIndex..., in: query)
        if let match = detector?.firstMatch(in: query, range: range),
           let url = match.url {
            return url.absoluteString
        }
        return nil
    }

    private func extractText(from query: String) -> String {
        var text = query

        let prefixes = [
            "summarize this: ",
            "summarize: ",
            "summarize ",
            "summary of: ",
            "summary of ",
            "tldr: ",
            "tldr ",
            "tl;dr: ",
            "tl;dr ",
            "sum up: ",
            "sum up ",
            "give me a summary of ",
        ]

        let lower = text.lowercased()
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
