import Foundation
import MapKit

struct ActionProcessor: Sendable {

    func process(query: String, userLocation: String?) async -> DomainResult {
        let requestedType = detectActionType(from: query)
        let placeName = stripActionVerbs(from: query)

        guard !placeName.isEmpty else { return .empty }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = placeName

            if let location = userLocation, !location.isEmpty {
                request.naturalLanguageQuery = "\(placeName) near \(location)"
            }

            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            guard let item = response.mapItems.first else { return .empty }

            let actions = buildActions(from: item, requestedType: requestedType)
            guard !actions.isEmpty else { return .empty }

            let enrichmentText = buildEnrichmentText(item: item, actions: actions)

            return DomainResult(
                enrichmentText: enrichmentText,
                citations: [],
                actions: actions,
                richContent: [],
                suggestedReplies: SuggestedReply.forPlaceAction()
            )
        } catch {
            return .empty
        }
    }

    // MARK: - Action Type Detection

    private func detectActionType(from query: String) -> RichActionType {
        let lower = query.lowercased()

        let callKeywords = ["call", "phone", "dial", "ring"]
        if callKeywords.contains(where: { lower.contains($0) }) {
            return .call
        }

        let websiteKeywords = ["website", "site", "webpage", "homepage", "url"]
        if websiteKeywords.contains(where: { lower.contains($0) }) {
            return .openWebsite
        }

        return .directions
    }

    // MARK: - Verb Stripping

    private func stripActionVerbs(from query: String) -> String {
        var text = query

        let patterns = [
            "get directions to ",
            "get directions for ",
            "directions to ",
            "directions for ",
            "navigate to ",
            "navigate me to ",
            "take me to ",
            "drive to ",
            "drive me to ",
            "walk to ",
            "how do i get to ",
            "how to get to ",
            "open the website for ",
            "open website for ",
            "open the website of ",
            "open website of ",
            "open the site for ",
            "go to the website of ",
            "go to the website for ",
            "visit the website of ",
            "visit the website for ",
            "call up ",
            "call ",
            "phone ",
            "dial ",
            "ring ",
            "open ",
        ]

        let lower = text.lowercased()
        for pattern in patterns {
            if lower.hasPrefix(pattern) {
                text = String(text.dropFirst(pattern.count))
                break
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Build Actions from MKMapItem

    private func buildActions(from item: MKMapItem, requestedType: RichActionType) -> [RichAction] {
        let name = item.name ?? "Unknown Place"
        let lat = item.placemark.coordinate.latitude
        let lon = item.placemark.coordinate.longitude

        var actions: [RichAction] = []

        // Directions — always available
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let directionsURL = "maps://?daddr=\(lat),\(lon)&q=\(encodedName)"
        actions.append(RichAction(
            type: .directions,
            label: "Get Directions",
            subtitle: name,
            urlString: directionsURL,
            latitude: lat,
            longitude: lon
        ))

        // Call — only if phone number exists
        if let phone = item.phoneNumber, !phone.isEmpty {
            let digits = phone.filter { $0.isNumber || $0 == "+" }
            actions.append(RichAction(
                type: .call,
                label: "Call",
                subtitle: name,
                urlString: "tel:\(digits)"
            ))
        }

        // Website — only if URL exists
        if let url = item.url {
            actions.append(RichAction(
                type: .openWebsite,
                label: "Open Website",
                subtitle: name,
                urlString: url.absoluteString
            ))
        }

        // Sort so the requested action type is first
        actions.sort { a, b in
            if a.type == requestedType && b.type != requestedType { return true }
            if a.type != requestedType && b.type == requestedType { return false }
            return false
        }

        return actions
    }

    // MARK: - Enrichment Text

    private func buildEnrichmentText(item: MKMapItem, actions: [RichAction]) -> String {
        let name = item.name ?? "Unknown Place"
        var parts: [String] = []

        if let placemark = item.placemark as? MKPlacemark {
            let addressParts = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode
            ].compactMap { $0 }
            if !addressParts.isEmpty {
                parts.append("Address: \(addressParts.joined(separator: " "))")
            }
        }

        if let phone = item.phoneNumber, !phone.isEmpty {
            parts.append("Phone: \(phone)")
        }

        if let url = item.url {
            parts.append("Website: \(url.absoluteString)")
        }

        let primary = actions.first
        let actionVerb: String
        switch primary?.type {
        case .directions: actionVerb = "Opening directions to"
        case .call: actionVerb = "Calling"
        case .openWebsite: actionVerb = "Opening website for"
        default: actionVerb = "Found"
        }

        let details = parts.isEmpty ? "" : "\n\(parts.joined(separator: "\n"))"
        return "\(actionVerb) \(name).\(details)"
    }
}
