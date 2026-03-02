import Foundation
import FoundationModels
import Observation
import SwiftUI

@Observable
@MainActor
final class MessageCoordinator {
    var pipelineSteps: [PipelineStep] = []
    var isRunningPipeline: Bool = false

    private let webSearchProcessor = WebSearchProcessor()
    private let calculationProcessor = CalculationProcessor()
    private let geoSearchProcessor = GeoSearchProcessor()
    private let actionProcessor = ActionProcessor()

    func process(
        userMessage: String,
        recentExchanges: [(role: String, content: String)],
        userProfile: UserProfile?,
        lastAssistantMessage: String? = nil
    ) async -> PipelineOutput {
        pipelineSteps = []
        isRunningPipeline = true
        defer { isRunningPipeline = false }

        // Step 1: Classify + Expand
        addStep(category: .analysis, label: "Analyzing question...")

        let classification = await classify(
            message: userMessage,
            recentExchanges: recentExchanges
        )

        completeStep()

        // Step 2: Route
        if classification.intent == .passthrough {
            return PipelineOutput(
                enrichedPrompt: userMessage,
                citations: [],
                actions: [],
                pipelineSteps: pipelineSteps
            )
        }

        // Step 3: Domain processing
        let stepInfo = domainStepInfo(for: classification.intent)
        addStep(category: stepInfo.category, label: stepInfo.label)

        let domainResult = await dispatch(
            intent: classification.intent,
            query: classification.expandedQuery,
            userProfile: userProfile
        )

        if domainResult.enrichmentText.isEmpty {
            failStep()
        } else {
            completeStep()
        }

        // Step 4: Build enriched prompt
        addStep(category: .composition, label: "Putting it all together...")

        let enrichedPrompt = buildEnrichedPrompt(
            originalMessage: userMessage,
            intent: classification.intent,
            domainResult: domainResult,
            lastAssistantMessage: lastAssistantMessage
        )

        completeStep()

        return PipelineOutput(
            enrichedPrompt: enrichedPrompt,
            citations: domainResult.citations,
            actions: domainResult.actions,
            pipelineSteps: pipelineSteps
        )
    }

    // MARK: - Classification

    private func classify(
        message: String,
        recentExchanges: [(role: String, content: String)]
    ) async -> ClassificationResult {
        do {
            var contextLines: [String] = []
            for exchange in recentExchanges.suffix(4) {
                // Truncate long messages to save classifier context tokens
                let content = exchange.content.count > 300
                    ? String(exchange.content.prefix(300)) + "..."
                    : exchange.content
                contextLines.append("\(exchange.role): \(content)")
            }
            let contextBlock = contextLines.isEmpty
                ? ""
                : "Recent conversation:\n\(contextLines.joined(separator: "\n"))\n\n"

            let instructions = """
            Classify the user's message into one category. Rewrite it as a self-contained query.

            Categories:
            - action: User wants to DO something with a specific place — get directions, \
            call, open website, navigate. Keywords: "directions", "navigate", "call", \
            "phone", "website", "open", "take me to", "drive to", "how do I get to"
            - geo_search: ANY question about finding places, stores, restaurants, shops, services, \
            or locations. Keywords: "nearby", "closest", "near me", "where is", "find a", place names.
            - calculation: math, percentages, unit conversions, arithmetic
            - factual_lookup: facts, news, weather, how-to, history, science, explanations
            - passthrough: greetings, chitchat, opinions, creative writing

            Choose action if the user wants to ACT on a specific place (directions, call, website). \
            Choose geo_search if the user wants to FIND or LOCATE places. \
            Rewrite the query to be self-contained using conversation context. \
            If passthrough, copy as-is.
            """

            let session = LanguageModelSession(instructions: instructions)
            let prompt = "\(contextBlock)User message: \(message)"

            let response = try await session.respond(
                to: prompt,
                generating: ClassifierOutput.self
            )

            let output = response.content
            let intent = MessageIntent(rawValue: output.intent) ?? .passthrough

            return ClassificationResult(
                expandedQuery: output.expandedQuery,
                intent: intent
            )
        } catch {
            return ClassificationResult(
                expandedQuery: message,
                intent: .passthrough
            )
        }
    }

    // MARK: - Domain Dispatch

    private func dispatch(
        intent: MessageIntent,
        query: String,
        userProfile: UserProfile?
    ) async -> DomainResult {
        switch intent {
        case .factualLookup:
            return await webSearchProcessor.process(query: query)
        case .calculation:
            return await calculationProcessor.process(query: query)
        case .geoSearch:
            return await geoSearchProcessor.process(
                query: query,
                userLocation: userProfile?.location
            )
        case .action:
            return await actionProcessor.process(
                query: query,
                userLocation: userProfile?.location
            )
        case .passthrough:
            return .empty
        }
    }

    // MARK: - Prompt Enrichment

    private func buildEnrichedPrompt(
        originalMessage: String,
        intent: MessageIntent,
        domainResult: DomainResult,
        lastAssistantMessage: String?
    ) -> String {
        guard !domainResult.enrichmentText.isEmpty else {
            return originalMessage
        }

        let header: String
        switch intent {
        case .factualLookup:
            header = "Supplementary information from the web:"
        case .calculation:
            header = "Calculation result:"
        case .geoSearch:
            header = "Relevant places found:"
        case .action:
            header = "Action information:"
        case .passthrough:
            return originalMessage
        }

        // Include brief conversation context so the model can reconcile
        // the enrichment with what was previously discussed
        var contextNote = ""
        if let lastResponse = lastAssistantMessage, !lastResponse.isEmpty {
            let truncated = lastResponse.count > 200
                ? String(lastResponse.prefix(200)) + "..."
                : lastResponse
            contextNote = "\nConversation context (your previous response): \(truncated)\n"
        }

        let footer: String
        if intent == .action {
            footer = "The action above has ALREADY been performed successfully. Confirm what was done in a brief, friendly message. Include the place details. Do NOT say you can't do it — it's already done."
        } else {
            footer = "Prioritize our conversation history. Use the supplementary info above only where it adds value. Answer naturally."
        }

        return """
        \(originalMessage)
        \(contextNote)
        ---
        \(header)
        \(domainResult.enrichmentText)
        ---
        \(footer)
        """
    }

    // MARK: - Step Tracking

    private func addStep(category: StepCategory, label: String) {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            pipelineSteps.append(PipelineStep(category: category, label: label))
        }
    }

    private func completeStep() {
        guard !pipelineSteps.isEmpty else { return }
        let lastIndex = pipelineSteps.count - 1
        withAnimation(.spring(duration: 0.3)) {
            pipelineSteps[lastIndex].status = .completed
            pipelineSteps[lastIndex].completedAt = Date()
        }
    }

    private func failStep() {
        guard !pipelineSteps.isEmpty else { return }
        let lastIndex = pipelineSteps.count - 1
        withAnimation(.spring(duration: 0.3)) {
            pipelineSteps[lastIndex].status = .failed
            pipelineSteps[lastIndex].completedAt = Date()
        }
    }

    private func domainStepInfo(for intent: MessageIntent) -> (category: StepCategory, label: String) {
        switch intent {
        case .factualLookup: return (.webSearch, "Searching the web...")
        case .calculation: return (.calculation, "Doing the math...")
        case .geoSearch: return (.geoSearch, "Consulting the map...")
        case .action: return (.action, "Preparing action...")
        case .passthrough: return (.analysis, "Processing...")
        }
    }
}
