import Foundation

struct LinkPreviewData: Codable, Sendable {
    let url: String
    let domain: String
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
    let summary: String
}
