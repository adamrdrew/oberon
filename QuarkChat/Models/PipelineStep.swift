import Foundation

// MARK: - Pipeline Step Tracking

enum StepCategory: String, Codable, Sendable {
    case webSearch
    case calculation
    case geoSearch
    case weather
    case imageSearch
    case videoSearch
    case urlExtraction
    case wikipedia

    var icon: String {
        switch self {
        case .webSearch: return "globe"
        case .calculation: return "function"
        case .geoSearch: return "map"
        case .weather: return "cloud.sun"
        case .imageSearch: return "photo.on.rectangle.angled"
        case .videoSearch: return "play.rectangle"
        case .urlExtraction: return "link"
        case .wikipedia: return "book.closed"
        }
    }
}

enum StepStatus: String, Codable, Sendable {
    case active
    case completed
    case failed
}

struct PipelineStep: Codable, Identifiable, Sendable {
    let id: UUID
    let category: StepCategory
    let label: String
    let startedAt: Date
    var completedAt: Date?
    var status: StepStatus

    nonisolated init(category: StepCategory, label: String) {
        self.id = UUID()
        self.category = category
        self.label = label
        self.startedAt = Date()
        self.status = .active
    }
}
