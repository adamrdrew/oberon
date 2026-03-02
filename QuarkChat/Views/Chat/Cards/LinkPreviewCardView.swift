import SwiftUI

struct LinkPreviewCardView: View {
    let data: LinkPreviewData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(data.domain)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(data.title)
                .font(.headline)
                .lineLimit(2)

            if let description = data.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.blue.opacity(0.15)), in: .rect(cornerRadius: 16))
    }
}
