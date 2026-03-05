import Foundation
import Observation
import FoundationModels

@Observable
final class AppState {
    var selectedConversation: Conversation?
    var modelAvailability: SystemLanguageModel.Availability = .unavailable(.modelNotReady)
    var showOnboarding = false

    func checkAvailability() {
        let model = SystemLanguageModel.default
        modelAvailability = model.availability
    }

    var isModelAvailable: Bool {
        if case .available = modelAvailability { return true }
        return false
    }

}
