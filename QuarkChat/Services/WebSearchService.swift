import Foundation
import SwiftSoup
import Reductio

actor WebSearchService {
    struct SearchResult: Sendable {
        let title: String
        let snippet: String
        let url: String
    }

    func search(query: String, maxResults: Int = 5) async -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            return parseDuckDuckGoHTML(html, maxResults: maxResults)
        } catch {
            return []
        }
    }

    struct PageMetadata: Sendable {
        let title: String?
        let description: String?
        let imageURL: String?
        let siteName: String?
        let summary: String
    }

    func fetchWithMetadata(url urlString: String) async -> PageMetadata? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            let og = extractOGMetadata(from: html)

            let text = extractArticleText(from: html)
            if text.isEmpty {
                if og.title != nil || og.description != nil {
                    return PageMetadata(
                        title: og.title,
                        description: og.description,
                        imageURL: og.imageURL,
                        siteName: og.siteName,
                        summary: og.description ?? ""
                    )
                }
                return nil
            }

            let sentences = text.summarize(count: 5)
            let summary = sentences.isEmpty ? String(text.prefix(500)) : sentences.joined(separator: " ")

            return PageMetadata(
                title: og.title,
                description: og.description,
                imageURL: og.imageURL,
                siteName: og.siteName,
                summary: summary
            )
        } catch {
            return nil
        }
    }

    func fetchAndExtract(url urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            let text = extractArticleText(from: html)
            guard !text.isEmpty else { return nil }

            // TextRank extractive summarization — pick the 5 most important sentences
            let sentences = text.summarize(count: 5)
            guard !sentences.isEmpty else { return nil }
            return sentences.joined(separator: " ")
        } catch {
            return nil
        }
    }

    // MARK: - DDG HTML Parsing (SwiftSoup)

    private func parseDuckDuckGoHTML(_ html: String, maxResults: Int) -> [SearchResult] {
        do {
            let doc = try SwiftSoup.parse(html)
            let resultDivs = try doc.select(".result")
            var results: [SearchResult] = []

            for div in resultDivs.prefix(maxResults) {
                guard let link = try div.select("a.result__a").first() else { continue }
                let title = try link.text()
                let rawURL = try link.attr("href")
                let url = extractRealURL(from: rawURL)

                var snippet = ""
                if let snippetEl = try div.select("a.result__snippet").first() {
                    snippet = try snippetEl.text()
                } else if let snippetEl = try div.select(".result__snippet").first() {
                    snippet = try snippetEl.text()
                }

                if !title.isEmpty {
                    results.append(SearchResult(title: title, snippet: snippet, url: url))
                }
            }

            return results
        } catch {
            return []
        }
    }

    private func extractRealURL(from rawURL: String) -> String {
        if rawURL.contains("uddg=") {
            if let range = rawURL.range(of: "uddg=") {
                let after = String(rawURL[range.upperBound...])
                let encoded = after.components(separatedBy: "&").first ?? after
                if let decoded = encoded.removingPercentEncoding, !decoded.isEmpty {
                    return decoded
                }
            }
        }
        if rawURL.hasPrefix("//") {
            return "https:" + rawURL
        }
        return rawURL
    }

    // MARK: - Article Text Extraction (SwiftSoup)

    private func extractArticleText(from html: String) -> String {
        do {
            let doc = try SwiftSoup.parse(html)

            // Remove boilerplate elements
            for selector in ["script", "style", "nav", "header", "footer", "aside", "form", "iframe", "noscript", ".nav", ".menu", ".sidebar", ".footer", ".header", ".ad", ".advertisement"] {
                try doc.select(selector).remove()
            }

            // Try to find the main article content
            let contentSelectors = ["article", "main", "[role=main]", ".article-body", ".post-content", ".entry-content"]
            for selector in contentSelectors {
                if let content = try doc.select(selector).first() {
                    let text = try extractParagraphs(from: content)
                    if text.count > 200 {
                        return String(text.prefix(3000))
                    }
                }
            }

            // Fallback: extract all paragraphs from body
            if let body = doc.body() {
                let text = try extractParagraphs(from: body)
                if !text.isEmpty {
                    return String(text.prefix(3000))
                }
            }

            return ""
        } catch {
            return ""
        }
    }

    private func extractParagraphs(from element: Element) throws -> String {
        let paragraphs = try element.select("p")
        let texts = try paragraphs.array().compactMap { p -> String? in
            let text = try p.text().trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip very short paragraphs (likely UI elements, not content)
            return text.count > 40 ? text : nil
        }
        return texts.joined(separator: " ")
    }

    // MARK: - OG Metadata Extraction

    private struct OGData {
        let title: String?
        let description: String?
        let imageURL: String?
        let siteName: String?
    }

    private func extractOGMetadata(from html: String) -> OGData {
        do {
            let doc = try SwiftSoup.parse(html)

            func ogContent(_ property: String) -> String? {
                try? doc.select("meta[property=og:\(property)]").first()?.attr("content")
            }

            let title = ogContent("title") ?? (try? doc.title())
            let description = ogContent("description")
            let imageURL = ogContent("image")
            let siteName = ogContent("site_name")

            return OGData(title: title, description: description, imageURL: imageURL, siteName: siteName)
        } catch {
            return OGData(title: nil, description: nil, imageURL: nil, siteName: nil)
        }
    }
}
