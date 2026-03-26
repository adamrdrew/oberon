import Foundation

enum PromptAssembler {

    // MARK: - Instructions (called once per session creation)

    static func buildInstructions(userProfile: UserProfile?, backendType: ModelBackendType = .foundation) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d, yyyy h:mm a"
        let dateStr = formatter.string(from: Date())

        let toolGuidance: String
        switch backendType {
        case .foundation:
            toolGuidance = "Only use tools when clearly needed — for current events, recent news, or something you're unsure about. For general knowledge, science, history, trivia, or conversation, just answer directly."
        case .mlxBalanced:
            toolGuidance = "Only use tools when clearly needed — for current events, recent news, or something you're unsure about. For general knowledge, science, history, trivia, or conversation, just answer directly. Invoke tools directly — never announce intent."
        case .mlx:
            toolGuidance = "Use your tools to enrich responses with visual content. Call wikipedia for any notable topic. Call image_search when the subject is visual. Call video_search when it could be watched. Call web_search for current events or uncertainty. Call read_url for URLs. Invoke tools directly — never announce intent. For greetings or simple chat, respond without tools."
        }

        var parts: [String] = [
            "You are Oberon, a helpful AI assistant. \(toolGuidance) When given tool results, give thorough answers using all the information. Don't greet or use the user's name repeatedly. Current: \(dateStr)."
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
