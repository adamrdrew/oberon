import SwiftUI

struct WeatherCardView: View {
    let data: WeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Location + current temp
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.locationName)
                        .font(QTheme.conversationTitle)

                    Text("\(Int(data.temperature))°\(data.temperatureUnit)")
                        .font(QTheme.weatherTemp)
                }

                Spacer()

                Image(systemName: data.weatherSymbol)
                    .font(.system(size: 40, design: .monospaced))
                    .symbolRenderingMode(.multicolor)
            }

            // Details row
            HStack(spacing: 16) {
                Label("H: \(Int(data.highTemp))°", systemImage: "thermometer.high")
                    .font(QTheme.weatherDetail)
                Label("L: \(Int(data.lowTemp))°", systemImage: "thermometer.low")
                    .font(QTheme.weatherDetail)
                Label("\(Int(data.humidity))%", systemImage: "humidity")
                    .font(QTheme.weatherDetail)
                Label("\(Int(data.windSpeed)) mph", systemImage: "wind")
                    .font(QTheme.weatherDetail)
            }
            .foregroundStyle(QTheme.quarkSecondary)

            // 5-day forecast
            if !data.forecast.isEmpty {
                Divider()

                HStack(spacing: 0) {
                    ForEach(Array(data.forecast.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 4) {
                            Text(dayLabel(day.date))
                                .font(QTheme.timestamp)
                                .foregroundStyle(QTheme.quarkSecondary)
                            Image(systemName: WeatherData.symbolForCode(day.weatherCode))
                                .font(QTheme.caption)
                                .symbolRenderingMode(.multicolor)
                            Text("\(Int(day.highTemp))°")
                                .font(QTheme.timestamp)
                            Text("\(Int(day.lowTemp))°")
                                .font(QTheme.timestamp)
                                .foregroundStyle(QTheme.quarkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(QTheme.quarkTeal.opacity(0.1)), in: .rect(cornerRadius: QTheme.cornerRadiusCard))
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
