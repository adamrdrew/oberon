import SwiftUI

struct PipelineStatusView: View {
    let steps: [PipelineStep]
    var isCompact: Bool = false

    @State private var appearedStepIDs: Set<UUID> = []

    private var dominantColor: Color {
        steps.last.map { categoryColor($0.category) } ?? .gray
    }

    private func categoryColor(_ category: StepCategory) -> Color {
        switch category {
        case .webSearch: return QTheme.quarkTeal
        case .calculation: return QTheme.quarkAccent
        case .geoSearch: return QTheme.quarkNavy
        case .weather: return QTheme.quarkTeal.opacity(0.7)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 4 : 8) {
            ForEach(steps) { step in
                stepRow(step)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isCompact ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.tint(dominantColor.opacity(0.15)),
            in: .rect(cornerRadius: QTheme.cornerRadiusCard)
        )
        .padding(.horizontal, isCompact ? 0 : QTheme.contentPadding)
    }

    @ViewBuilder
    private func stepRow(_ step: PipelineStep) -> some View {
        HStack(spacing: 8) {
            // Left color band
            RoundedRectangle(cornerRadius: 1.5)
                .fill(categoryColor(step.category))
                .frame(width: 3, height: isCompact ? 16 : 20)
                .opacity(step.status == .active && appearedStepIDs.contains(step.id) ? 1 : 0.6)
                .animation(
                    step.status == .active
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: appearedStepIDs.contains(step.id)
                )

            Text(step.label)
                .font(isCompact ? QTheme.pipelineLabelCompact : QTheme.pipelineLabel)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(stepTextColor(step))

            Spacer()

            if step.status == .completed {
                Text("OK")
                    .font(QTheme.timestamp)
                    .foregroundStyle(categoryColor(step.category))
            } else if step.status == .failed {
                Text("---")
                    .font(QTheme.timestamp)
                    .foregroundStyle(QTheme.quarkSecondary)
            }
        }
        .onAppear { appearedStepIDs.insert(step.id) }
        .onDisappear { appearedStepIDs.remove(step.id) }
    }

    private func stepTextColor(_ step: PipelineStep) -> Color {
        switch step.status {
        case .active: return QTheme.quarkPrimary.opacity(0.8)
        case .completed: return QTheme.quarkSecondary
        case .failed: return QTheme.quarkSecondary
        }
    }
}
