@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class ThaiLifeSmokeTests: XCTestCase {
    func testInMemoryContainerCanBeCreated() throws {
        XCTAssertNoThrow(try AppContainer.makeModelContainer(inMemory: true))
    }
}
