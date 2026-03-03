import SwiftUI

/// Bold stacked color bands — the retro-future transit motif.
/// Each color is a thick full-width stripe. Used sparingly: empty state + sidebar.
struct StripeAccentView: View {
    var bandHeight: CGFloat = 4
    var spacing: CGFloat = 2
    var colors: [Color] = QTheme.defaultStripeColors

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(colors.indices, id: \.self) { index in
                colors[index]
                    .frame(height: bandHeight)
            }
        }
    }
}
