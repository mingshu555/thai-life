@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class ProgressViewModelTests: XCTestCase {
    var container: ModelContainer!
    var store: StudyStore!
    var viewModel: ProgressViewModel!
    var appState: AppState!

    override func setUp() async throws {
        container = try AppContainer.makeModelContainer(inMemory: true)
        store = StudyStore(context: container.mainContext)
        viewModel = ProgressViewModel()
        appState = AppState()
        appState.modelContainer = container
        appState.store = store
        appState.contentItems = (0..<ContentCategory.allCases.count).map { i in
            ContentItem.fixture(id: "item-\(i)", category: ContentCategory.allCases[i])
        }
    }

    func testInitialRetentionIs90() {
        viewModel.refresh(appState: appState)
        XCTAssertEqual(viewModel.snapshot.targetRetention, 0.90)
    }

    func testAllCategoriesPresent() {
        viewModel.refresh(appState: appState)
        XCTAssertEqual(viewModel.snapshot.categoryMastery.count, ContentCategory.allCases.count)
    }

    func testRecallIsZeroWithNoLogs() {
        viewModel.refresh(appState: appState)
        XCTAssertEqual(viewModel.snapshot.historicalCorrectRate, 0.0)
    }

    func testRecallWithOnlyGoodRatings() throws {
        try store.appendReview(ReviewLogRecord(id: "u1", contentID: "item-0", direction: "thai→zh", rating: "good"))
        try store.appendReview(ReviewLogRecord(id: "u2", contentID: "item-1", direction: "thai→zh", rating: "easy"))
        viewModel.refresh(appState: appState)
        XCTAssertEqual(viewModel.snapshot.historicalCorrectRate, 1.0)
    }

    func testDailyLoadIs30Days() {
        viewModel.refresh(appState: appState)
        XCTAssertEqual(viewModel.snapshot.dailyLoad.count, 30)
    }
}

extension ProgressViewModelTests {
    func testProgressSeparatesHistoricalCorrectRateFromEstimatedRecall() throws {
        let now = Date()
        try store.appendReview(ReviewLogRecord(
            id: "good-review",
            contentID: "item-0",
            direction: "thai→zh",
            rating: "good",
            reviewedAt: now.addingTimeInterval(-86400)
        ))
        try store.appendReview(ReviewLogRecord(
            id: "again-review",
            contentID: "item-1",
            direction: "thai→zh",
            rating: "again",
            reviewedAt: now.addingTimeInterval(-86400)
        ))

        viewModel.refresh(appState: appState)

        XCTAssertEqual(viewModel.snapshot.historicalCorrectRate, 0.5, accuracy: 0.0001)
        XCTAssertGreaterThan(viewModel.snapshot.estimatedRecall, 0)
        XCTAssertLessThanOrEqual(viewModel.snapshot.estimatedRecall, 1)
    }

    func testEstimatedRecallExcludesNewCards() {
        viewModel.refresh(appState: appState)

        XCTAssertEqual(viewModel.snapshot.estimatedRecall, 0)
    }
}
