import Foundation
import FoundationModels

@Generable
struct ComposeExtraction {
    @Guide(description: "The recipient's name")
    var recipient: String

    @Guide(description: "The message subject (for email). Empty if SMS.")
    var subject: String

    @Guide(description: "The message body content")
    var body: String

    @Guide(description: "Communication channel", .anyOf(["email", "sms"]))
    var channel: String
}
