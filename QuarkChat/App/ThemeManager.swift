import SwiftUI
import Observation

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: ColorTheme = .oberon
    @ObservationIgnored var hasLoadedInitialTheme = false

    private init() {}

    func applyTheme(id: String) {
        currentTheme = ColorTheme.theme(for: id)
    }
}
