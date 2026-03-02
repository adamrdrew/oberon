import Foundation

/// Layer 1: Pure-Swift keyword matching. Catches ~40-50% of queries instantly, no LLM call.
struct KeywordPreFilter: Sendable {

    struct Result: Sendable {
        let intent: MessageIntent?
        let expandedQuery: String?
    }

    func check(_ message: String) -> Result {
        let lower = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Short greetings → passthrough (skip LLM entirely)
        if isGreeting(lower) {
            return Result(intent: .passthrough, expandedQuery: message)
        }

        // Negative patterns — catch before positive matches
        if isNegativeReminder(lower) { return Result(intent: nil, expandedQuery: nil) }

        // Timer
        if matchesAny(lower, prefixes: ["set a timer", "set timer", "start a timer", "start timer", "countdown for", "timer for"]) {
            return Result(intent: .timer, expandedQuery: message)
        }

        // Reminder
        if matchesAny(lower, prefixes: ["remind me to", "remind me about", "don't forget to", "dont forget to", "set a reminder", "create a reminder"]) {
            return Result(intent: .reminder, expandedQuery: message)
        }

        // Translation
        if matchesAny(lower, prefixes: ["translate", "how do you say", "how to say", "say in"]) {
            return Result(intent: .translation, expandedQuery: message)
        }

        // Definition
        if matchesAny(lower, prefixes: ["define ", "definition of ", "meaning of ", "what does", "what is the meaning of"]) &&
           !lower.contains("weather") && !lower.contains("time") {
            // Only match "what does X mean" pattern
            if lower.hasPrefix("what does") && lower.hasSuffix("mean") {
                return Result(intent: .definition, expandedQuery: message)
            }
            if lower.hasPrefix("define") || lower.hasPrefix("definition") || lower.hasPrefix("meaning of") {
                return Result(intent: .definition, expandedQuery: message)
            }
        }

        // Summarization
        if matchesAny(lower, prefixes: ["summarize", "summary of", "tldr", "tl;dr", "give me a summary", "sum up"]) {
            return Result(intent: .summarization, expandedQuery: message)
        }

        // Unit conversion
        if isUnitConversion(lower) {
            return Result(intent: .unitConversion, expandedQuery: message)
        }

        // Proofreading
        if matchesAny(lower, prefixes: ["proofread", "proof read", "check my grammar", "fix my grammar", "grammar check"]) {
            return Result(intent: .proofreading, expandedQuery: message)
        }

        // Rewriting
        if matchesAny(lower, prefixes: ["rewrite", "rephrase", "paraphrase", "reword"]) {
            return Result(intent: .rewriting, expandedQuery: message)
        }

        // Clipboard
        if matchesAny(lower, prefixes: ["copy that", "copy the", "copy this", "copy my"]) {
            return Result(intent: .clipboard, expandedQuery: message)
        }

        // App launch
        if matchesAny(lower, prefixes: ["open app", "launch app", "open safari", "open settings", "open maps", "open music", "open notes", "open calendar", "open reminders", "open mail", "open messages", "open photos", "open camera", "open clock", "open weather", "open files"]) {
            return Result(intent: .appLaunch, expandedQuery: message)
        }

        // Checklist
        if matchesAny(lower, prefixes: ["create a list", "make a list", "create a checklist", "make a checklist", "shopping list", "to-do list", "todo list"]) {
            return Result(intent: .checklist, expandedQuery: message)
        }

        // Weather — straightforward patterns only
        if matchesAny(lower, substrings: ["what's the weather", "what is the weather", "weather forecast", "weather in ", "weather for ", "will it rain", "is it going to rain", "temperature in ", "temperature outside"]) {
            return Result(intent: .weather, expandedQuery: message)
        }

        // Music
        if matchesAny(lower, prefixes: ["play ", "play some", "play music"]) && !lower.contains("video") {
            return Result(intent: .playMusic, expandedQuery: message)
        }

        // No keyword match → send to LLM classifier
        return Result(intent: nil, expandedQuery: nil)
    }

    // MARK: - Helpers

    private func isGreeting(_ lower: String) -> Bool {
        let greetings = ["hi", "hey", "hello", "howdy", "yo", "sup", "good morning", "good afternoon", "good evening", "good night", "what's up", "whats up"]
        return greetings.contains(lower) || greetings.contains(where: { lower == "\($0)!" || lower == "\($0)." })
    }

    private func isNegativeReminder(_ lower: String) -> Bool {
        // "remind me what we talked about" → NOT a reminder intent
        let negativePatterns = ["remind me what", "remind me about our", "remind me of what"]
        return negativePatterns.contains(where: { lower.hasPrefix($0) })
    }

    private func isUnitConversion(_ lower: String) -> Bool {
        // "convert X to Y", "X miles in kilometers", "X pounds to kg"
        if lower.hasPrefix("convert ") && lower.contains(" to ") { return true }
        // Pattern: number + unit + "to"/"in" + unit
        let conversionPattern = #"^\d+(\.\d+)?\s*\w+\s+(to|in)\s+\w+"#
        return lower.range(of: conversionPattern, options: .regularExpression) != nil
    }

    private func matchesAny(_ text: String, prefixes: [String]) -> Bool {
        prefixes.contains(where: { text.hasPrefix($0) })
    }

    private func matchesAny(_ text: String, substrings: [String]) -> Bool {
        substrings.contains(where: { text.contains($0) })
    }
}
