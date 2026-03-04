import Foundation

struct VideoSearchData: Codable, Sendable {
    let query: String
    let videos: [VideoResult]

    struct VideoResult: Codable, Sendable, Identifiable {
        var id: String { videoURL }
        let title: String
        let videoURL: String
        let thumbnailURL: String
        let duration: String
        let publisher: String
        let uploader: String
        let published: String?
        let viewCount: Int?
    }
}
