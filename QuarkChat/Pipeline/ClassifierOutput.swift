import Foundation
import FoundationModels

@Generable
struct ClassifierOutput {
    @Guide(description: "Self-contained rewrite of the user query that resolves pronouns and references")
    var expandedQuery: String

    @Guide(description: "Intent category", .anyOf([
        "passthrough", "factual_lookup", "calculation", "geo_search",
        "place_action", "productivity", "language", "content_processing"
    ]))
    var intent: String
}
