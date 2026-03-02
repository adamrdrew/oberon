import Foundation

struct AppLaunchProcessor: Sendable {

    private static let appSchemes: [String: String] = [
        "safari": "https://",
        "settings": "App-prefs:",
        "maps": "maps://",
        "music": "music://",
        "notes": "mobilenotes://",
        "calendar": "calshow://",
        "reminders": "x-apple-reminderkit://",
        "mail": "mailto:",
        "messages": "sms:",
        "photos": "photos-redirect://",
        "camera": "camera://",
        "clock": "clock-worldclock://",
        "weather": "weather://",
        "files": "shareddocuments://",
        "phone": "tel:",
        "facetime": "facetime://",
        "app store": "itms-apps://",
        "news": "applenews://",
        "podcasts": "podcasts://",
        "books": "ibooks://",
        "health": "x-apple-health://",
        "wallet": "shoebox://",
        "shortcuts": "shortcuts://",
        "translate": "translate://",
    ]

    func process(query: String) async -> DomainResult {
        let appName = extractAppName(from: query)
        guard !appName.isEmpty else { return .empty }

        let lowerApp = appName.lowercased()
        guard let scheme = Self.appSchemes[lowerApp] else {
            return DomainResult(
                enrichmentText: "Unable to find the app '\(appName)'. Available apps: \(Self.appSchemes.keys.sorted().joined(separator: ", ")).",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        let action = RichAction(
            type: .openApp,
            label: "Open \(appName.capitalized)",
            subtitle: appName.capitalized,
            urlString: scheme
        )

        return DomainResult(
            enrichmentText: "Opening \(appName.capitalized).",
            citations: [],
            actions: [action],
            richContent: [],
            suggestedReplies: []
        )
    }

    private func extractAppName(from query: String) -> String {
        var text = query

        let prefixes = [
            "open the ",
            "open app ",
            "open ",
            "launch the ",
            "launch app ",
            "launch ",
            "start ",
        ]

        let lower = text.lowercased()
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        // Strip trailing " app"
        if text.lowercased().hasSuffix(" app") {
            text = String(text.dropLast(4))
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
