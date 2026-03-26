import Foundation

enum ModelBackendType: String, Codable, CaseIterable, Sendable {
    case foundation
    case mlxBalanced
    case mlx

    var displayName: String {
        switch self {
        case .foundation: "Simple"
        case .mlxBalanced: "Balanced"
        case .mlx: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .foundation: "Built into your device. No download required."
        case .mlxBalanced: "Fast and capable. Requires a 1 GB download."
        case .mlx: "Best answers. Requires a 2.5 GB download."
        }
    }

    var detailDescription: String {
        switch self {
        case .foundation: "Uses Apple Intelligence built into your device. No extra download needed. Gentle on your battery."
        case .mlxBalanced: "Runs a smaller model on your device. Fast on all devices including iPhone, with a 1 GB download."
        case .mlx: "Runs the most powerful model on your device. Best answers, but requires a 2.5 GB download and uses more power."
        }
    }

    var isBeta: Bool {
        self == .mlx || self == .mlxBalanced
    }

    /// Whether this backend type uses MLX inference.
    var isMLX: Bool {
        self == .mlx || self == .mlxBalanced
    }
}
