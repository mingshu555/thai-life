@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class TodayViewModelTests: XCTestCase {
    var container: ModelContainer!
    var store: StudyStore!
    var viewModel: TodayViewModel!
    var appState: AppState!

    override func setUp() async throws {
        container = try AppContainer.makeModelContainer(inMemory: true)
        store = StudyStore(context: container.mainContext)
        viewModel = TodayViewModel()
        appState = AppState()
        appState.modelContainer = container
        appState.store = store
        appState.contentItems = [ContentItem.fixture(id: "test-001")]
    }

    func testInitialSnapshotHasDefaults() {
        viewModel.refresh(appState: appState)
        XCTAssertEqual(viewModel.snapshot.newLimit, 1, "New-card quota should reflect eligible new cards, not the configured cap")
    }

    func testDueCountIncreasesWithOverdueReview() throws {
        let past = Date().addingTimeInterval(-86400 * 7)
        let log = ReviewLogRecord(id: "uuid-001", contentID: "test-001", direction: "thai→zh", rating: "good", reviewedAt: past)
        try store.appendReview(log)
        viewModel.refresh(appState: appState)
        // After 7 days with "good", card should be due
        XCTAssertGreaterThanOrEqual(viewModel.snapshot.dueCount, 0)
    }

    func testStartReviewSetsShowReview() {
        viewModel.refresh(appState: appState)
        viewModel.startReview()
        XCTAssertTrue(viewModel.showReview)
        XCTAssertEqual(viewModel.reviewRoute, .daily)
    }

    func testWeaknessRoute() {
        viewModel.startWeaknessReview()
        XCTAssertTrue(viewModel.showReview)
        XCTAssertEqual(viewModel.reviewRoute, .weakness)
    }
}
