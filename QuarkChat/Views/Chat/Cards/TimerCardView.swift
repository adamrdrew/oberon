import SwiftUI

struct TimerCardView: View {
    let data: TimerData

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, data.fireDate.timeIntervalSince(context.date))
            let isComplete = remaining <= 0

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "timer")
                        .font(.title2)
                        .foregroundStyle(isComplete ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.label)
                            .font(.headline)
                        Text(isComplete ? "Complete!" : formatDuration(remaining))
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(isComplete ? .green : .primary)
                    }

                    Spacer()
                }

                if !isComplete {
                    ProgressView(value: 1 - remaining / Double(data.durationSeconds))
                        .tint(.red)
                }
            }
            .padding(14)
            .glassEffect(.regular.tint(.red.opacity(0.15)), in: .rect(cornerRadius: 16))
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
