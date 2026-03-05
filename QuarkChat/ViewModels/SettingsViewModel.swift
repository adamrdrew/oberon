import Foundation
import Observation
import SwiftUI
import AVFoundation

@Observable
@MainActor
final class SettingsViewModel {
    var name: String = ""
    var location: String = ""
    var aboutMe: String = ""
    var responsePreference: String = ""
    var favoriteColorHex: String = "#1E2D4D"
    var selectedThemeID: String = "oberon"
    var selectedVoiceID: String = ""

    private var profile: UserProfile?
    private var previewSynthesizer = AVSpeechSynthesizer()

    static let maxAboutMeLength = 250
    static let maxResponsePrefLength = 250

    var aboutMeRemaining: Int {
        Self.maxAboutMeLength - aboutMe.count
    }

    var responsePrefRemaining: Int {
        Self.maxResponsePrefLength - responsePreference.count
    }

    var favoriteColor: Color {
        get { Color(hex: favoriteColorHex) ?? .blue }
        set { favoriteColorHex = newValue.hexString }
    }

    /// Voices available for the current language, sorted by quality (best first).
    var availableVoices: [AVSpeechSynthesisVoice] {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(lang) }
            .sorted { lhs, rhs in
                lhs.quality.rawValue > rhs.quality.rawValue
            }
    }

    func load(from profile: UserProfile) {
        self.profile = profile
        self.name = profile.name
        self.location = profile.location
        self.aboutMe = profile.aboutMe
        self.responsePreference = profile.responsePreference
        self.favoriteColorHex = profile.favoriteColorHex
        self.selectedVoiceID = profile.selectedVoiceID
        // Use ThemeManager as source of truth (profile may be stale if .id() rebuild interfered)
        self.selectedThemeID = ThemeManager.shared.currentTheme.id
    }

    func save(context: Any?) {
        guard let profile else { return }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.aboutMe = String(aboutMe.prefix(Self.maxAboutMeLength))
        profile.responsePreference = String(responsePreference.prefix(Self.maxResponsePrefLength))
        profile.favoriteColorHex = favoriteColorHex
        profile.themeID = selectedThemeID
        profile.selectedVoiceID = selectedVoiceID
    }

    func previewVoice(_ voiceID: String) {
        previewSynthesizer.stopSpeaking(at: .immediate)
        AudioSessionHelper.activatePlaybackSession()

        let utterance = AVSpeechUtterance(string: "Hello, I am Oberon")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        utterance.voice = VoiceSelectionHelper.voice(for: voiceID)
        previewSynthesizer.speak(utterance)
    }

    func stopPreview() {
        previewSynthesizer.stopSpeaking(at: .immediate)
    }
}
