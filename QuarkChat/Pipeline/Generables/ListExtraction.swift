import Foundation
import FoundationModels

@Generable
struct ListExtraction {
    @Guide(description: "Name of the list, e.g. 'Grocery List'")
    var listName: String

    @Guide(description: "Comma-separated list items, e.g. 'milk, eggs, bread'")
    var items: String
}
