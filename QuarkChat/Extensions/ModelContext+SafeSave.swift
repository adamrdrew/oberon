import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.adamdrew.oberon", category: "SwiftData")

extension ModelContext {
    /// Saves the context, logging any errors rather than silently swallowing them.
    func safeSave() {
        do {
            try save()
        } catch {
            logger.error("ModelContext save failed: \(error.localizedDescription)")
        }
    }
}
