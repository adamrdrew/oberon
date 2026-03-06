import SwiftUI

struct ModelOptionRow: View {
    let type: ModelBackendType
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(type.displayName)
                            .font(OTheme.body)
                            .foregroundStyle(OTheme.primary)

                        if type.isBeta {
                            Text("Beta")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(OTheme.accent.opacity(0.8), in: Capsule())
                        }
                    }

                    Text(type.subtitle)
                        .font(OTheme.pipelineLabel)
                        .foregroundStyle(OTheme.tertiary)
                }

                Spacer()

                if !isAvailable {
                    Text("Unavailable")
                        .font(OTheme.pipelineLabel)
                        .foregroundStyle(OTheme.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(OTheme.caption.bold())
                        .foregroundStyle(OTheme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.5)
    }
}
