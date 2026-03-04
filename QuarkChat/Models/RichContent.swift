import Foundation

// MARK: - Rich Content Container

enum RichContent: Codable, Identifiable, Sendable {
    case weather(WeatherData)
    case wikipedia(WikipediaData)
    case images(ImageSearchData)
    case videos(VideoSearchData)
    case linkPreview(LinkPreviewData)

    var id: String {
        switch self {
        case .weather(let d): return "weather-\(d.locationName)"
        case .wikipedia(let d): return "wikipedia-\(d.title)"
        case .images(let d): return "images-\(d.query)"
        case .videos(let d): return "videos-\(d.query)"
        case .linkPreview(let d): return "linkPreview-\(d.url)"
        }
    }
}

// MARK: - Data Types

struct WeatherData: Codable, Sendable {
    let locationName: String
    let temperature: Double
    let temperatureUnit: String
    let weatherCode: Int
    let highTemp: Double
    let lowTemp: Double
    let humidity: Double
    let windSpeed: Double
    let forecast: [ForecastDay]

    struct ForecastDay: Codable, Sendable {
        let date: String
        let weatherCode: Int
        let highTemp: Double
        let lowTemp: Double
        let precipProbability: Int
    }

    var weatherSymbol: String {
        Self.symbolForCode(weatherCode)
    }

    static func symbolForCode(_ code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }
}
