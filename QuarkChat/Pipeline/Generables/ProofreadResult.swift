import Foundation
import FoundationModels

@Generable
struct ProofreadResult {
    @Guide(description: "The corrected text with all grammar and spelling fixes applied")
    var correctedText: String

    @Guide(description: "Comma-separated list of corrections made, e.g. 'their→there, recieve→receive'")
    var corrections: String
}
