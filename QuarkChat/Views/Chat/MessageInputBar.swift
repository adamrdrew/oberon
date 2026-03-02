import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isGenerating)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .onSubmit {
                    if !isGenerating && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }

            Button {
                if isGenerating {
                    onStop()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isGenerating ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isGenerating)
            }
            .disabled(!isGenerating && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 4)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
