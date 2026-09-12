@testable import ThaiLife
import XCTest

final class LooplessSignageReferenceViewTests: XCTestCase {
    func testCatalogHasDirectLooplessReferenceEntryWithoutSearchOrQuiz() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ThaiLife/Features/Catalog/CatalogView.swift")
        let source = try String(contentsOf: path)
        XCTAssertTrue(source.contains("LooplessSignageReferenceView"))
        XCTAssertTrue(source.contains("泰国招牌无头字对照"))
    }

    func testReferenceResourceIsSinglePageData() throws {
        let reference = try ContentRepository.loadLooplessSignageReference()
        XCTAssertFalse(reference.introductionZhHans.isEmpty)
        XCTAssertGreaterThan(reference.scenes.count, 5)
    }
}
