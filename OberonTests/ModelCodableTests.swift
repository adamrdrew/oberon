import Foundation
import Testing
@testable import Oberon

struct ModelCodableTests {

    // MARK: - Citation

    @Test func citationCodableRoundTrip() throws {
        let citation = Citation(title: "Wikipedia", url: "https://en.wikipedia.org")
        let data = try JSONEncoder().encode(citation)
        let decoded = try JSONDecoder().decode(Citation.self, from: data)
        #expect(decoded.title == "Wikipedia")
        #expect(decoded.url == "https://en.wikipedia.org")
    }

    @Test func citationArrayCodable() throws {
        let citations = [
            Citation(title: "A", url: "https://a.com"),
            Citation(title: "B", url: "https://b.com"),
        ]
        let data = try JSONEncoder().encode(citations)
        let decoded = try JSONDecoder().decode([Citation].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].title == "A")
        #expect(decoded[1].url == "https://b.com")
    }

    // MARK: - SuggestedReply

    @Test func suggestedReplyInit() {
        let reply = SuggestedReply(text: "Tell me more")
        #expect(reply.text == "Tell me more")
        #expect(!reply.id.uuidString.isEmpty)
    }

    @Test func suggestedReplyFactoryMethods() {
        #expect(!SuggestedReply.forWebSearch().isEmpty)
        #expect(!SuggestedReply.forImageSearch().isEmpty)
        #expect(!SuggestedReply.forVideoSearch().isEmpty)
        #expect(!SuggestedReply.forURLReader().isEmpty)
    }

    @Test func suggestedReplyCodableRoundTrip() throws {
        let reply = SuggestedReply(text: "More info")
        let data = try JSONEncoder().encode(reply)
        let decoded = try JSONDecoder().decode(SuggestedReply.self, from: data)
        #expect(decoded.id == reply.id)
        #expect(decoded.text == "More info")
    }

    // MARK: - RichAction

    @Test func richActionIcon() {
        let directions = RichAction(type: .directions, label: "Go")
        #expect(directions.icon == "arrow.triangle.turn.up.right.diamond.fill")

        let call = RichAction(type: .call, label: "Call")
        #expect(call.icon == "phone.fill")

        let web = RichAction(type: .openWebsite, label: "Open")
        #expect(web.icon == "safari.fill")

        let copy = RichAction(type: .copyToClipboard, label: "Copy")
        #expect(copy.icon == "doc.on.doc")
    }

    @Test func richActionCodableRoundTrip() throws {
        let action = RichAction(
            type: .directions,
            label: "Navigate",
            subtitle: "Coffee Shop",
            urlString: "https://maps.apple.com",
            latitude: 45.5,
            longitude: -122.6
        )
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(RichAction.self, from: data)
        #expect(decoded.type == .directions)
        #expect(decoded.label == "Navigate")
        #expect(decoded.subtitle == "Coffee Shop")
        #expect(decoded.latitude == 45.5)
        #expect(decoded.longitude == -122.6)
    }

    // MARK: - PlaceAction backward compat

    @Test func placeActionToRichActionConversion() {
        let place = PlaceAction(
            type: .directions,
            label: "Get Directions",
            placeName: "Voodoo Doughnut",
            urlString: "https://maps.apple.com",
            latitude: 45.5,
            longitude: -122.6
        )
        let rich = RichAction(from: place)
        #expect(rich.type == .directions)
        #expect(rich.label == "Get Directions")
        #expect(rich.subtitle == "Voodoo Doughnut")
        #expect(rich.latitude == 45.5)
    }

    // MARK: - WeatherData

    @Test func weatherSymbolForCode() {
        #expect(WeatherData.symbolForCode(0) == "sun.max.fill")
        #expect(WeatherData.symbolForCode(1) == "cloud.sun.fill")
        #expect(WeatherData.symbolForCode(3) == "cloud.fill")
        #expect(WeatherData.symbolForCode(45) == "cloud.fog.fill")
        #expect(WeatherData.symbolForCode(61) == "cloud.rain.fill")
        #expect(WeatherData.symbolForCode(71) == "cloud.snow.fill")
        #expect(WeatherData.symbolForCode(95) == "cloud.bolt.fill")
        #expect(WeatherData.symbolForCode(999) == "cloud.fill")  // unknown → default
    }

    // MARK: - RichContent

    @Test func richContentId() {
        let weather = RichContent.weather(WeatherData(
            locationName: "Portland",
            temperature: 72,
            temperatureUnit: "°F",
            weatherCode: 0,
            highTemp: 80,
            lowTemp: 60,
            humidity: 45,
            windSpeed: 10,
            forecast: []
        ))
        #expect(weather.id == "weather-Portland")
    }
}
