import Foundation
import Testing
@testable import Oberon

struct PipelineStepTests {

    @Test func initSetsDefaults() {
        let step = PipelineStep(category: .webSearch, label: "Searching")
        #expect(step.category == .webSearch)
        #expect(step.label == "Searching")
        #expect(step.status == .active)
        #expect(step.completedAt == nil)
    }

    @Test func stepCategoryIcons() {
        #expect(StepCategory.webSearch.icon == "globe")
        #expect(StepCategory.calculation.icon == "function")
        #expect(StepCategory.geoSearch.icon == "map")
        #expect(StepCategory.weather.icon == "cloud.sun")
        #expect(StepCategory.imageSearch.icon == "photo.on.rectangle.angled")
        #expect(StepCategory.videoSearch.icon == "play.rectangle")
        #expect(StepCategory.urlExtraction.icon == "link")
    }

    @Test func codableRoundTrip() throws {
        let step = PipelineStep(category: .imageSearch, label: "Finding images")
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(PipelineStep.self, from: data)
        #expect(decoded.id == step.id)
        #expect(decoded.category == step.category)
        #expect(decoded.label == step.label)
        #expect(decoded.status == .active)
    }

    @Test func codableWithCompletedStatus() throws {
        var step = PipelineStep(category: .webSearch, label: "Done")
        step.status = .completed
        step.completedAt = Date()
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(PipelineStep.self, from: data)
        #expect(decoded.status == .completed)
        #expect(decoded.completedAt != nil)
    }
}
