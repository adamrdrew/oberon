import Foundation
import SwiftUI

// MARK: - Pipeline Step Tracking

enum StepCategory: String, Codable, Sendable {
    case webSearch
    case calculation
    case geoSearch
    case weather

    var icon: String {
        switch self {
        case .webSearch: return "globe"
        case .calculation: return "function"
        case .geoSearch: return "map"
        case .weather: return "cloud.sun"
        }
    }

    var color: Color {
        switch self {
        case .webSearch: return QTheme.quarkTeal
        case .calculation: return QTheme.quarkAccent
        case .geoSearch: return QTheme.quarkNavy
        case .weather: return QTheme.quarkTeal.opacity(0.7)
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

    init(category: StepCategory, label: String) {
        self.id = UUID()
        self.category = category
        self.label = label
        self.startedAt = Date()
        self.status = .active
    }
}
