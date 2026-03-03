import SwiftUI

// MARK: - QuarkColorTheme: Pure data defining all colors for one theme

struct QuarkColorTheme: Identifiable, Equatable {
    let id: String
    let displayName: String

    // MARK: - 5 Band Colors (fixed, used for stripes + swatches)

    let band1Hex: String
    let band2Hex: String
    let band3Hex: String
    let band4Hex: String
    let band5Hex: String

    // MARK: - 10 Adaptive Semantic Colors (light/dark pairs)

    let backgroundLight: String; let backgroundDark: String
    let surfaceLight: String;    let surfaceDark: String
    let primaryLight: String;    let primaryDark: String
    let secondaryLight: String;  let secondaryDark: String
    let tertiaryLight: String;   let tertiaryDark: String
    let accentLight: String;     let accentDark: String
    let tealLight: String;       let tealDark: String
    let navyLight: String;       let navyDark: String
    let signalRedLight: String;  let signalRedDark: String
    let creamLight: String;      let creamDark: String

    // MARK: - Computed Color Accessors

    var background: Color  { Color(light: backgroundLight, dark: backgroundDark) }
    var surface: Color     { Color(light: surfaceLight, dark: surfaceDark) }
    var primary: Color     { Color(light: primaryLight, dark: primaryDark) }
    var secondary: Color   { Color(light: secondaryLight, dark: secondaryDark) }
    var tertiary: Color    { Color(light: tertiaryLight, dark: tertiaryDark) }
    var accent: Color      { Color(light: accentLight, dark: accentDark) }
    var teal: Color        { Color(light: tealLight, dark: tealDark) }
    var navy: Color        { Color(light: navyLight, dark: navyDark) }
    var signalRed: Color   { Color(light: signalRedLight, dark: signalRedDark) }
    var cream: Color       { Color(light: creamLight, dark: creamDark) }

    // MARK: - Band Colors (fixed, not adaptive)

    var band1: Color { Color(hex: band1Hex)! }
    var band2: Color { Color(hex: band2Hex)! }
    var band3: Color { Color(hex: band3Hex)! }
    var band4: Color { Color(hex: band4Hex)! }
    var band5: Color { Color(hex: band5Hex)! }

    var stripeColors: [Color] { [band1, band2, band3, band4, band5] }

    var bubbleSwatches: [(name: String, hex: String, color: Color)] {
        [
            ("Band 1", band3Hex, band3),
            ("Band 2", band2Hex, band2),
            ("Band 3", band1Hex, band1),
            ("Band 4", band4Hex, band4),
            ("Band 5", band5Hex, band5),
        ]
    }
}

// MARK: - Predefined Themes

extension QuarkColorTheme {

    /// Current default — warm retro-future
    static let quark = QuarkColorTheme(
        id: "quark", displayName: "Quark",
        band1Hex: "#D4582A", band2Hex: "#2A8A8A", band3Hex: "#1E2D4D",
        band4Hex: "#C23B22", band5Hex: "#F5F2EB",
        backgroundLight: "#F5F2EB", backgroundDark: "#1A1721",
        surfaceLight: "#FFFDF7",    surfaceDark: "#252030",
        primaryLight: "#1C1B20",    primaryDark: "#F0EDE6",
        secondaryLight: "#6B6570",  secondaryDark: "#9B95A0",
        tertiaryLight: "#9B95A0",   tertiaryDark: "#5A5460",
        accentLight: "#D4582A",     accentDark: "#E8693A",
        tealLight: "#2A8A8A",       tealDark: "#3ABFB0",
        navyLight: "#1E2D4D",       navyDark: "#4A7AB5",
        signalRedLight: "#C23B22",  signalRedDark: "#D94E38",
        creamLight: "#F5F2EB",      creamDark: "#F0EDE6"
    )

    /// Cool neon on dark
    static let muon = QuarkColorTheme(
        id: "muon", displayName: "Muon",
        band1Hex: "#00D4FF", band2Hex: "#D946EF", band3Hex: "#64748B",
        band4Hex: "#8B5CF6", band5Hex: "#E0F2FE",
        backgroundLight: "#F0F4F8", backgroundDark: "#0F1219",
        surfaceLight: "#F8FAFC",    surfaceDark: "#1A1F2E",
        primaryLight: "#0F172A",    primaryDark: "#E2E8F0",
        secondaryLight: "#64748B",  secondaryDark: "#94A3B8",
        tertiaryLight: "#94A3B8",   tertiaryDark: "#475569",
        accentLight: "#0891B2",     accentDark: "#22D3EE",
        tealLight: "#D946EF",       tealDark: "#E879F9",
        navyLight: "#64748B",       navyDark: "#94A3B8",
        signalRedLight: "#7C3AED",  signalRedDark: "#A78BFA",
        creamLight: "#E0F2FE",      creamDark: "#CBD5E1"
    )

