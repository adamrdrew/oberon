import Foundation

struct WikipediaData: Codable, Sendable {
    let title: String
    let description: String?
    let extract: String
    let articleURL: String
    let thumbnailURL: String?
    let images: [WikipediaImage]

    struct WikipediaImage: Codable, Sendable, Identifiable {
        var id: String { imageURL }
        let imageURL: String
        let filePageURL: String
        let caption: String?
    }
}
