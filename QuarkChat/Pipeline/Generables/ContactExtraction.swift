import Foundation
import FoundationModels

@Generable
struct ContactExtraction {
    @Guide(description: "The person's name to look up")
    var personName: String

    @Guide(description: "What info the user wants", .anyOf(["phone", "email", "address", "all"]))
    var infoType: String
}