    /// 70s warm sunset
    static let tau = QuarkColorTheme(
        id: "tau", displayName: "Tau",
        band1Hex: "#D97706", band2Hex: "#B45309", band3Hex: "#CA8A04",
        band4Hex: "#7F1D1D", band5Hex: "#A0522D",
        backgroundLight: "#FEF3C7", backgroundDark: "#1C1208",
        surfaceLight: "#FFFBEB",    surfaceDark: "#2A1E0E",
        primaryLight: "#1C1208",    primaryDark: "#FEF3C7",
        secondaryLight: "#92400E",  secondaryDark: "#D97706",
        tertiaryLight: "#B45309",   tertiaryDark: "#78350F",
        accentLight: "#D97706",     accentDark: "#F59E0B",
        tealLight: "#B45309",       tealDark: "#D97706",
        navyLight: "#CA8A04",       navyDark: "#EAB308",
        signalRedLight: "#991B1B",  signalRedDark: "#DC2626",
        creamLight: "#FDE68A",      creamDark: "#FEF3C7"
    )

    /// Earth & terracotta
    static let pion = QuarkColorTheme(
        id: "pion", displayName: "Pion",
        band1Hex: "#C2703E", band2Hex: "#5F8575", band3Hex: "#A93226",
        band4Hex: "#C8A951", band5Hex: "#D2C6A5",
        backgroundLight: "#F5F0E8", backgroundDark: "#1A1712",
        surfaceLight: "#FAF8F2",    surfaceDark: "#252118",
        primaryLight: "#2D2418",    primaryDark: "#F0EAD6",
        secondaryLight: "#7D7060",  secondaryDark: "#A89A88",
        tertiaryLight: "#A89A88",   tertiaryDark: "#5C5245",
        accentLight: "#C2703E",     accentDark: "#D4895A",
        tealLight: "#5F8575",       tealDark: "#7AAF98",
        navyLight: "#A93226",       navyDark: "#D04A3E",
        signalRedLight: "#A93226",  signalRedDark: "#D04A3E",
        creamLight: "#D2C6A5",      creamDark: "#E8DECA"
    )

    /// Ocean depths
    static let gluon = QuarkColorTheme(
        id: "gluon", displayName: "Gluon",
        band1Hex: "#0D7377", band2Hex: "#E76F51", band3Hex: "#14213D",
        band4Hex: "#52B788", band5Hex: "#F0EFEB",
        backgroundLight: "#EFF6F5", backgroundDark: "#0A1218",
        surfaceLight: "#F7FBFA",    surfaceDark: "#121E28",
        primaryLight: "#0A1628",    primaryDark: "#E0ECE8",
        secondaryLight: "#4A6670",  secondaryDark: "#7FA0A8",
        tertiaryLight: "#7FA0A8",   tertiaryDark: "#3D5560",
        accentLight: "#0D7377",     accentDark: "#14B8A6",
        tealLight: "#E76F51",       tealDark: "#F08C70",
        navyLight: "#14213D",       navyDark: "#4A7AB5",
        signalRedLight: "#E76F51",  signalRedDark: "#F08C70",
        creamLight: "#F0EFEB",      creamDark: "#D6E4E0"
    )

    /// Apple rainbow retro
    static let kaon = QuarkColorTheme(
        id: "kaon", displayName: "Kaon",
        band1Hex: "#5AC94B", band2Hex: "#F57C20", band3Hex: "#E03C31",
        band4Hex: "#8B5CC0", band5Hex: "#2D7DD2",
        backgroundLight: "#F5F3F0", backgroundDark: "#18161E",
        surfaceLight: "#FEFDFB",    surfaceDark: "#221F2A",
        primaryLight: "#1E1B26",    primaryDark: "#F0ECF0",
        secondaryLight: "#6B6075",  secondaryDark: "#9B90A5",
        tertiaryLight: "#9B90A5",   tertiaryDark: "#504860",
        accentLight: "#E03C31",     accentDark: "#F06058",
        tealLight: "#5AC94B",       tealDark: "#78E068",
        navyLight: "#2D7DD2",       navyDark: "#5AA0E8",
        signalRedLight: "#E03C31",  signalRedDark: "#F06058",
        creamLight: "#F0ECF0",      creamDark: "#D8D0E0"
    )

    // MARK: - All Themes

    static let allThemes: [QuarkColorTheme] = [
        .quark, .muon, .tau, .pion, .gluon, .kaon,
    ]

    static func theme(for id: String) -> QuarkColorTheme {
        allThemes.first(where: { $0.id == id }) ?? .quark
    }
}
