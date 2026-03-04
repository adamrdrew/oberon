import Foundation

struct ImageSearchData: Codable, Sendable {
    let query: String
    let images: [ImageResult]

    struct ImageResult: Codable, Sendable, Identifiable {
        var id: String { thumbnail }
        let title: String
        let imageURL: String
        let thumbnail: String
        let sourceURL: String
        let width: Int
        let height: Int
    }
}
