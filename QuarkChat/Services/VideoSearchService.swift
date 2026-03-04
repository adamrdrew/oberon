import Foundation

actor VideoSearchService {

    func search(query: String, maxResults: Int = 6) async -> [VideoSearchData.VideoResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        guard let token = await fetchVQDToken(query: encoded) else { return [] }

        guard let url = URL(string: "https://duckduckgo.com/v.js?l=us-en&o=json&q=\(encoded)&vqd=\(token)") else {
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("https://duckduckgo.com/", forHTTPHeaderField: "Referer")
            request.timeoutInterval = 5

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DDGVideoResponse.self, from: data)

            guard let results = response.results else { return [] }

            return results.prefix(maxResults).compactMap { result in
                guard !result.content.isEmpty else { return nil }
                let thumbnailURL = result.images?.medium ?? result.images?.large ?? ""
                guard !thumbnailURL.isEmpty else { return nil }

                return VideoSearchData.VideoResult(
                    title: result.title,
                    videoURL: result.content,
                    thumbnailURL: thumbnailURL,
                    duration: result.duration ?? "",
                    publisher: result.publisher ?? "",
                    uploader: result.uploader ?? "",
                    published: result.published,
                    viewCount: result.statistics?.viewCount
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Private

    private func fetchVQDToken(query: String) async -> String? {
        guard let url = URL(string: "https://duckduckgo.com/?q=\(query)&iax=videos&ia=videos") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            let patterns = [
                #"vqd=([^&"']+)"#,
                #"vqd='([^']+)'"#,
                #"vqd="([^"]+)""#,
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    let token = String(html[range])
                    if !token.isEmpty { return token }
                }
            }

            return nil
        } catch {
            return nil
        }
    }

    private struct DDGVideoResponse: Decodable {
        let results: [DDGVideoResult]?

        struct DDGVideoResult: Decodable {
            let content: String
            let title: String
            let description: String?
            let duration: String?
            let images: DDGVideoImages?
            let publisher: String?
            let uploader: String?
            let published: String?
            let statistics: DDGVideoStats?
        }

        struct DDGVideoImages: Decodable {
            let medium: String?
            let large: String?
        }

        struct DDGVideoStats: Decodable {
            let viewCount: Int?
        }
    }
}
