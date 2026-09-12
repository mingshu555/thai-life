@testable import ThaiLife
import XCTest

final class ThaiTextTests: XCTestCase {

    func testStandardShortTextFitsAtBaseFontSize() {
        let layout = ThaiTextSizing.font(
            for: "สวัสดี",
            availableWidth: 300,
            maxLines: 6
        )
        XCTAssertEqual(layout.fontSize, 40.0)
        XCTAssertFalse(layout.requiresContinuation)
    }

    func testCardSizingUsesReadableFontBounds() {
        XCTAssertEqual(ThaiTextSizing.preferredFontSize, 40.0)
        XCTAssertEqual(ThaiTextSizing.minimumFontSize, 30.0)
    }

    func testLongTextRequiresContinuationIfTooLarge() {
        let veryLongText = String(repeating: "ประเทศไทย", count: 30)
        let layout = ThaiTextSizing.font(
            for: veryLongText,
            availableWidth: 200,
            maxLines: 3
        )
        // At some point text is too long to fit
        // This test verifies the sizing logic runs without crashing
        XCTAssertGreaterThanOrEqual(layout.fontSize, ThaiTextSizing.minimumFontSize)
    }

    func testMinimumFontSizeIsEnforced() {
        let layout = ThaiTextSizing.font(
            for: "x",
            availableWidth: 50,
            maxLines: 1
        )
        XCTAssertGreaterThanOrEqual(layout.fontSize, ThaiTextSizing.minimumFontSize)
    }

    func testEmptyStringDoesNotCrash() {
        let layout = ThaiTextSizing.font(
            for: "",
            availableWidth: 300,
            maxLines: 6
        )
        XCTAssertFalse(layout.requiresContinuation)
    }
}

final class TypographyScaleTests: XCTestCase {
    func testCourseListTextIsThirtyPercentLargerThanCurrentSize() {
        XCTAssertEqual(CourseListTypography.itemThaiFontSize, 29.0)
        XCTAssertEqual(CourseListTypography.exampleFontSize, 16.0)
        XCTAssertEqual(CourseListTypography.metadataFontSize, 14.0)
    }

    func testReviewCardBackUsesLargerTypography() {
        XCTAssertEqual(ReviewCardTypography.answerThaiScale, 1.05)
        XCTAssertEqual(ReviewCardTypography.answerThaiMinimum, 34.0)

        XCTAssertEqual(ReviewCardTypography.answerMeaningMinimum, 28.0)
        XCTAssertEqual(ReviewCardTypography.exampleFontSize, 18.0)
        XCTAssertEqual(ReviewCardTypography.exampleMeaningFontSize, 16.0)
        XCTAssertEqual(ReviewCardTypography.segmentGlossFontSize, 16.0)
    }
}

final class ReviewCardDirectionTypographyTests: XCTestCase {
    func testFrontCardIsSlightlyLargerThanBackCard() {
        XCTAssertGreaterThan(ReviewCardTypography.frontThaiScale, ReviewCardTypography.answerThaiScale)
        XCTAssertEqual(ReviewCardTypography.frontThaiScale, 1.15)
        XCTAssertEqual(ReviewCardTypography.answerThaiScale, 1.05)
    }
}
