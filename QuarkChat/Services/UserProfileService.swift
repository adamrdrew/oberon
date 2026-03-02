import Foundation
import Observation
import SwiftData

@Observable
final class UserProfileService {
    var profile: UserProfile?

    @ObservationIgnored
    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        self.modelContext = context
        loadProfile()
    }

    func loadProfile() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<UserProfile>()
        profile = try? context.fetch(descriptor).first
    }

    func ensureProfileExists() {
        guard let context = modelContext else { return }
        if profile == nil {
            let newProfile = UserProfile()
            context.insert(newProfile)
            try? context.save()
            profile = newProfile
        }
    }

    func saveProfile() {
        guard let context = modelContext else { return }
        try? context.save()
    }
}
