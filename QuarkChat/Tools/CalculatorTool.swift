import Foundation
import FoundationModels

struct CalculatorTool: Tool {
    let name = "calculator"
    let description = "Evaluate a math expression. Use for any arithmetic, percentages, or numeric calculations."

    @Generable
    struct Arguments {
        @Guide(description: "A mathematical expression using numbers and operators (+, -, *, /, parentheses). Convert percentages to decimals first, e.g. '15% of 230' becomes '230 * 0.15'.")
        var expression: String
    }

    func call(arguments: Arguments) async throws -> String {
        let step = PipelineStep(category: .calculation, label: "Calculating")
        await ToolResultStore.shared.addPipelineStep(step)

        let expr = arguments.expression
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Sanitize: only allow digits, operators, decimal points, spaces, parens
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard expr.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "Invalid expression: '\(expr)'. Use only numbers and +, -, *, / operators."
        }

        guard let result = evaluateExpression(expr) else {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "Could not evaluate '\(expr)'. Check the syntax."
        }

        let formatted = formatNumber(result)
        await ToolResultStore.shared.completePipelineStep(id: step.id)

        return "\(expr) = \(formatted)"
    }

    private func evaluateExpression(_ expr: String) -> Double? {
        let nsExpression = NSExpression(format: expr)
        return nsExpression.expressionValue(with: nil, context: nil) as? Double
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        let formatted = String(format: "%.6f", value)
        return formatted
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }
}
