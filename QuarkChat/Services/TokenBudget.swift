import Foundation

enum TokenBudget {
    // MARK: - Per-Intent Enrichment Caps (characters)

    static func enrichmentCap(for intent: MessageIntent) -> Int {
        switch intent {
        case .factualLookup:   return 1600
        case .weather:         return 400
        case .geoSearch:       return 600
        case .placeAction:     return 400
        case .calculation:     return 200
        case .unitConversion:  return 200
        case .definition:      return 400
        case .translation:     return 400
        case .summarization:   return 800
        case .rewriting:       return 800
        case .proofreading:    return 800
        case .reminder:        return 200
        case .timer:           return 200
        case .checklist:       return 400
        case .contactLookup:   return 300
        case .composeMessage:  return 400
        case .playMusic:       return 200
        case .appLaunch:       return 200
        case .clipboard:       return 200
        case .passthrough:     return 0
        }
    }

    static let conversationContextCap = 600  // chars

    // MARK: - Capping

    static func capEnrichment(_ text: String, for intent: MessageIntent) -> String {
        let cap = enrichmentCap(for: intent)
        guard cap > 0, text.count > cap else { return text }
        return String(text.prefix(cap - 3)) + "..."
    }

    static func capConversationContext(_ text: String) -> String {
        guard text.count > conversationContextCap else { return text }
        return String(text.prefix(conversationContextCap - 3)) + "..."
    }

    static func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }
}
