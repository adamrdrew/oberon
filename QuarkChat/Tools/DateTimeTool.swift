import Foundation
import FoundationModels

struct DateTimeTool: Tool {
    let name = "current_datetime"
    let description = "Get current date and time"

    @Generable
    struct Arguments {
        @Guide(description: "Timezone (optional, default: local)")
        var timezone: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"

        if let tz = arguments.timezone, let timeZone = TimeZone(identifier: tz) {
            formatter.timeZone = timeZone
        }

        return formatter.string(from: Date())
    }
}
