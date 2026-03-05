import Foundation

enum RichActionType: String, Codable, Sendable {
    case directions
    case call
    case openWebsite
    case copyToClipboard
}

struct RichAction: Codable, Identifiable, Sendable {
    let id: UUID
    let type: RichActionType
    let label: String
    let subtitle: String
    let urlString: String?
    let payload: [String: String]?
    let latitude: Double?
    let longitude: Double?

    var icon: String {
        switch type {
        case .directions: return "arrow.triangle.turn.up.right.diamond.fill"
        case .call: return "phone.fill"
        case .openWebsite: return "safari.fill"
        case .copyToClipboard: return "doc.on.doc"
        }
    }

    nonisolated init(
        type: RichActionType,
        label: String,
        subtitle: String = "",
        urlString: String? = nil,
        payload: [String: String]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.label = label
        self.subtitle = subtitle
        self.urlString = urlString
        self.payload = payload
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Convert from legacy PlaceAction
    init(from placeAction: PlaceAction) {
        self.id = placeAction.id
        self.label = placeAction.label
        self.subtitle = placeAction.placeName
        self.urlString = placeAction.urlString
        self.payload = nil
        self.latitude = placeAction.latitude
        self.longitude = placeAction.longitude

        switch placeAction.type {
        case .directions: self.type = .directions
        case .call: self.type = .call
        case .openWebsite: self.type = .openWebsite
        }
    }
}
