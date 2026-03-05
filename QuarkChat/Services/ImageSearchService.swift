import Foundation

actor ImageSearchService {

    func search(query: String, maxResults: Int = 8) async -> [ImageSearchData.ImageResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        // Step 1: Get vqd token from DDG
        guard let token = await DDGTokenService.fetchVQDToken(query: encoded, mediaType: .images) else { return [] }

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
