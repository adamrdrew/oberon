import Foundation
import Testing
import SwiftData
@testable import Oberon

@MainActor
struct PromptAssemblerTests {

    @Test func buildInstructionsWithNilProfile() {
        let result = PromptAssembler.buildInstructions(userProfile: nil)
        #expect(result.contains("Oberon"))
        #expect(!result.contains("User:"))
        #expect(!result.contains("Location:"))
    }

    @Test func buildInstructionsIncludesDateString() {
        let result = PromptAssembler.buildInstructions(userProfile: nil)
        // Should contain a date string (e.g., "2026")
        let year = Calendar.current.component(.year, from: Date())
        #expect(result.contains(String(year)))
    }

    @Test func buildInstructionsWithProfile() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UserProfile.self, configurations: config)
        let context = ModelContext(container)

        let profile = UserProfile()
        profile.name = "Alice"
        profile.location = "Portland"
        profile.aboutMe = "Loves hiking"
        profile.responsePreference = "Brief"
        context.insert(profile)

        let result = PromptAssembler.buildInstructions(userProfile: profile)
        #expect(result.contains("User: Alice"))
        #expect(result.contains("Location: Portland"))
        #expect(result.contains("About: Loves hiking"))
        #expect(result.contains("Style: Brief"))
    }

    @Test func buildInstructionsSkipsEmptyFields() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UserProfile.self, configurations: config)
        let context = ModelContext(container)

        let profile = UserProfile()
        profile.name = "Bob"
        profile.location = ""
        profile.aboutMe = ""
        profile.responsePreference = ""
        context.insert(profile)

        let result = PromptAssembler.buildInstructions(userProfile: profile)
        #expect(result.contains("User: Bob"))
        #expect(!result.contains("Location:"))
        #expect(!result.contains("About:"))
        #expect(!result.contains("Style:"))
    }
}
