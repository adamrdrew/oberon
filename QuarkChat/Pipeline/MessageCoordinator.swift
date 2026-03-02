import Foundation
import FoundationModels
import Observation
import SwiftUI

@Observable
@MainActor
final class MessageCoordinator {
    var pipelineSteps: [PipelineStep] = []
    var isRunningPipeline: Bool = false

    // Layer 1 & 3
    private let keywordPreFilter = KeywordPreFilter()
    private let intentSubRouter = IntentSubRouter()

    // Existing processors
    private let webSearchProcessor = WebSearchProcessor()
    private let calculationProcessor = CalculationProcessor()
    private let geoSearchProcessor = GeoSearchProcessor()
    private let actionProcessor = ActionProcessor()

    // New processors
    private let unitConversionProcessor = UnitConversionProcessor()
    private let definitionProcessor = DefinitionProcessor()
    private let appLaunchProcessor = AppLaunchProcessor()
    private let clipboardProcessor = ClipboardProcessor()
    private let weatherProcessor = WeatherProcessor()
    private let summarizationProcessor = SummarizationProcessor()
    private let translationProcessor = TranslationProcessor()
    private let rewritingProcessor = RewritingProcessor()
    private let proofreadingProcessor = ProofreadingProcessor()
    private let reminderProcessor = ReminderProcessor()
    private let timerProcessor = TimerProcessor()
    private let checklistProcessor = ChecklistProcessor()
    private let contactLookupProcessor = ContactLookupProcessor()
    private let composeMessageProcessor = ComposeMessageProcessor()
    private let musicProcessor = MusicProcessor()

    func process(
        userMessage: String,
        recentExchanges: [(role: String, content: String)],
        userProfile: UserProfile?,
        lastAssistantMessage: String? = nil
    ) async -> PipelineOutput {
        pipelineSteps = []
        isRunningPipeline = true
        defer { isRunningPipeline = false }

        // === Layer 1: Keyword Pre-Filter (zero tokens) ===
        let keywordResult = keywordPreFilter.check(userMessage)

        let classification: ClassificationResult

        if let keywordIntent = keywordResult.intent {
            // Keyword matched — skip LLM classifier entirely
            classification = ClassificationResult(
                expandedQuery: keywordResult.expandedQuery ?? userMessage,
                intent: keywordIntent
            )
        } else {
            // === Layer 2: LLM Classifier (8 grouped intents) ===
            addStep(category: .analysis, label: "Analyzing question...")

            let llmClassification = await classify(
                message: userMessage,
                recentExchanges: recentExchanges
            )

            completeStep()

            // === Layer 3: Intent Sub-Router ===
            let specificIntent = intentSubRouter.route(
                groupedIntent: llmClassification.expandedQuery.isEmpty ? "passthrough" : llmClassification.intent.rawValue,
                query: llmClassification.expandedQuery
            )

            classification = ClassificationResult(
                expandedQuery: llmClassification.expandedQuery,
                intent: specificIntent
            )
        }

        // Passthrough → return immediately
        if classification.intent == .passthrough {
            return PipelineOutput(
                enrichedPrompt: userMessage,
                intent: .passthrough,
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: [],
                pipelineSteps: pipelineSteps
            )
        }

        // === Domain Processing ===
        let stepInfo = domainStepInfo(for: classification.intent)
        addStep(category: stepInfo.category, label: stepInfo.label)

        let domainResult = await dispatch(
            intent: classification.intent,
            query: classification.expandedQuery,
            userProfile: userProfile,
            lastAssistantMessage: lastAssistantMessage
        )

        if domainResult.enrichmentText.isEmpty && domainResult.richContent.isEmpty && domainResult.actions.isEmpty {
            failStep()
        } else {
            completeStep()
        }

        // === Enriched Prompt ===
        addStep(category: .composition, label: "Putting it all together...")

        let enrichedPrompt = buildEnrichedPrompt(
            originalMessage: userMessage,
            intent: classification.intent,
            domainResult: domainResult
        )

        completeStep()

        return PipelineOutput(
            enrichedPrompt: enrichedPrompt,
            intent: classification.intent,
            citations: domainResult.citations,
            actions: domainResult.actions,
            richContent: domainResult.richContent,
            suggestedReplies: domainResult.suggestedReplies,
            pipelineSteps: pipelineSteps
        )
    }

