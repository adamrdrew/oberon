import Foundation
import FoundationModels

@Generable
struct TranslationExtraction {
    @Guide(description: "The text to translate")
    var sourceText: String

    @Guide(description: "The target language name, e.g. 'Spanish', 'French', 'Japanese'")
    var targetLanguage: String

    @Guide(description: "The source language name if specified, e.g. 'English'. Empty if not specified.")
    var sourceLanguage: String
}
