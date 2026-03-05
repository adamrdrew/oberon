import Testing
@testable import Oberon

struct ColorThemeTests {

    @Test func allThemesContainsSixThemes() {
        #expect(ColorTheme.allThemes.count == 6)
    }

    @Test func themeIdsAreUnique() {
        let ids = ColorTheme.allThemes.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func themeLookupByID() {
        let theme = ColorTheme.theme(for: "titania")
        #expect(theme.id == "titania")
        #expect(theme.displayName == "Titania")
    }

    @Test func themeLookupFallsBackToOberon() {
        let theme = ColorTheme.theme(for: "nonexistent")
        #expect(theme.id == "oberon")
    }

    @Test func legacyIDMigration() {
        #expect(ColorTheme.theme(for: "quark").id == "oberon")
        #expect(ColorTheme.theme(for: "muon").id == "titania")
        #expect(ColorTheme.theme(for: "tau").id == "ariel")
        #expect(ColorTheme.theme(for: "pion").id == "miranda")
        #expect(ColorTheme.theme(for: "gluon").id == "puck")
        #expect(ColorTheme.theme(for: "kaon").id == "umbriel")
    }

    @Test func eachThemeHasFiveBubbleSwatches() {
        for theme in ColorTheme.allThemes {
            #expect(theme.bubbleSwatches.count == 5, "Theme \(theme.id) should have 5 swatches")
        }
    }

    @Test func eachThemeHasFiveStripeColors() {
        for theme in ColorTheme.allThemes {
            #expect(theme.stripeColors.count == 5, "Theme \(theme.id) should have 5 stripe colors")
        }
    }

    @Test func eachThemeHasDisplayName() {
        for theme in ColorTheme.allThemes {
            #expect(!theme.displayName.isEmpty, "Theme \(theme.id) should have a display name")
        }
    }
}
