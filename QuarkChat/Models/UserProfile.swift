import Foundation
import SwiftData
import SwiftUI

@Model
class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var location: String = ""
    var aboutMe: String = ""
    var responsePreference: String = ""
    var favoriteColorHex: String = "#007AFF"

    var favoriteColor: Color {
        Color(hex: favoriteColorHex) ?? .blue
    }

    init() {
        self.id = UUID()
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    var hexString: String {
        #if os(macOS)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        #else
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: nil)
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        #endif
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
