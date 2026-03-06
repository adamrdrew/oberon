import SwiftUI

struct ThinkingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 5) {
                Image(systemName: "brain")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OTheme.accent)
                    .opacity(reduceMotion ? 0.7 : 0.4 + 0.3 * sin(phase * 2))

                Text("Thinking")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(OTheme.tertiary)
            }
            .padding(.leading, OTheme.contentPadding + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
