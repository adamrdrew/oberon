import Foundation
import MapKit
import FoundationModels

struct SearchNearbyTool: Tool {
    let name = "search_nearby"
    let description = "Search for nearby places, businesses, or points of interest. Returns names, addresses, and available actions (directions, call, website)."

    let userLocation: String?

    @Generable
    struct Arguments {
        @Guide(description: "What to search for, e.g. 'coffee shops', 'gas stations', 'Italian restaurants'")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let step = PipelineStep(category: .geoSearch, label: "Searching nearby")
        await ToolResultStore.shared.addPipelineStep(step)

        do {
            let request = MKLocalSearch.Request()
            if let location = userLocation, !location.isEmpty {
                request.naturalLanguageQuery = "\(arguments.query) near \(location)"
            } else {
                request.naturalLanguageQuery = arguments.query
            }

            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let items = Array(response.mapItems.prefix(5))

            guard !items.isEmpty else {
                await ToolResultStore.shared.failPipelineStep(id: step.id)
                return "No places found for '\(arguments.query)'."
            }

            // Build actions for each place
            var allActions: [RichAction] = []
            var lines: [String] = []

            for (index, item) in items.enumerated() {
                let name = item.name ?? "Unknown"
                let lat = item.placemark.coordinate.latitude
                let lon = item.placemark.coordinate.longitude

                // Build address
                let addressParts = [
                    item.placemark.subThoroughfare,
                    item.placemark.thoroughfare,
                    item.placemark.locality,
                    item.placemark.administrativeArea
                ].compactMap { $0 }
                let address = addressParts.isEmpty ? "" : addressParts.joined(separator: " ")

                lines.append("\(index + 1). \(name)\(address.isEmpty ? "" : " — \(address)")")

                // Directions action for each place
                let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
                allActions.append(RichAction(
                    type: .directions,
                    label: "Directions",
                    subtitle: name,
                    urlString: "maps://?daddr=\(lat),\(lon)&q=\(encodedName)",
                    latitude: lat,
                    longitude: lon
                ))

                // Call action if phone available
                if let phone = item.phoneNumber, !phone.isEmpty {
                    let digits = phone.filter { $0.isNumber || $0 == "+" }
                    allActions.append(RichAction(
                        type: .call,
                        label: "Call",
                        subtitle: name,
                        urlString: "tel:\(digits)"
                    ))
                }

                // Website action if available
                if let url = item.url {
                    allActions.append(RichAction(
                        type: .openWebsite,
                        label: "Website",
                        subtitle: name,
                        urlString: url.absoluteString
                    ))
                }
            }

            await ToolResultStore.shared.addActions(allActions)
            await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forGeoSearch())
            await ToolResultStore.shared.completePipelineStep(id: step.id)

            return lines.joined(separator: "\n")
        } catch {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "Search failed for '\(arguments.query)'. Try a different query."
        }
    }
}
