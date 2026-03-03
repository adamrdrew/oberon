import SwiftUI

struct PipelineStatusView: View {
    let steps: [PipelineStep]
    var isCompact: Bool = false

    @State private var appearedStepIDs: Set<UUID> = []

    private var dominantColor: Color {
        steps.last?.category.color ?? .gray
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: isCompact ? 4 : 8) {
                ForEach(steps) { step in
                    stepRow(step)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isCompact ? 8 : 12)
            .glassEffect(
                .regular.tint(dominantColor.opacity(0.15)),
                in: .rect(cornerRadius: 16)
            )

            Spacer()
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func stepRow(_ step: PipelineStep) -> some View {
        HStack(spacing: 8) {
            Image(systemName: step.category.icon)
                .font(isCompact ? .caption : .subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(stepColor(step))
                .symbolEffect(
                    .pulse.wholeSymbol,
                    isActive: step.status == .active && appearedStepIDs.contains(step.id)
                )
                .frame(width: isCompact ? 16 : 20, height: isCompact ? 16 : 20)

            Text(step.label)
                .font(isCompact ? .caption : .subheadline)
                .fontWeight(.medium)
                .foregroundStyle(stepTextColor(step))

            Spacer()

            if step.status == .completed {
                Image(systemName: "checkmark")
                    .font(isCompact ? .caption2 : .caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(step.category.color)
            } else if step.status == .failed {
                Text("(skipped)")
                    .font(isCompact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { appearedStepIDs.insert(step.id) }
        .onDisappear { appearedStepIDs.remove(step.id) }
    }

    private func stepColor(_ step: PipelineStep) -> Color {
        switch step.status {
        case .active: return step.category.color
        case .completed: return step.category.color.opacity(0.5)
        case .failed: return .secondary
        }
    }

    private func stepTextColor(_ step: PipelineStep) -> Color {
        switch step.status {
        case .active: return .primary.opacity(0.8)
        case .completed: return .secondary
        case .failed: return .secondary
        }
    }
}
