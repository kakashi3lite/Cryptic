import XCTest
import SwiftData
@testable import Cryptic

final class ContextSavingTests: XCTestCase {
    func testScheduleSavePersistsDraft() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Draft.self, configurations: config)
        let context = ModelContext(container)

        let draft = Draft(text: "hello")
        context.insert(draft)
        ContextSaver.shared.scheduleSave(context, delay: .milliseconds(50))

        // Give the saver time to persist.
        try? await Task.sleep(nanoseconds: 120_000_000)

        // Fetch back and assert exists
        let descriptor = FetchDescriptor<Draft>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "hello")
    }
}

