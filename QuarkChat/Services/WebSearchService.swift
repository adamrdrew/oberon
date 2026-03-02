import Foundation
import FoundationModels

actor WebSearchService {
    struct SearchResult: Sendable {
        let title: String
        let snippet: String
        let url: String
    }

    func search(query: String, maxResults: Int = 3) async -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            return parseDuckDuckGoHTML(html, maxResults: maxResults)
        } catch {
            return []
        }
    }

    func fetchPageText(url urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let text = extractTextContent(from: html)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    func fetchAndSummarize(url urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            let text = extractTextContent(from: html)
            let truncated = String(text.prefix(2000))

            let session = LanguageModelSession(
                instructions: "Summarize the following text in 2-3 concise sentences."
            )
            let response = try await session.respond(to: truncated)
            return response.content
        } catch {
            return nil
        }
    }

    private func parseDuckDuckGoHTML(_ html: String, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        // Split on result class markers
        let resultBlocks = html.components(separatedBy: "class=\"result__a\"")

        for block in resultBlocks.dropFirst().prefix(maxResults) {
            let title = extractBetween(block, start: ">", end: "</a>")
                .flatMap { stripHTML($0) } ?? "No title"

            let snippet: String
            if let snippetBlock = extractBetween(block, start: "class=\"result__snippet\"", end: "</a>") {
                snippet = stripHTML(snippetBlock)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } else if let snippetBlock = extractBetween(block, start: "class=\"result__snippet\">", end: "</") {
                snippet = stripHTML(snippetBlock)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } else {
                snippet = ""
            }

            let rawURL = extractBetween(block, start: "href=\"", end: "\"") ?? ""
            let url = extractRealURL(from: rawURL)

            if !title.isEmpty {
                results.append(SearchResult(title: title, snippet: snippet, url: url))
            }
        }

        return results
    }

    private func extractRealURL(from rawURL: String) -> String {
        // DuckDuckGo wraps URLs like //duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com&rut=...
        // Extract the actual destination from the uddg parameter
        if rawURL.contains("uddg=") {
            if let range = rawURL.range(of: "uddg=") {
                let after = String(rawURL[range.upperBound...])
                let encoded = after.components(separatedBy: "&").first ?? after
                if let decoded = encoded.removingPercentEncoding, !decoded.isEmpty {
                    return decoded
                }
            }
        }
        // If it's a protocol-relative URL, add https:
        if rawURL.hasPrefix("//") {
            return "https:" + rawURL
        }
        return rawURL
    }

    private func extractBetween(_ text: String, start: String, end: String) -> String? {
        guard let startRange = text.range(of: start) else { return nil }
        let after = text[startRange.upperBound...]
        guard let endRange = after.range(of: end) else { return nil }
        return String(after[..<endRange.lowerBound])
    }

    private func stripHTML(_ text: String) -> String? {
        var result = text
        // Remove HTML tags
        while let startRange = result.range(of: "<"),
              let endRange = result[startRange.lowerBound...].range(of: ">") {
            result.removeSubrange(startRange.lowerBound...endRange.lowerBound)
        }
        // Decode common entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#x27;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractTextContent(from html: String) -> String {
        var text = html
        // Remove script and style blocks
        while let scriptStart = text.range(of: "<script", options: .caseInsensitive),
              let scriptEnd = text[scriptStart.lowerBound...].range(of: "</script>", options: .caseInsensitive) {
            text.removeSubrange(scriptStart.lowerBound...scriptEnd.upperBound)
        }
        while let styleStart = text.range(of: "<style", options: .caseInsensitive),
              let styleEnd = text[styleStart.lowerBound...].range(of: "</style>", options: .caseInsensitive) {
            text.removeSubrange(styleStart.lowerBound...styleEnd.upperBound)
        }
        return stripHTML(text) ?? text
    }
}
