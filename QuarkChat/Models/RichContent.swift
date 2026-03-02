import Foundation

// MARK: - Rich Content Container

enum RichContent: Codable, Identifiable, Sendable {
    case weather(WeatherData)
    case contact(ContactData)
    case event(EventData)
    case reminder(ReminderData)
    case timer(TimerData)
    case music(MusicData)
    case linkPreview(LinkPreviewData)
    case list(ListData)
    case translation(TranslationData)
    case unitConversion(UnitConversionData)

    var id: String {
        switch self {
        case .weather(let d): return "weather-\(d.locationName)"
        case .contact(let d): return "contact-\(d.name)"
        case .event(let d): return "event-\(d.title)"
        case .reminder(let d): return "reminder-\(d.title)"
        case .timer(let d): return "timer-\(d.label)"
        case .music(let d): return "music-\(d.title)"
        case .linkPreview(let d): return "link-\(d.url)"
        case .list(let d): return "list-\(d.title)"
        case .translation(let d): return "translation-\(d.sourceText)"
        case .unitConversion(let d): return "conversion-\(d.fromValue)\(d.fromUnit)"
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

struct ContactData: Codable, Sendable {
    let name: String
    let phoneNumber: String?
    let email: String?
    let initials: String

    init(name: String, phoneNumber: String? = nil, email: String? = nil) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        let parts = name.split(separator: " ")
        self.initials = parts.prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }
}

struct EventData: Codable, Sendable {
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let calendarColor: String // hex color
}

struct ReminderData: Codable, Sendable {
    let title: String
    let dueDate: Date?
    let priority: Int // 0=none, 1=low, 5=medium, 9=high
    let listName: String?
}

struct TimerData: Codable, Sendable {
    let label: String
    let durationSeconds: Int
    let fireDate: Date
}

struct MusicData: Codable, Sendable {
    let title: String
    let artist: String
    let albumName: String?
    let artworkURL: String?
    let mediaType: String // song, album, playlist
}

struct LinkPreviewData: Codable, Sendable {
    let url: String
    let title: String
    let description: String?
    let domain: String

    init(url: String, title: String, description: String? = nil) {
        self.url = url
        self.title = title
        self.description = description
        self.domain = URL(string: url)?.host ?? url
    }
}

struct ListData: Codable, Sendable {
    let title: String
    let items: [ListItem]

    struct ListItem: Codable, Sendable, Identifiable {
        let id: UUID
        let text: String
        var isChecked: Bool

        init(text: String, isChecked: Bool = false) {
            self.id = UUID()
            self.text = text
            self.isChecked = isChecked
        }
    }
}

struct TranslationData: Codable, Sendable {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
}

struct UnitConversionData: Codable, Sendable {
    let fromValue: Double
    let fromUnit: String
    let toValue: Double
    let toUnit: String
}
