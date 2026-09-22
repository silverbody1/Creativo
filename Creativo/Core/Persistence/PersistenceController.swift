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
            ProjectEquipmentAssignment.self
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
            logger.error("Ouverture du store impossible, bascule en mémoire: \(String(describing: error))")
            return makeFallbackContainer()
        }
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
