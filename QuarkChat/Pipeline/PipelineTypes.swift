import Foundation
import SwiftUI

// MARK: - Intent Classification

enum MessageIntent: String, Codable, Sendable {
    case passthrough
    case factualLookup = "factual_lookup"
    case calculation
    case geoSearch = "geo_search"
}

// MARK: - Pipeline Step Tracking

enum StepCategory: String, Codable, Sendable {
    case analysis
    case webSearch
    case calculation
    case geoSearch
    case composition

    var icon: String {
        switch self {
        case .analysis: return "brain"
        case .webSearch: return "globe"
        case .calculation: return "function"
        case .geoSearch: return "map"
        case .composition: return "text.page"
        }
    }

    var color: Color {
        switch self {
        case .analysis: return .gray
        case .webSearch: return .blue
        case .calculation: return .purple
        case .geoSearch: return .green
        case .composition: return .green
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

// MARK: - Domain Results

struct DomainResult: Sendable {
    let enrichmentText: String
    let citations: [Citation]

    static let empty = DomainResult(enrichmentText: "", citations: [])
}

struct ClassificationResult: Sendable {
    let expandedQuery: String
    let intent: MessageIntent
}

struct PipelineOutput: Sendable {
    let enrichedPrompt: String
    let citations: [Citation]
    let pipelineSteps: [PipelineStep]
}
