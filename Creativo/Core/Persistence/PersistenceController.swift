import Foundation
import SwiftData
import OSLog

/// Builds the app's SwiftData stack.
///
/// CloudKit is explicitly disabled (`cloudKitDatabase: .none`) so that the app
/// launches on a machine with no iCloud account, no entitlement and no
/// developer team. Turning sync on later is a one-line change here plus the
/// entitlement, and the schema is already shaped for it: every property has a
/// default value and no relationship is required.
enum PersistenceController {
    static let logger = Logger(subsystem: "com.creativo.studio", category: "persistence")

    /// Single source of truth for the model graph. Anything added here must
    /// also be added to `SampleData` so previews keep working.
    static var schema: Schema {
        Schema([
            Project.self,
            StoryScene.self,
            Shot.self,
            Person.self,
            ProductionLocation.self,
            EquipmentItem.self,
            BudgetLine.self,
            ShootDay.self,
            ReferenceAsset.self,
            ProjectPersonAssignment.self,
            ProjectEquipmentAssignment.self,
            ScreenplayElement.self,
            YouTubeBlock.self,
            MusicVideoFacet.self
        ])
    }

    /// Container used by the shipping app.
    ///
    /// If the on-disk store cannot be opened — an incompatible store left by a
    /// future build, a full disk — the app falls back to an in-memory store
    /// rather than crashing on launch. The user keeps a usable app and the
    /// failure is logged instead of hidden.
    static func makeAppContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            logger.error("Ouverture du store impossible: \(String(describing: error))")
            // Never delete what could not be read. The unreadable store is moved
            // aside under a timestamped name so it stays recoverable, and the
            // app starts on a fresh one instead of refusing to launch.
            if archiveStore(at: configuration.url),
               let recovered = try? ModelContainer(for: schema, configurations: configuration) {
                logger.notice("Store précédent archivé, nouveau store créé.")
                return recovered
            }
            return makeFallbackContainer()
        }
    }

    /// Renames the store and its sidecar files, keeping the data on disk.
    private static func archiveStore(at url: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return false }

        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        var movedAtLeastOne = false
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: url.path(percentEncoded: false) + suffix)
            guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
            let destination = URL(
                fileURLWithPath: url.path(percentEncoded: false) + ".sauvegarde-\(stamp)" + suffix
            )
            do {
                try fileManager.moveItem(at: source, to: destination)
                movedAtLeastOne = true
            } catch {
                logger.error("Archivage du store impossible: \(String(describing: error))")
                return false
            }
        }
        return movedAtLeastOne
    }

    /// Volatile container for previews, tests and the sample-data mode.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static func makeFallbackContainer() -> ModelContainer {
        do {
            return try makeInMemoryContainer()
        } catch {
            // An in-memory container cannot realistically fail; if it does the
            // schema itself is invalid and there is nothing left to run on.
            fatalError("Schéma SwiftData invalide: \(error)")
        }
    }
}
