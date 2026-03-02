import Foundation
import FoundationModels

@Generable
struct ExtractedExpression {
    @Guide(description: "A mathematical expression using only numbers and operators (+, -, *, /). Example: 230 * 0.15")
    var expression: String
}

struct CalculationProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        do {
            let session = LanguageModelSession(
                instructions: "Extract the math expression from the user's question. Convert percentages to decimals (e.g. '15% of 230' becomes '230 * 0.15'). Use only numbers and +, -, *, / operators."
            )

            let response = try await session.respond(
                to: query,
                generating: ExtractedExpression.self
            )

            let expr = response.content.expression
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let result = evaluateExpression(expr) else {
                return .empty
            }

            let formatted = formatNumber(result)
            return DomainResult(
                enrichmentText: "\(expr) = \(formatted)",
                citations: []
            )
        } catch {
            return .empty
        }
    }

    private func evaluateExpression(_ expr: String) -> Double? {
        // Sanitize: only allow digits, operators, decimal points, spaces, parens
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard expr.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        let nsExpression = NSExpression(format: expr)
        return nsExpression.expressionValue(with: nil, context: nil) as? Double
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        // Up to 6 decimal places, trimming trailing zeros
        let formatted = String(format: "%.6f", value)
        return formatted
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }
}
