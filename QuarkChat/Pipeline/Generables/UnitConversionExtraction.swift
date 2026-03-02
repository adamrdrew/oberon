import Foundation
import FoundationModels

@Generable
struct UnitConversionExtraction {
    @Guide(description: "The numeric value to convert, e.g. '5.0'")
    var value: String

    @Guide(description: "The source unit, e.g. 'miles', 'celsius', 'pounds'")
    var fromUnit: String

    @Guide(description: "The target unit, e.g. 'kilometers', 'fahrenheit', 'kilograms'")
    var toUnit: String
}
