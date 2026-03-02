import Foundation

enum PromptAssembler {
    /// Assembles instructions and prompt for a fresh per-turn session.
    static func assemble(
        conversationSummary: String,
        userProfile: UserProfile?,
        enrichedPrompt: String,
        intent: MessageIntent
    ) -> (instructions: String, prompt: String) {
        let instructions = buildInstructions()
        let prompt = buildPrompt(
            conversationSummary: conversationSummary,
            userProfile: userProfile,
            enrichedPrompt: enrichedPrompt,
            intent: intent
        )
        return (instructions, prompt)
    }

    // MARK: - Instructions (~60 tokens)

    private static func buildInstructions() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d, yyyy h:mm a"
        let dateStr = formatter.string(from: Date())

        return "You are Quark, a helpful AI assistant. When given research or web info, give thorough, detailed answers using all the information available. For simple questions, keep it brief. Use info between --- markers naturally; never mention it was provided. Don't greet or use the user's name. Current: \(dateStr)."
    }

    // MARK: - Prompt Assembly

    private static func buildPrompt(
        conversationSummary: String,
        userProfile: UserProfile?,
        enrichedPrompt: String,
        intent: MessageIntent
    ) -> String {
        var parts: [String] = []

        // Profile block (~30-50 tokens)
        if let profile = userProfile {
            let profileParts = buildProfileParts(profile)
            if !profileParts.isEmpty {
                parts.append(profileParts)
            }
        }

        // Conversation summary (~100-150 tokens)
        let trimmedSummary = conversationSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty {
            let capped = TokenBudget.capConversationContext(trimmedSummary)
            parts.append("Conversation so far: \(capped)")
        }

        // Enriched prompt (already contains user message + domain enrichment)
        parts.append(enrichedPrompt)

        return parts.joined(separator: "\n\n")
    }

    private static func buildProfileParts(_ profile: UserProfile) -> String {
        var fields: [String] = []
        if !profile.name.isEmpty { fields.append("User: \(profile.name)") }
        if !profile.location.isEmpty { fields.append("Location: \(profile.location)") }
        if !profile.responsePreference.isEmpty { fields.append("Style: \(profile.responsePreference)") }
        if !profile.aboutMe.isEmpty { fields.append("About: \(profile.aboutMe)") }
        return fields.joined(separator: ". ") + (fields.isEmpty ? "" : ".")
    }
}
