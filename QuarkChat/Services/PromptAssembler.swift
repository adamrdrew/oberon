import Foundation

enum PromptAssembler {

    // MARK: - Instructions (called once per session creation)

    static func buildInstructions(userProfile: UserProfile?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d, yyyy h:mm a"
        let dateStr = formatter.string(from: Date())

        var parts: [String] = [
            "You are Oberon, a helpful AI assistant. You have tools available but only use them when clearly needed. search_nearby: ONLY when the user asks for a local business, restaurant, store, or service near them. get_weather: ONLY when the user explicitly asks about weather or forecast. web_search: when the user asks about current events, recent news, or something you're unsure about. calculator: when the user needs a math calculation. For general knowledge, science, history, trivia, or conversation, just answer directly without tools. When given tool results, give thorough answers using all the information. Don't greet or use the user's name repeatedly. Current: \(dateStr)."
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
