import Foundation
import CoreLocation
import FoundationModels

struct GetWeatherTool: Tool {
    let name = "get_weather"
    let description = "Get current weather and forecast for a location. Returns temperature, conditions, humidity, wind, and 5-day forecast."

    let userLocation: String?

    @Generable
    struct Arguments {
        @Guide(description: "The city or location to get weather for, e.g. 'Tokyo', 'New York', 'London'")
        var location: String
    }

    func call(arguments: Arguments) async throws -> String {
        let step = PipelineStep(category: .weather, label: "Fetching weather")
        await ToolResultStore.shared.addPipelineStep(step)

        let locationName = arguments.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveLocation = locationName.isEmpty ? (userLocation ?? "") : locationName

        guard !effectiveLocation.isEmpty else {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "I need a location to check the weather."
        }

        // Geocode
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.geocodeAddressString(effectiveLocation).first,
              let location = placemark.location else {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "Couldn't find the location '\(effectiveLocation)'."
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let resolvedName = resolveLocationName(placemark: placemark, queriedName: effectiveLocation)

        // Fetch from Open-Meteo
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max&timezone=auto&forecast_days=5&temperature_unit=fahrenheit&wind_speed_unit=mph"

        guard let url = URL(string: urlString) else {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "Failed to fetch weather data."
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let daily = json["daily"] as? [String: Any] else {
                await ToolResultStore.shared.failPipelineStep(id: step.id)
                return "Failed to parse weather data."
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

            // Build forecast
            var forecast: [WeatherData.ForecastDay] = []
            for i in 0..<min(5, dates.count) {
                forecast.append(WeatherData.ForecastDay(
                    date: dates[i],
                    weatherCode: i < dailyCodes.count ? dailyCodes[i] : 0,
                    highTemp: i < maxTemps.count ? maxTemps[i] : 0,
                    lowTemp: i < minTemps.count ? minTemps[i] : 0,
                    precipProbability: i < precipProbs.count ? precipProbs[i] : 0
                ))
            }

            let weatherData = WeatherData(
                locationName: resolvedName,
                temperature: temp,
                temperatureUnit: "F",
                weatherCode: weatherCode,
                highTemp: highTemp,
                lowTemp: lowTemp,
                humidity: humidity,
                windSpeed: windSpeed,
                forecast: forecast
            )

            // Store rich content for UI
            await ToolResultStore.shared.addRichContent([.weather(weatherData)])
            await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forWeather())
            await ToolResultStore.shared.completePipelineStep(id: step.id)

            // Build text result for model
            var lines: [String] = []
            lines.append("Location: \(resolvedName)")
            lines.append("Current: \(Int(temp))°F, \(weatherDescription(for: weatherCode))")
            lines.append("High/Low: \(Int(highTemp))°F / \(Int(lowTemp))°F")
            lines.append("Humidity: \(Int(humidity))%, Wind: \(Int(windSpeed)) mph")

            if forecast.count > 1 {
                lines.append("\nForecast:")
                for day in forecast.dropFirst() {
                    lines.append("  \(day.date): \(weatherDescription(for: day.weatherCode)), \(Int(day.highTemp))°F/\(Int(day.lowTemp))°F, \(day.precipProbability)% precip")
                }
            }

            return lines.joined(separator: "\n")
        } catch {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "Failed to fetch weather data."
        }
    }

    // MARK: - Helpers

    private func resolveLocationName(placemark: CLPlacemark, queriedName: String) -> String {
        if let locality = placemark.locality, !locality.isEmpty {
            if let state = placemark.administrativeArea {
                return "\(locality), \(state)"
            }
            return locality
        }
        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
            if let admin = placemark.administrativeArea {
                return "\(subLocality), \(admin)"
            }
            return subLocality
        }
        if let name = placemark.name, !name.isEmpty,
           !name.contains(","), !name.contains(".") {
            return name
        }
        return queriedName
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
