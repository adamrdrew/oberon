import SwiftUI

struct ContactCardView: View {
    let data: ContactData

    var body: some View {
        HStack(spacing: 12) {
            // Initials avatar
            Text(data.initials)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.blue.gradient, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.name)
                    .font(.headline)

                if let phone = data.phoneNumber {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let email = data.email {
                    Label(email, systemImage: "envelope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .glassEffect(.regular.tint(.green.opacity(0.15)), in: .rect(cornerRadius: 16))
    }
}