    // MARK: - Classification (Layer 2)

    private func classify(
        message: String,
        recentExchanges: [(role: String, content: String)]
    ) async -> ClassificationResult {
        do {
            var contextLines: [String] = []
            for exchange in recentExchanges.suffix(4) {
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
            - place_action: User wants to DO something with a specific place — get directions, \
            call, open website, navigate. Keywords: "directions", "navigate", "call", \
            "phone", "website", "take me to", "drive to"
            - geo_search: Finding places, stores, restaurants, shops, services, locations. \
            Keywords: "nearby", "closest", "near me", "where is", "find a"
            - calculation: math, percentages, arithmetic
            - factual_lookup: facts, news, how-to, history, science, explanations
            - productivity: reminders, timers, countdowns, checklists, to-do lists
            - language: translation, word definitions, word meanings
            - content_processing: summarizing, rewriting, proofreading, paraphrasing
            - passthrough: greetings, chitchat, opinions, creative writing

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

            // Layer 3: sub-route the grouped intent to specific intent
            let specificIntent = intentSubRouter.route(
                groupedIntent: output.intent,
                query: output.expandedQuery
            )

            return ClassificationResult(
                expandedQuery: output.expandedQuery,
                intent: specificIntent
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
        userProfile: UserProfile?,
        lastAssistantMessage: String? = nil
    ) async -> DomainResult {
        switch intent {
        case .factualLookup:
            return await webSearchProcessor.process(query: query)
        case .calculation:
            return await calculationProcessor.process(query: query)
        case .geoSearch:
            return await geoSearchProcessor.process(query: query, userLocation: userProfile?.location)
        case .placeAction:
            return await actionProcessor.process(query: query, userLocation: userProfile?.location)
        case .unitConversion:
            return await unitConversionProcessor.process(query: query)
        case .definition:
            return await definitionProcessor.process(query: query)
        case .appLaunch:
            return await appLaunchProcessor.process(query: query)
        case .clipboard:
            return await clipboardProcessor.process(query: query, lastAssistantMessage: lastAssistantMessage)
        case .weather:
            return await weatherProcessor.process(query: query, userLocation: userProfile?.location)
        case .summarization:
            return await summarizationProcessor.process(query: query)
        case .translation:
            return await translationProcessor.process(query: query)
        case .rewriting:
            return await rewritingProcessor.process(query: query)
        case .proofreading:
            return await proofreadingProcessor.process(query: query)
        case .reminder:
            return await reminderProcessor.process(query: query)
        case .timer:
            return await timerProcessor.process(query: query)
        case .checklist:
            return await checklistProcessor.process(query: query)
        case .contactLookup:
            return await contactLookupProcessor.process(query: query)
        case .composeMessage:
            return await composeMessageProcessor.process(query: query)
        case .playMusic:
            return await musicProcessor.process(query: query)
        case .passthrough:
            return .empty
        }
    }

    // MARK: - Prompt Enrichment

    private func buildEnrichedPrompt(
        originalMessage: String,
        intent: MessageIntent,
        domainResult: DomainResult
    ) -> String {
        guard !domainResult.enrichmentText.isEmpty else {
            return originalMessage
        }

        let header: String
        let footer: String

        switch intent {
        case .factualLookup:
            header = "Web info:"
            footer = "Use the info above to answer naturally."
        case .calculation:
            header = "Calculation result:"
            footer = "Present this result in context."
        case .geoSearch:
            header = "Places found:"
            footer = "Use the info above to answer naturally."
        case .placeAction:
            header = "Action info:"
            footer = "Already done. Confirm briefly with place details."
        case .reminder:
            header = "Reminder created:"
            footer = "Already created. Confirm naturally."
        case .timer:
            header = "Timer set:"
            footer = "Already set. Confirm naturally."
        case .checklist:
            header = "Checklist created:"
            footer = "Already created. Confirm naturally."
        case .translation:
            header = "Translation:"
            footer = "Present the translation naturally."
        case .definition:
            header = "Definition:"
            footer = "Present this definition conversationally."
        case .summarization:
            header = "Summary:"
            footer = "Present this summary cleanly."
        case .rewriting:
            header = "Rewritten text:"
            footer = "Present the rewritten version."
        case .proofreading:
            header = "Proofread result:"
            footer = "Present corrections briefly."
        case .unitConversion:
            header = "Conversion:"
            footer = "Present this result naturally."
        case .weather:
            header = "Weather data:"
            footer = "Answer the weather question using this data."
        case .contactLookup:
            header = "Contact info:"
            footer = "Present the contact info naturally."
        case .composeMessage:
            header = "Message:"
            footer = "Confirm what will be sent."
        case .playMusic:
            header = "Music:"
            footer = "Already playing. Confirm briefly."
        case .appLaunch:
            header = "App launch:"
            footer = "Opening. Confirm briefly."
        case .clipboard:
            header = "Clipboard:"
            footer = "Copied. Confirm briefly."
        case .passthrough:
            return originalMessage
        }

        let cappedEnrichment = TokenBudget.capEnrichment(domainResult.enrichmentText, for: intent)

        return """
        \(originalMessage)

        ---
        \(header)
        \(cappedEnrichment)
        ---
        \(footer)
        """
    }

    // MARK: - Step Tracking

    private func addStep(category: StepCategory, label: String) {
        // No withAnimation here — ChatView's declarative .animation() modifier
        // handles the transition. Using withAnimation from async pipeline code
        // causes constraint recursion on macOS (competing layout passes).
        pipelineSteps.append(PipelineStep(category: category, label: label))
    }

    private func completeStep() {
        guard !pipelineSteps.isEmpty else { return }
        let lastIndex = pipelineSteps.count - 1
        pipelineSteps[lastIndex].status = .completed
        pipelineSteps[lastIndex].completedAt = Date()
    }

    private func failStep() {
        guard !pipelineSteps.isEmpty else { return }
        let lastIndex = pipelineSteps.count - 1
        pipelineSteps[lastIndex].status = .failed
        pipelineSteps[lastIndex].completedAt = Date()
    }

    private func domainStepInfo(for intent: MessageIntent) -> (category: StepCategory, label: String) {
        switch intent {
        case .factualLookup: return (.webSearch, "Searching the web...")
        case .calculation: return (.calculation, "Doing the math...")
        case .geoSearch: return (.geoSearch, "Consulting the map...")
        case .placeAction: return (.action, "Preparing action...")
        case .reminder: return (.reminder, "Creating reminder...")
        case .timer: return (.timer, "Setting timer...")
        case .checklist: return (.checklist, "Building checklist...")
        case .translation: return (.translation, "Translating...")
        case .definition: return (.definition, "Looking up definition...")
        case .summarization: return (.summarization, "Summarizing...")
        case .rewriting: return (.rewriting, "Rewriting...")
        case .proofreading: return (.proofreading, "Proofreading...")
        case .unitConversion: return (.unitConversion, "Converting units...")
        case .weather: return (.weather, "Checking weather...")
        case .contactLookup: return (.contacts, "Looking up contact...")
        case .composeMessage: return (.messaging, "Composing message...")
        case .playMusic: return (.music, "Finding music...")
        case .appLaunch: return (.appLaunch, "Opening app...")
        case .clipboard: return (.clipboard, "Copying to clipboard...")
        case .passthrough: return (.analysis, "Processing...")
        }
    }
}
