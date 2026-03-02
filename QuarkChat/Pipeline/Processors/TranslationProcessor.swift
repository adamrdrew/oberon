import Foundation
import FoundationModels

struct TranslationProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        do {
            let session = LanguageModelSession(
                instructions: "Extract the text to translate, the target language, and the source language (if specified) from the user's request."
            )

            let response = try await session.respond(
                to: query,
                generating: TranslationExtraction.self
            )

            let extraction = response.content
            let sourceText = extraction.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetLang = extraction.targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !sourceText.isEmpty, !targetLang.isEmpty else { return .empty }

            // Use a disposable LLM session for translation
            let translationSession = LanguageModelSession(
                instructions: "You are a translator. Translate the given text to \(targetLang). Return ONLY the translated text, nothing else."
            )

            let translationResponse = try await translationSession.respond(to: sourceText)
            let translatedText = translationResponse.content.trimmingCharacters(in: .whitespacesAndNewlines)

            let sourceLang = extraction.sourceLanguage.isEmpty ? "Auto-detected" : extraction.sourceLanguage

            let translationData = TranslationData(
                sourceText: sourceText,
                translatedText: translatedText,
                sourceLanguage: sourceLang,
                targetLanguage: targetLang
            )

            let copyAction = RichAction(
                type: .copyToClipboard,
                label: "Copy Translation",
                subtitle: translatedText,
                payload: ["text": translatedText]
            )

            return DomainResult(
                enrichmentText: "\(sourceText) → \(translatedText) (\(sourceLang) → \(targetLang))",
                citations: [],
                actions: [copyAction],
                richContent: [.translation(translationData)],
                suggestedReplies: SuggestedReply.forTranslation()
            )
        } catch {
            return .empty
        }
    }
}
