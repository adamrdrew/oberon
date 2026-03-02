import Foundation
import MapKit

struct GeoSearchProcessor: Sendable {

    func process(query: String, userLocation: String?) async -> DomainResult {
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

            // Bias toward user's location if available
            if let location = userLocation, !location.isEmpty {
                request.naturalLanguageQuery = "\(query) near \(location)"
            }

            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let items = Array(response.mapItems.prefix(5))

            guard !items.isEmpty else { return .empty }

            let lines = items.enumerated().map { index, item in
                let name = item.name ?? "Unknown"
                let address = item.addressRepresentations?.description ?? name
                return "\(index + 1). \(name) — \(address)"
            }

            return DomainResult(
                enrichmentText: lines.joined(separator: "\n"),
                citations: []
            )
        } catch {
            return .empty
        }
    }
}
