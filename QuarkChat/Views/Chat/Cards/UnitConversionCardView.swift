import SwiftUI

struct UnitConversionCardView: View {
    let data: UnitConversionData

    var body: some View {
        HStack(spacing: 12) {
            // From
            VStack(spacing: 2) {
                Text(formatValue(data.fromValue))
                    .font(.title2.weight(.medium))
                Text(data.fromUnit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.purple)

            // To
            VStack(spacing: 2) {
                Text(formatValue(data.toValue))
                    .font(.title2.weight(.medium))
                Text(data.toUnit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .glassEffect(.regular.tint(.purple.opacity(0.15)), in: .rect(cornerRadius: 16))
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e10 {
            return String(format: "%.0f", value)
        }
        let formatted = String(format: "%.4f", value)
        return formatted
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }
}
