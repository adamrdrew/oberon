import Foundation
import FoundationModels

struct UnitConversionProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        do {
            let session = LanguageModelSession(
                instructions: "Extract the numeric value, source unit, and target unit from the user's conversion request."
            )

            let response = try await session.respond(
                to: query,
                generating: UnitConversionExtraction.self
            )

            let extraction = response.content
            guard let value = Double(extraction.value) else { return .empty }

            let fromUnit = extraction.fromUnit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let toUnit = extraction.toUnit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Try Foundation Measurement conversion
            if let fromDimension = dimension(for: fromUnit),
               let toDimension = dimension(for: toUnit),
               type(of: fromDimension) == type(of: toDimension) {
                let measurement = Measurement(value: value, unit: fromDimension)
                let converted = measurement.converted(to: toDimension)

                let formatter = MeasurementFormatter()
                formatter.unitOptions = .providedUnit
                formatter.numberFormatter.maximumFractionDigits = 4

                let fromFormatted = formatter.string(from: measurement)
                let toFormatted = formatter.string(from: converted)

                let richContent: [RichContent] = [
                    .unitConversion(UnitConversionData(
                        fromValue: value,
                        fromUnit: fromFormatted,
                        toValue: converted.value,
                        toUnit: toFormatted
                    ))
                ]

                return DomainResult(
                    enrichmentText: "\(fromFormatted) = \(toFormatted)",
                    citations: [],
                    actions: [],
                    richContent: richContent,
                    suggestedReplies: SuggestedReply.forUnitConversion()
                )
            }

            return .empty
        } catch {
            return .empty
        }
    }

    // MARK: - Unit Mapping

    private func dimension(for unit: String) -> Dimension? {
        // Length
        switch unit {
        case "miles", "mile", "mi": return UnitLength.miles
        case "kilometers", "kilometer", "km": return UnitLength.kilometers
        case "meters", "meter", "m": return UnitLength.meters
        case "feet", "foot", "ft": return UnitLength.feet
        case "inches", "inch", "in": return UnitLength.inches
        case "yards", "yard", "yd": return UnitLength.yards
        case "centimeters", "centimeter", "cm": return UnitLength.centimeters
        case "millimeters", "millimeter", "mm": return UnitLength.millimeters
        // Mass
        case "pounds", "pound", "lbs", "lb": return UnitMass.pounds
        case "kilograms", "kilogram", "kg": return UnitMass.kilograms
        case "ounces", "ounce", "oz": return UnitMass.ounces
        case "grams", "gram", "g": return UnitMass.grams
        case "stones", "stone", "st": return UnitMass.stones
        // Temperature
        case "celsius", "c": return UnitTemperature.celsius
        case "fahrenheit", "f": return UnitTemperature.fahrenheit
        case "kelvin", "k": return UnitTemperature.kelvin
        // Volume
        case "liters", "liter", "l": return UnitVolume.liters
        case "gallons", "gallon", "gal": return UnitVolume.gallons
        case "cups", "cup": return UnitVolume.cups
        case "tablespoons", "tablespoon", "tbsp": return UnitVolume.tablespoons
        case "teaspoons", "teaspoon", "tsp": return UnitVolume.teaspoons
        case "milliliters", "milliliter", "ml": return UnitVolume.milliliters
        case "fluid ounces", "fluid ounce", "fl oz": return UnitVolume.fluidOunces
        case "pints", "pint", "pt": return UnitVolume.pints
        case "quarts", "quart", "qt": return UnitVolume.quarts
        // Speed
        case "mph", "miles per hour": return UnitSpeed.milesPerHour
        case "kph", "kmh", "km/h", "kilometers per hour": return UnitSpeed.kilometersPerHour
        case "m/s", "meters per second": return UnitSpeed.metersPerSecond
        case "knots", "knot": return UnitSpeed.knots
        default: return nil
        }
    }
}
