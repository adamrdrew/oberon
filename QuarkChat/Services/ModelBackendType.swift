import Foundation

enum ModelBackendType: String, Codable, CaseIterable, Sendable {
    case foundation
    case mlx

    var displayName: String {
        switch self {
        case .foundation: "Simple"
        case .mlx: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .foundation: "Built into your device. No download required."
        case .mlx: "Better answers. Requires a 2.5 GB download."
        }
    }

    var detailDescription: String {
        switch self {
        case .foundation: "Uses Apple Intelligence built into your device. No extra download needed. Gentle on your battery."
        case .mlx: "Runs a more powerful model on your device. Can produce much better answers, but requires a 2.5 GB download and uses more power."
        }
    }

    var isBeta: Bool {
        self == .mlx
    }
}
