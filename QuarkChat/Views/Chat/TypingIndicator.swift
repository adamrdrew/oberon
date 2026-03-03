import SwiftUI

struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * (.pi * 2 / 1.2)

            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(OTheme.teal)
                            .frame(width: 8, height: 8)
                            .offset(y: reduceMotion ? 0 : sin(phase + Double(index) * 0.4) * 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(in: .rect(cornerRadius: OTheme.cornerRadiusBubble))

                Spacer()
            }
            .padding(.horizontal, OTheme.contentPadding)
        }
    }
}
