import SwiftUI

struct WeatherCardView: View {
    let data: WeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Location + current temp
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.locationName)
                        .font(OTheme.conversationTitle)

                    Text("\(Int(data.temperature))°\(data.temperatureUnit)")
                        .font(OTheme.weatherTemp)
                }

                Spacer()

                Image(systemName: data.weatherSymbol)
                    .font(.system(size: 40, design: .monospaced))
                    .symbolRenderingMode(.multicolor)
            }

            // Details row
            HStack(spacing: 16) {
                Label("H: \(Int(data.highTemp))°", systemImage: "thermometer.high")
                    .font(OTheme.weatherDetail)
                Label("L: \(Int(data.lowTemp))°", systemImage: "thermometer.low")
                    .font(OTheme.weatherDetail)
                Label("\(Int(data.humidity))%", systemImage: "humidity")
                    .font(OTheme.weatherDetail)
                Label("\(Int(data.windSpeed)) mph", systemImage: "wind")
                    .font(OTheme.weatherDetail)
            }
            .foregroundStyle(OTheme.secondary)

            // 5-day forecast
            if !data.forecast.isEmpty {
                Divider()

                HStack(spacing: 0) {
                    ForEach(Array(data.forecast.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 4) {
                            Text(dayLabel(day.date))
                                .font(OTheme.timestamp)
                                .foregroundStyle(OTheme.secondary)
                            Image(systemName: WeatherData.symbolForCode(day.weatherCode))
                                .font(OTheme.caption)
                                .symbolRenderingMode(.multicolor)
                            Text("\(Int(day.highTemp))°")
                                .font(OTheme.timestamp)
                            Text("\(Int(day.lowTemp))°")
                                .font(OTheme.timestamp)
                                .foregroundStyle(OTheme.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(OTheme.teal.opacity(0.1)), in: .rect(cornerRadius: OTheme.cornerRadiusCard))
    }

    private func dayLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }
}
