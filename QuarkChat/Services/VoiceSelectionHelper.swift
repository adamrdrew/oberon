import AVFoundation

/// Shared logic for selecting the best available TTS voice.
enum VoiceSelectionHelper {

    /// Returns the best voice for the given identifier, falling back to premium/enhanced auto-selection.
    static func voice(for identifier: String) -> AVSpeechSynthesisVoice? {
        if !identifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return bestAvailableVoice()
    }

    /// Selects the highest-quality voice for the current language.
    static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(lang) }
        return voices.first(where: { $0.quality == .premium })
            ?? voices.first(where: { $0.quality == .enhanced })
    }
}
