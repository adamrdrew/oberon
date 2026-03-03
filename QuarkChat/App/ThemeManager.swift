import SwiftUI
import Observation

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: QuarkColorTheme = .quark
    @ObservationIgnored var hasLoadedInitialTheme = false

    private init() {}

    func applyTheme(id: String) {
        currentTheme = QuarkColorTheme.theme(for: id)
    }
}
