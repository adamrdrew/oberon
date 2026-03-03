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
                            .font(OTheme.label)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.label)
                                .font(OTheme.label)

                            if !action.subtitle.isEmpty {
                                Text(action.subtitle)
                                    .font(OTheme.caption)
                                    .foregroundStyle(OTheme.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(OTheme.caption)
                            .foregroundStyle(OTheme.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            }
        }
    }
}
