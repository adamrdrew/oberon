import SwiftUI

struct ListCardView: View {
    let data: ListData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.title)
                .font(.headline)

            ForEach(data.items) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(item.isChecked ? .green : .secondary)

                    Text(item.text)
                        .font(.subheadline)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.indigo.opacity(0.15)), in: .rect(cornerRadius: 16))
    }
}
