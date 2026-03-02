import Foundation
import CoreLocation

struct WeatherProcessor: Sendable {

    func process(query: String, userLocation: String?) async -> DomainResult {
        // Extract location from query or fall back to user profile location
        let locationName = extractLocation(from: query) ?? userLocation ?? ""

        guard !locationName.isEmpty else {
            return DomainResult(
                enrichmentText: "I need a location to check the weather. Try asking about a specific city.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        // Geocode the location name to coordinates
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.geocodeAddressString(locationName).first,
              let location = placemark.location else {
            return DomainResult(
                enrichmentText: "Couldn't find the location '\(locationName)'.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let resolvedName = resolveLocationName(placemark: placemark, queriedName: locationName)

        // Fetch weather from Open-Meteo (free, no API key)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max&timezone=auto&forecast_days=5&temperature_unit=fahrenheit&wind_speed_unit=mph"

        guard let url = URL(string: urlString) else { return .empty }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .empty
            }

            return buildResult(from: json, locationName: resolvedName, query: query)
        } catch {
            return .empty
        }
    }

    // MARK: - Parse Response

    private func buildResult(from json: [String: Any], locationName: String, query: String) -> DomainResult {
        guard let current = json["current"] as? [String: Any],
              let daily = json["daily"] as? [String: Any] else {
            return .empty
        }

        let temp = current["temperature_2m"] as? Double ?? 0
        let weatherCode = current["weather_code"] as? Int ?? 0
        let windSpeed = current["wind_speed_10m"] as? Double ?? 0
        let humidity = current["relative_humidity_2m"] as? Double ?? 0

        let maxTemps = daily["temperature_2m_max"] as? [Double] ?? []
        let minTemps = daily["temperature_2m_min"] as? [Double] ?? []
        let dailyCodes = daily["weather_code"] as? [Int] ?? []
        let precipProbs = daily["precipitation_probability_max"] as? [Int] ?? []
        let dates = daily["time"] as? [String] ?? []

        let highTemp = maxTemps.first ?? temp
        let lowTemp = minTemps.first ?? temp

        // Build forecast days
        var forecast: [WeatherData.ForecastDay] = []
        for i in 0..<min(5, dates.count) {
            forecast.append(WeatherData.ForecastDay(
                date: i < dates.count ? dates[i] : "",
                weatherCode: i < dailyCodes.count ? dailyCodes[i] : 0,
                highTemp: i < maxTemps.count ? maxTemps[i] : 0,
                lowTemp: i < minTemps.count ? minTemps[i] : 0,
                precipProbability: i < precipProbs.count ? precipProbs[i] : 0
            ))
        }

        let weatherData = WeatherData(
            locationName: locationName,
            temperature: temp,
            temperatureUnit: "F",
            weatherCode: weatherCode,
            highTemp: highTemp,
            lowTemp: lowTemp,
            humidity: humidity,
            windSpeed: windSpeed,
            forecast: forecast
        )

        // Build comprehensive enrichment text for the LLM
        var enrichmentLines: [String] = []
        enrichmentLines.append("Location: \(locationName)")
        enrichmentLines.append("Current: \(Int(temp))°F, \(weatherDescription(for: weatherCode))")
        enrichmentLines.append("High/Low: \(Int(highTemp))°F / \(Int(lowTemp))°F")
        enrichmentLines.append("Humidity: \(Int(humidity))%, Wind: \(Int(windSpeed)) mph")

        if forecast.count > 1 {
            enrichmentLines.append("\nForecast:")
            for day in forecast.dropFirst() {
                let desc = weatherDescription(for: day.weatherCode)
                enrichmentLines.append("  \(day.date): \(desc), \(Int(day.highTemp))°F/\(Int(day.lowTemp))°F, \(day.precipProbability)% precip")
            }
        }

        return DomainResult(
            enrichmentText: enrichmentLines.joined(separator: "\n"),
            citations: [],
            actions: [],
            richContent: [.weather(weatherData)],
            suggestedReplies: SuggestedReply.forWeather()
        )
    }

    // MARK: - Helpers

    /// Resolve the best display name from a placemark, preferring city names over
    /// unincorporated areas, counties, or administrative regions.
    private func resolveLocationName(placemark: CLPlacemark, queriedName: String) -> String {
        // Prefer locality (city) — this is "New York", "San Francisco", etc.
        if let locality = placemark.locality, !locality.isEmpty {
            // Include state for US locations for clarity
            if let state = placemark.administrativeArea {
                return "\(locality), \(state)"
            }
            return locality
        }

        // Some areas return subLocality instead (neighborhoods, boroughs)
        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
            if let admin = placemark.administrativeArea {
                return "\(subLocality), \(admin)"
            }
            return subLocality
        }

        // If placemark.name matches an actual place and not a coordinate string
        if let name = placemark.name, !name.isEmpty,
           !name.contains(","), !name.contains(".") {
            return name
        }

        // Fall back to the user's original query text — it's what they asked for
        return queriedName
    }

    private func extractLocation(from query: String) -> String? {
        let lower = query.lowercased()

        // Try explicit patterns first
        let patterns = [
            "weather in ", "weather for ", "weather at ",
            "temperature in ", "temperature at ",
            "forecast for ", "forecast in ",
            "weather like in ", "weather like at ",
            "rain in ", "rain at ",
            "snow in ", "snow at ",
        ]

        for pattern in patterns {
            if let range = lower.range(of: pattern) {
                let location = String(query[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !location.isEmpty { return location }
            }
        }

        // Try "what's the weather" without a preposition — might be asking about their location
        let generalPatterns = ["what's the weather", "what is the weather", "how's the weather", "how is the weather"]
        for pattern in generalPatterns {
            if lower.contains(pattern) {
                // No explicit location — return nil to fall back to user profile location
                return nil
            }
        }

        return nil
    }

    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }
}
