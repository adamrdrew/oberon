import Foundation
import FoundationModels

@Generable
struct TimerExtraction {
    @Guide(description: "Total duration in seconds, e.g. 300 for 5 minutes")
    var durationSeconds: Int

    @Guide(description: "Human-readable duration label, e.g. '5 minutes'")
    var durationLabel: String

    @Guide(description: "Optional label for the timer, e.g. 'pasta'. Empty if none.")
    var label: String
}
