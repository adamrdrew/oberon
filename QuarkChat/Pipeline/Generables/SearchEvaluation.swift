import Foundation
import FoundationModels

@Generable
struct SearchEvaluation {
    @Guide(description: "Whether the current search results are sufficient to fully answer the user's question. Say 'no' if important details are missing and another search would help. Say 'yes' if we have enough.", .anyOf(["yes", "no"]))
    var hasSufficientInfo: String

    @Guide(description: "A follow-up search query to find the missing information. Only meaningful when hasSufficientInfo is 'no'. Should be a different query angle than previous searches.")
    var followUpQuery: String
}
