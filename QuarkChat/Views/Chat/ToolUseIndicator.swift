import SwiftUI

struct ToolUseIndicator: View {
    let toolName: String

    @State private var appeared = false

    private var displayInfo: (icon: String, label: String, tint: Color) {
        switch toolName {
        case "web_search":
            return ("globe", "Searching the web...", .blue)
        case "current_datetime":
            return ("clock", "Checking the time...", .purple)
        default:
            return ("gearshape", "Working...", .orange)
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: displayInfo.icon)
                    .font(.body.weight(.semibold))
                    .symbolEffect(.pulse.wholeSymbol, isActive: appeared)
                    .foregroundStyle(displayInfo.tint)
                    .frame(width: 24, height: 24)

                Text(displayInfo.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(displayInfo.tint.opacity(0.2)), in: .rect(cornerRadius: 20))

            Spacer()
        }
        .padding(.horizontal, 12)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}
