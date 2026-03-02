import SwiftUI

struct TranslationCardView: View {
    let data: TranslationData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Source
            VStack(alignment: .leading, spacing: 2) {
                Text(data.sourceLanguage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(data.sourceText)
                    .font(.body)
            }

            // Arrow separator
            HStack {
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Target
            VStack(alignment: .leading, spacing: 2) {
                Text(data.targetLanguage)
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text(data.translatedText)
                    .font(.body.weight(.medium))
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.teal.opacity(0.15)), in: .rect(cornerRadius: 16))
    }
}
