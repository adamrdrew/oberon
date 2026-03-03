import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    var name: String = ""
    var location: String = ""
    var aboutMe: String = ""
    var responsePreference: String = ""
    var favoriteColorHex: String = "#1E2D4D"
    var selectedThemeID: String = "quark"

    private var profile: UserProfile?

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

    func load(from profile: UserProfile) {
        self.profile = profile
        self.name = profile.name
        self.location = profile.location
        self.aboutMe = profile.aboutMe
        self.responsePreference = profile.responsePreference
        self.favoriteColorHex = profile.favoriteColorHex
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
    }
}
