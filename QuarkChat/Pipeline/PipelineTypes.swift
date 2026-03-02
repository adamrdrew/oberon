import Foundation
import SwiftUI

// MARK: - Intent Classification

enum MessageIntent: String, Codable, Sendable {
    case passthrough
    case factualLookup = "factual_lookup"
    case calculation
    case geoSearch = "geo_search"
    case placeAction = "place_action"
    // Productivity
    case reminder
    case timer
    case checklist
    // Language
    case translation
    case definition
    // Content processing
    case summarization
    case rewriting
    case proofreading
    // Utility
    case unitConversion = "unit_conversion"
    case weather
    // Contacts & communication
    case contactLookup = "contact_lookup"
    case composeMessage = "compose_message"
    // Media
    case playMusic = "play_music"
    // System
    case appLaunch = "app_launch"
    case clipboard
}

// MARK: - Pipeline Step Tracking

enum StepCategory: String, Codable, Sendable {
    case analysis
    case webSearch
    case calculation
    case geoSearch
    case action
    case composition
    // New categories
    case reminder
    case timer
    case checklist
    case translation
    case definition
    case summarization
    case rewriting
    case proofreading
    case unitConversion
    case weather
    case contacts
    case messaging
    case music
    case appLaunch
    case clipboard

    var icon: String {
        switch self {
        case .analysis: return "brain"
        case .webSearch: return "globe"
        case .calculation: return "function"
        case .geoSearch: return "map"
        case .action: return "arrow.up.forward.app"
        case .composition: return "text.page"
        case .reminder: return "bell.badge"
        case .timer: return "timer"
        case .checklist: return "checklist"
        case .translation: return "textformat.abc"
        case .definition: return "character.book.closed"
        case .summarization: return "text.redaction"
        case .rewriting: return "pencil.and.outline"
        case .proofreading: return "checkmark.seal"
        case .unitConversion: return "arrow.left.arrow.right"
        case .weather: return "cloud.sun"
        case .contacts: return "person.crop.circle"
        case .messaging: return "envelope.fill"
        case .music: return "music.note"
        case .appLaunch: return "arrow.up.forward.app.fill"
        case .clipboard: return "doc.on.doc"
        }
    }

    var color: Color {
        switch self {
        case .analysis: return .gray
        case .webSearch: return .blue
        case .calculation: return .purple
        case .geoSearch: return .green
        case .action: return .orange
        case .composition: return .green
        case .reminder: return .yellow
        case .timer: return .red
        case .checklist: return .indigo
        case .translation: return .teal
        case .definition: return .cyan
        case .summarization: return .mint
        case .rewriting: return .pink
        case .proofreading: return .brown
        case .unitConversion: return .purple
        case .weather: return .blue
        case .contacts: return .green
        case .messaging: return .blue
        case .music: return .pink
        case .appLaunch: return .orange
        case .clipboard: return .gray
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
    let actions: [RichAction]
    let richContent: [RichContent]
    let suggestedReplies: [SuggestedReply]

    static let empty = DomainResult(
        enrichmentText: "",
        citations: [],
        actions: [],
        richContent: [],
        suggestedReplies: []
    )

    /// Convenience init without rich content / suggested replies (backward compat)
    init(enrichmentText: String, citations: [Citation], actions: [RichAction]) {
        self.enrichmentText = enrichmentText
        self.citations = citations
        self.actions = actions
        self.richContent = []
        self.suggestedReplies = []
    }

    init(
        enrichmentText: String,
        citations: [Citation],
        actions: [RichAction],
        richContent: [RichContent],
        suggestedReplies: [SuggestedReply]
    ) {
        self.enrichmentText = enrichmentText
        self.citations = citations
        self.actions = actions
        self.richContent = richContent
        self.suggestedReplies = suggestedReplies
    }
}

struct ClassificationResult: Sendable {
    let expandedQuery: String
    let intent: MessageIntent
}

struct PipelineOutput: Sendable {
    let enrichedPrompt: String
    let intent: MessageIntent
    let citations: [Citation]
    let actions: [RichAction]
    let richContent: [RichContent]
    let suggestedReplies: [SuggestedReply]
    let pipelineSteps: [PipelineStep]
}
