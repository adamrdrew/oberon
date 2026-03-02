import Foundation

/// Layer 3: Maps grouped LLM intents (8 broad categories) to specific MessageIntent values.
struct IntentSubRouter: Sendable {

    func route(groupedIntent: String, query: String) -> MessageIntent {
        switch groupedIntent {
        case "passthrough":
            return .passthrough

        case "factual_lookup":
            return .factualLookup

        case "calculation":
            return .calculation

        case "geo_search":
            return .geoSearch

        case "place_action":
            return .placeAction

        case "productivity":
            return routeProductivity(query: query)

        case "language":
            return routeLanguage(query: query)

        case "content_processing":
            return routeContentProcessing(query: query)

        default:
            return .passthrough
        }
    }

    // MARK: - Sub-routing

    private func routeProductivity(query: String) -> MessageIntent {
        let lower = query.lowercased()

        if lower.contains("timer") || lower.contains("countdown") {
            return .timer
        }

        if lower.contains("list") || lower.contains("checklist") || lower.contains("shopping") {
            return .checklist
        }

        // Default productivity intent
        return .reminder
    }

    private func routeLanguage(query: String) -> MessageIntent {
        let lower = query.lowercased()

        if lower.contains("define") || lower.contains("definition") || lower.contains("meaning") {
            return .definition
        }

        return .translation
    }

    private func routeContentProcessing(query: String) -> MessageIntent {
        let lower = query.lowercased()

        if lower.contains("proofread") || lower.contains("grammar") || lower.contains("spelling") {
            return .proofreading
        }

        if lower.contains("rewrite") || lower.contains("rephrase") || lower.contains("paraphrase") || lower.contains("reword") {
            return .rewriting
        }

        return .summarization
    }
}
