import SwiftUI
import MarkdownUI

// MARK: - OTheme: Single source of truth for Oberon visual identity

enum OTheme {

    @MainActor private static var theme: ColorTheme { ThemeManager.shared.currentTheme }

    // MARK: - Adaptive Colors (computed from active theme)

    @MainActor static var background: Color { theme.background }
    @MainActor static var surface: Color    { theme.surface }
    @MainActor static var primary: Color    { theme.primary }
    @MainActor static var secondary: Color  { theme.secondary }
    @MainActor static var tertiary: Color   { theme.tertiary }
    @MainActor static var accent: Color     { theme.accent }
    @MainActor static var teal: Color       { theme.teal }
    @MainActor static var navy: Color       { theme.navy }
    @MainActor static var signalRed: Color  { theme.signalRed }
    @MainActor static var cream: Color      { theme.cream }

    // MARK: - Fixed Stripe Colors (computed from active theme band colors)

    @MainActor static var stripeOrange: Color { theme.band1 }
    @MainActor static var stripeTeal: Color   { theme.band2 }
    @MainActor static var stripeNavy: Color   { theme.band3 }
    @MainActor static var stripeRed: Color    { theme.band4 }
    @MainActor static var stripeCream: Color  { theme.band5 }

    @MainActor static var defaultStripeColors: [Color] { theme.stripeColors }

    // MARK: - Layout

    /// Standard horizontal padding for all chat content (bubbles, cards, pipeline, input)
    static let contentPadding: CGFloat = 16

    // MARK: - Corner Radii

    /// Chat bubbles, streaming message, typing indicator, error
    static let cornerRadiusBubble: CGFloat = 4

    /// Cards (weather, pipeline, code blocks)
    static let cornerRadiusCard: CGFloat = 3

    /// Input bar
    static let cornerRadiusInput: CGFloat = 4

    /// Small elements (code blocks inline)
    static let cornerRadiusSmall: CGFloat = 2

    // MARK: - Bubble Color Swatches (derived from active theme)

    @MainActor static var bubbleSwatches: [(name: String, hex: String, color: Color)] {
        theme.bubbleSwatches
    }

    // MARK: - Typography Scale
    //
    // SF Mono throughout. Weight provides contrast: bold for headings,
    // regular for body, medium for UI elements.

    /// 28pt bold monospaced — empty state headline
    static let displayLarge: Font = .system(size: 28, weight: .bold, design: .monospaced)

    /// 11pt bold monospaced — section headers (use with .textCase(.uppercase) + .tracking(3))
    static let sectionHeader: Font = .system(size: 11, weight: .bold, design: .monospaced)

    /// 13pt semibold monospaced — sidebar row titles
    static let conversationTitle: Font = .system(size: 13, weight: .semibold, design: .monospaced)

    /// 11pt regular monospaced — sidebar preview text
    static let conversationPreview: Font = .system(size: 11, weight: .regular, design: .monospaced)

    /// 10pt medium monospaced — timestamps, technical readouts
    static let timestamp: Font = .system(size: 10, weight: .medium, design: .monospaced)

    /// 10pt bold monospaced — pipeline labels (use with .textCase(.uppercase) + .tracking(1.5))
    static let pipelineLabel: Font = .system(size: 10, weight: .bold, design: .monospaced)

    /// 9pt bold monospaced — compact persisted pipeline steps
    static let pipelineLabelCompact: Font = .system(size: 9, weight: .bold, design: .monospaced)

    /// 13pt medium monospaced — suggested reply buttons
    static let suggestedReply: Font = .system(size: 13, weight: .medium, design: .monospaced)

    /// 36pt light monospaced — temperature display
    static let weatherTemp: Font = .system(size: 36, weight: .light, design: .monospaced)

    /// 10pt medium monospaced — weather detail stats
    static let weatherDetail: Font = .system(size: 10, weight: .medium, design: .monospaced)

    /// 10pt medium monospaced — citation links
    static let citation: Font = .system(size: 10, weight: .medium, design: .monospaced)

    /// 13pt regular monospaced — error message body text
    static let errorBody: Font = .system(size: 13, weight: .regular, design: .monospaced)

    /// 14pt regular monospaced — standard body text (chat input, form fields, descriptions)
    static let body: Font = .system(size: 14, weight: .regular, design: .monospaced)

    /// 12pt regular monospaced — secondary body text (subtitles, captions)
    static let bodySmall: Font = .system(size: 12, weight: .regular, design: .monospaced)

    /// 13pt medium monospaced — UI labels (buttons, action labels)
    static let label: Font = .system(size: 13, weight: .medium, design: .monospaced)

    /// 11pt regular monospaced — small captions
    static let caption: Font = .system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - Adaptive Color Initializer

extension Color {
    /// Creates a color that adapts between light and dark mode using hex strings.
    init(light lightHex: String, dark darkHex: String) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? darkHex : lightHex
            return NSColor(Color(hex: hex) ?? .clear)
        })
        #else
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(Color(hex: hex) ?? .clear)
        })
        #endif
    }
}

// MARK: - MarkdownUI Theme

extension Theme {
    @MainActor static var oberon: Theme { Theme()
        .text {
            FontFamilyVariant(.monospaced)
            FontSize(14)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(OTheme.teal)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
            }
            .background(OTheme.surface, in: .rect(cornerRadius: OTheme.cornerRadiusSmall))
            .markdownMargin(top: 8, bottom: 8)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 8)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.1))
        }
    }
}
