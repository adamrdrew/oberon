import SwiftUI

struct WeatherCardView: View {
    let data: WeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Location + current temp
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.locationName)
                        .font(.headline)
                    Text("\(Int(data.temperature))°\(data.temperatureUnit)")
                        .font(.system(size: 36, weight: .thin))
                }

                Spacer()

                Image(systemName: data.weatherSymbol)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.multicolor)
            }

            // Details row
            HStack(spacing: 16) {
                Label("H: \(Int(data.highTemp))°", systemImage: "thermometer.high")
                    .font(.caption)
                Label("L: \(Int(data.lowTemp))°", systemImage: "thermometer.low")
                    .font(.caption)
                Label("\(Int(data.humidity))%", systemImage: "humidity")
                    .font(.caption)
                Label("\(Int(data.windSpeed)) mph", systemImage: "wind")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            // 5-day forecast
            if !data.forecast.isEmpty {
                Divider()

                HStack(spacing: 0) {
                    ForEach(Array(data.forecast.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 4) {
                            Text(dayLabel(day.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: WeatherData.symbolForCode(day.weatherCode))
                                .font(.caption)
                                .symbolRenderingMode(.multicolor)
                            Text("\(Int(day.highTemp))°")
                                .font(.caption2)
                            Text("\(Int(day.lowTemp))°")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.blue.opacity(0.15)), in: .rect(cornerRadius: 16))
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
