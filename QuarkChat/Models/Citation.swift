import Foundation

struct Citation: Codable, Sendable {
    let title: String
    let url: String
}

actor CitationStore {
    static let shared = CitationStore()

    private var pending: [Citation] = []

    func set(_ citations: [Citation]) {
        pending = citations
    }

    func take() -> [Citation] {
        let result = pending
        pending = []
        return result
    }
}
