import SwiftUI

enum Haptics {
    /// Light tap — user initiated an action (send message, start recording)
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Soft thud — something arrived (response complete)
    static func landed() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        #endif
    }

    /// Tick — selection changed (theme, color swatch)
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
