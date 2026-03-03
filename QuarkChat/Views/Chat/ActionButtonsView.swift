import SwiftUI

struct ActionButtonsView: View {
    let actions: [RichAction]
    var onExecute: (RichAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(actions) { action in
                Button {
                    onExecute(action)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.icon)
                            .font(QTheme.label)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.label)
                                .font(QTheme.label)

                            if !action.subtitle.isEmpty {
                                Text(action.subtitle)
                                    .font(QTheme.caption)
                                    .foregroundStyle(QTheme.quarkSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(QTheme.caption)
                            .foregroundStyle(QTheme.quarkTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            }
        }
    }
}
