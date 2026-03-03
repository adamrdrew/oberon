import Foundation

actor WikipediaService {

    // MARK: - API Response Models

    private struct SummaryResponse: Decodable {
        let title: String
        let description: String?
        let extract: String?
        let thumbnail: ImageInfo?
        let content_urls: ContentURLs?

        struct ImageInfo: Decodable {
            let source: String
            let width: Int
            let height: Int
        }

        struct ContentURLs: Decodable {
            let desktop: DesktopURL?
            struct DesktopURL: Decodable {
                let page: String?
            }
        }
    }

    private struct MediaListResponse: Decodable {
        let items: [MediaItem]?

        struct MediaItem: Decodable {
            let type: String
            let showInGallery: Bool?
            let title: String?
            let srcset: [SrcsetEntry]?
            let caption: Caption?

            struct SrcsetEntry: Decodable {
                let src: String
                let scale: String?
            }

            struct Caption: Decodable {
                let text: String?
            }
        }
    }

    // MARK: - Public API

    func fetchArticleData(title: String, baseURL: String = "https://en.wikipedia.org") async -> WikipediaData? {
        let encodedTitle = title
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title

        let summaryURL = URL(string: "\(baseURL)/api/rest_v1/page/summary/\(encodedTitle)")
        let mediaURL = URL(string: "\(baseURL)/api/rest_v1/page/media-list/\(encodedTitle)")

        guard let summaryURL, let mediaURL else { return nil }

        async let summaryResult = fetch(SummaryResponse.self, from: summaryURL)
        async let mediaResult = fetch(MediaListResponse.self, from: mediaURL)

        guard let summary = await summaryResult,
              let extract = summary.extract, !extract.isEmpty else {
            return nil
        }

        let mediaList = await mediaResult
        let images = buildImages(from: mediaList, baseURL: baseURL)

        let articleURL = summary.content_urls?.desktop?.page
            ?? "\(baseURL)/wiki/\(encodedTitle)"

        return WikipediaData(
            title: summary.title,
            description: summary.description,
            extract: extract,
            articleURL: articleURL,
            thumbnailURL: summary.thumbnail?.source,
            images: images
        )
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async -> T? {
        var request = URLRequest(url: url)
        request.setValue("Oberon/1.0 (iOS; oberon-app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func buildImages(from mediaList: MediaListResponse?, baseURL: String) -> [WikipediaData.WikipediaImage] {
        guard let items = mediaList?.items else { return [] }

        return items
            .filter { item in
                item.type == "image"
                    && item.showInGallery == true
                    && !(item.title?.lowercased().hasSuffix(".svg") ?? false)
            }
            .prefix(4)
            .compactMap { item -> WikipediaData.WikipediaImage? in
                guard let srcset = item.srcset, !srcset.isEmpty else { return nil }

                // Pick a moderate resolution image
                let src = srcset.first?.src ?? ""
                let imageURL = src.hasPrefix("//") ? "https:\(src)" : src
                guard !imageURL.isEmpty else { return nil }

                let filePageURL: String
                if let fileTitle = item.title {
                    let encoded = fileTitle
                        .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileTitle
                    filePageURL = "\(baseURL)/wiki/\(encoded)"
                } else {
                    filePageURL = ""
                }

                return WikipediaData.WikipediaImage(
                    imageURL: imageURL,
                    filePageURL: filePageURL,
                    caption: item.caption?.text
                )
            }
    }
}
