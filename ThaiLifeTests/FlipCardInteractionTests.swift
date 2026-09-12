@testable import ThaiLife
import XCTest

final class FlipCardInteractionTests: XCTestCase {
    func testBlankTapHasDedicatedFlipAction() {
        XCTAssertEqual(FlipCardGestureAction.flip, .flip)
    }

    func testHorizontalSwipeDispatchRespectsNavigationBoundaries() {
        XCTAssertEqual(
            FlipCardGestureAction.resolve(translation: CGSize(width: -100, height: 0), canGoPrevious: true, canGoNext: true),
            .next
        )
        XCTAssertEqual(
            FlipCardGestureAction.resolve(translation: CGSize(width: 100, height: 0), canGoPrevious: true, canGoNext: true),
            .previous
        )
        XCTAssertEqual(
            FlipCardGestureAction.resolve(translation: CGSize(width: -100, height: 0), canGoPrevious: true, canGoNext: false),
            .reset
        )
    }
}
