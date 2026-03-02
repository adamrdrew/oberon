import Foundation
import FoundationModels

@Generable
struct ClassifierOutput {
    @Guide(description: "Self-contained rewrite of the user query that resolves pronouns and references")
    var expandedQuery: String

    @Guide(description: "Intent category", .anyOf(["action", "passthrough", "factual_lookup", "calculation", "geo_search"]))
    var intent: String
}
