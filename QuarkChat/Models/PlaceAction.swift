import Foundation

enum PlaceActionType: String, Codable, Sendable {
    case directions
    case call
    case openWebsite
}

struct PlaceAction: Codable, Identifiable, Sendable {
    let id: UUID
    let type: PlaceActionType
    let label: String
    let placeName: String
    let urlString: String
    let latitude: Double?
    let longitude: Double?

    var icon: String {
        switch type {
        case .directions: return "arrow.triangle.turn.up.right.diamond.fill"
        case .call: return "phone.fill"
        case .openWebsite: return "safari.fill"
        }
    }

    init(type: PlaceActionType, label: String, placeName: String, urlString: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = UUID()
        self.type = type
        self.label = label
        self.placeName = placeName
        self.urlString = urlString
        self.latitude = latitude
        self.longitude = longitude
    }
}
