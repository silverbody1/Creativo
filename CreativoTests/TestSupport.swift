import Foundation
import SwiftData
import XCTest
@testable import Creativo

/// Base class giving every test its own empty in-memory store.
///
/// Nothing is shared between tests: each one gets a fresh container, so a test
/// can never be affected by what another one wrote.
class CreativoTestCase: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try PersistenceController.makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    /// Fetches every object of a kind currently in the store.
    func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    func countOf<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try fetchAll(type).count
    }
}
