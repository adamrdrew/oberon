import SwiftUI

struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .offset(y: reduceMotion ? 0 : dotOffset(for: index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 18))

            Spacer()
        }
        .padding(.horizontal, 12)
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
        }
        .opacity(reduceMotion ? pulseOpacity : 1)
    }

    private func dotOffset(for index: Int) -> CGFloat {
        let offset = CGFloat(index) * 0.4
        return sin(phase + offset) * 4
    }

    @State private var pulseOpacity: Double = 1.0
}
