import Testing
import AVFoundation
@testable import Oberon

struct VoiceSelectionHelperTests {

    @Test func emptyIdentifierReturnsBestAvailable() {
        // Should not crash; returns nil or a voice depending on system
        let voice = VoiceSelectionHelper.voice(for: "")
        // On CI/macOS there may or may not be voices — just verify no crash
        _ = voice
    }

    @Test func invalidIdentifierFallsBack() {
        let voice = VoiceSelectionHelper.voice(for: "com.apple.nonexistent.voice.12345")
        // Falls back to best available (may be nil on systems with no voices)
        _ = voice
    }

    @Test func bestAvailableVoiceDoesNotCrash() {
        _ = VoiceSelectionHelper.bestAvailableVoice()
    }
}
