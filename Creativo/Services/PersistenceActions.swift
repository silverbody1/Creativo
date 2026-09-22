import Foundation
import SwiftData
import OSLog

/// Shared save helper for every service.
///
/// SwiftData autosaves, but an explicit save after each user intent makes the
/// behaviour predictable and surfaces store errors in the log instead of
/// silently dropping them.
enum PersistenceActions {
    private static let logger = Logger(subsystem: "com.creativo.studio", category: "store")

    static func save(_ context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.error("Enregistrement impossible: \(String(describing: error))")
        }
    }
}
