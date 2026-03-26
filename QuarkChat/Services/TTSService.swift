import Foundation
import Observation
import AVFoundation

@Observable
@MainActor
final class TTSService: NSObject {
    var isSpeaking: Bool = false
    var currentMessageID: UUID?

    /// Called when TTS finishes speaking naturally (not on cancel).
    var onFinishedSpeaking: (() -> Void)?

    /// Voice identifier persisted from user settings. Empty = auto (best available).
    var selectedVoiceID: String = ""

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, messageID: UUID) {
        if isSpeaking && currentMessageID == messageID {
            stop()
            return
        }

        stop()

        // Strip markdown formatting for cleaner speech
        let cleanText = stripMarkdown(text)
        guard !cleanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        AudioSessionHelper.activatePlaybackSession()

        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        utterance.voice = VoiceSelectionHelper.voice(for: selectedVoiceID)

        currentMessageID = messageID
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentMessageID = nil
    }

    private func stripMarkdown(_ text: String) -> String {
        var result = text
        // Remove bold/italic markers
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "_", with: "")
        // Remove code blocks
        result = result.replacingOccurrences(of: "```", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        // Remove headers
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        // Remove bullet points
        result = result.replacingOccurrences(of: "- ", with: "")
        return result
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentMessageID = nil
            self.onFinishedSpeaking?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentMessageID = nil
        }
    }
}
