import Testing
@testable import Oberon

struct TokenBudgetTests {

    @Test func estimateTokensFromText() {
        #expect(TokenBudget.estimateTokens("") == 0)
        #expect(TokenBudget.estimateTokens("abcd") == 1)
        #expect(TokenBudget.estimateTokens("abcdefgh") == 2)
        // 100 chars → 25 tokens
        let hundred = String(repeating: "x", count: 100)
        #expect(TokenBudget.estimateTokens(hundred) == 25)
    }

    @Test func compactionThresholdIsReasonable() {
        // Threshold should be below the context window size
        let contextSize = TokenBudget.foundationModelContextSize
        #expect(TokenBudget.compactionThreshold > 0)
        #expect(TokenBudget.compactionThreshold < contextSize)
    }
}
