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

    var unavailableReason: String {
        switch modelAvailability {
        case .available:
            return ""
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is not enabled. Go to Settings > Apple Intelligence & Siri to turn it on."
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.modelNotReady):
            return "The language model is still downloading. Please try again shortly."
        @unknown default:
            return "The language model is unavailable."
        }
    }
}
