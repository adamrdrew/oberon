import Foundation

enum PromptAssembler {

    // MARK: - Instructions (called once per session creation)

    static func buildInstructions(userProfile: UserProfile?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d, yyyy h:mm a"
        let dateStr = formatter.string(from: Date())

        var parts: [String] = [
            "You are Oberon, a helpful AI assistant. You have tools available: web_search for current info, search_nearby for finding places, get_weather for weather, and calculator for math. Use them when the user's question would benefit from real data. For conversational messages, just respond naturally. When given tool results, give thorough, detailed answers using all the information. Don't greet or use the user's name repeatedly. Current: \(dateStr)."
        ]

        if let profile = userProfile {
            let profileStr = buildProfileParts(profile)
            if !profileStr.isEmpty {
                parts.append(profileStr)
            }
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Private

    private static func buildProfileParts(_ profile: UserProfile) -> String {
        var fields: [String] = []
        if !profile.name.isEmpty { fields.append("User: \(profile.name)") }
        if !profile.location.isEmpty { fields.append("Location: \(profile.location)") }
        if !profile.responsePreference.isEmpty { fields.append("Style: \(profile.responsePreference)") }
        if !profile.aboutMe.isEmpty { fields.append("About: \(profile.aboutMe)") }
        return fields.joined(separator: ". ") + (fields.isEmpty ? "" : ".")
    }
}
