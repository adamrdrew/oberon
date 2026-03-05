import Foundation

/// Shared DuckDuckGo VQD token fetching used by image and video search.
enum DDGTokenService {

    enum MediaType: String {
        case images
        case videos
    }

    static func fetchVQDToken(query: String, mediaType: MediaType) async -> String? {
        guard let url = URL(string: "https://duckduckgo.com/?q=\(query)&iax=\(mediaType.rawValue)&ia=\(mediaType.rawValue)") else {
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
}
