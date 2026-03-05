import Foundation
import Testing
@testable import Oberon

struct ToolResultStoreTests {

    @Test func addAndTakeCitations() async {
        let store = ToolResultStore()
        let citations = [Citation(title: "A", url: "https://a.com")]
        await store.addCitations(citations)
        let results = await store.takeAll()
        #expect(results.citations.count == 1)
        #expect(results.citations[0].title == "A")
    }

    @Test func takeAllClearsState() async {
        let store = ToolResultStore()
        await store.addCitations([Citation(title: "X", url: "https://x.com")])
        await store.addSuggestedReplies([SuggestedReply(text: "More")])
        _ = await store.takeAll()
        let second = await store.takeAll()
        #expect(second.citations.isEmpty)
        #expect(second.suggestedReplies.isEmpty)
    }

    @Test func toolPerformedTracking() async {
        let store = ToolResultStore()
        let performed = await store.hasToolPerformed("web_search")
        #expect(!performed)
        await store.markToolPerformed("web_search")
        let afterMark = await store.hasToolPerformed("web_search")
        #expect(afterMark)
    }

    @Test func takeAllResetsToolTracking() async {
        let store = ToolResultStore()
        await store.markToolPerformed("image_search")
        _ = await store.takeAll()
        let afterTake = await store.hasToolPerformed("image_search")
        #expect(!afterTake)
    }

    @Test func pipelineStepLifecycle() async {
        let store = ToolResultStore()
        let step = PipelineStep(category: .webSearch, label: "Searching")
        await store.addPipelineStep(step)
        await store.completePipelineStep(id: step.id)
        let results = await store.takeAll()
        #expect(results.pipelineSteps.count == 1)
        #expect(results.pipelineSteps[0].status == .completed)
        #expect(results.pipelineSteps[0].completedAt != nil)
    }

    @Test func pipelineStepFailure() async {
        let store = ToolResultStore()
        let step = PipelineStep(category: .imageSearch, label: "Searching")
        await store.addPipelineStep(step)
        await store.failPipelineStep(id: step.id)
        let results = await store.takeAll()
        #expect(results.pipelineSteps[0].status == .failed)
    }

    @Test func addRichContentAndActions() async {
        let store = ToolResultStore()
        let action = RichAction(type: .openWebsite, label: "Open", urlString: "https://example.com")
        await store.addActions([action])
        let results = await store.takeAll()
        #expect(results.actions.count == 1)
        #expect(results.actions[0].type == .openWebsite)
    }

    @Test func multipleToolsTrackedIndependently() async {
        let store = ToolResultStore()
        await store.markToolPerformed("web_search")
        await store.markToolPerformed("image_search")
        let hasWeb = await store.hasToolPerformed("web_search")
        let hasImage = await store.hasToolPerformed("image_search")
        let hasVideo = await store.hasToolPerformed("video_search")
        #expect(hasWeb)
        #expect(hasImage)
        #expect(!hasVideo)
    }
}
