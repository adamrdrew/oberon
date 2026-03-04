import Foundation

actor ImageSearchService {

    func search(query: String, maxResults: Int = 8) async -> [ImageSearchData.ImageResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        // Step 1: Get vqd token from DDG
        guard let token = await fetchVQDToken(query: encoded) else { return [] }

        // Step 2: Fetch image results JSON
        guard let url = URL(string: "https://duckduckgo.com/i.js?l=us-en&o=json&q=\(encoded)&vqd=\(token)&f=,,,,,&p=1") else {
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("https://duckduckgo.com/", forHTTPHeaderField: "Referer")
            request.timeoutInterval = 5

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DDGImageResponse.self, from: data)

            guard let results = response.results else { return [] }

            return results.prefix(maxResults).compactMap { result in
                guard !result.image.isEmpty, !result.thumbnail.isEmpty else { return nil }
                return ImageSearchData.ImageResult(
                    title: result.title,
                    imageURL: result.image,
                    thumbnail: result.thumbnail,
                    sourceURL: result.url,
                    width: result.width,
                    height: result.height
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Private

    private func fetchVQDToken(query: String) async -> String? {
        guard let url = URL(string: "https://duckduckgo.com/?q=\(query)&iax=images&ia=images") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // Try multiple extraction patterns for resilience
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

    private struct DDGImageResponse: Decodable {
        let results: [DDGImageResult]?

        struct DDGImageResult: Decodable {
            let image: String
            let thumbnail: String
            let title: String
            let url: String
            let width: Int
            let height: Int
        }
    }
}
