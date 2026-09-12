import XCTest
@testable import ThaiLife

final class UnitDetailViewTests: XCTestCase {
    func testSelectingListItemBuildsCourseBrowseRouteAtThatItem() {
        let route = UnitDetailView.browserRoute(category: .basics, itemID: "basics-word-003")
        XCTAssertEqual(route, .courseBrowse(category: .basics, startContentID: "basics-word-003"))
    }

    func testThaiTextHitTargetOnlyTriggersAudioPlayback() {
        let target = UnitDetailRowHitTargetResolver.target(for: .thaiText)
        XCTAssertEqual(target, .playAudio, "Tapping Thai text must only trigger audio playback")
    }

    func testRowHitAreasExcludeHiddenRomanization() {
        XCTAssertEqual(
            Set(UnitDetailRowHitArea.allCases),
            [.thaiText, .meaning, .example, .metadata, .rowBackground, .favoriteButton]
        )
    }

    func testMeaningExampleMetadataWhitespaceHitTargetsTriggerBrowseNavigation() {
        let browseAreas: [UnitDetailRowHitArea] = [.meaning, .example, .metadata, .rowBackground]
        for area in browseAreas {
            let target = UnitDetailRowHitTargetResolver.target(for: area)
            XCTAssertEqual(target, .browse, "Tapping \(area) must trigger course browse navigation")
        }
    }

    func testFavoriteButtonHitTargetOnlyTriggersFavoriteToggle() {
        let target = UnitDetailRowHitTargetResolver.target(for: .favoriteButton)
        XCTAssertEqual(target, .toggleFavorite, "Tapping favorite button must only trigger favorite toggle")
    }

    func testRowHitTargetSeparationForThaiTextFavoriteAndBrowseArea() {
        let item = ContentItem.fixture(id: "basics-word-001", category: .basics)

        var audioPlayed = false
        var favoriteToggled = false
        var browseSelectedID: String?

        let dispatchAction: (UnitDetailRowHitArea) -> Void = { area in
            switch UnitDetailRowHitTargetResolver.target(for: area) {
            case .playAudio:
                audioPlayed = true
            case .toggleFavorite:
                favoriteToggled = true
            case .browse:
                browseSelectedID = item.id
            }
        }

        // 1. Thai text action: only plays audio
        dispatchAction(.thaiText)
        XCTAssertTrue(audioPlayed)
        XCTAssertFalse(favoriteToggled)
        XCTAssertNil(browseSelectedID, "Tapping Thai text must not navigate to course browse")

        // 2. Favorite button action: only toggles favorite
        audioPlayed = false
        dispatchAction(.favoriteButton)
        XCTAssertFalse(audioPlayed)
        XCTAssertTrue(favoriteToggled)
        XCTAssertNil(browseSelectedID, "Tapping favorite button must not navigate to course browse")

        // 3. Meaning/Example/Metadata/Background actions: navigate to course browse for current item
        favoriteToggled = false
        let nonThaiNonFavAreas: [UnitDetailRowHitArea] = [.meaning, .example, .metadata, .rowBackground]
        for area in nonThaiNonFavAreas {
            audioPlayed = false
            favoriteToggled = false
            browseSelectedID = nil
            dispatchAction(area)
            XCTAssertFalse(audioPlayed, "Tapping \(area) must not play audio")
            XCTAssertFalse(favoriteToggled, "Tapping \(area) must not toggle favorite")
            XCTAssertEqual(browseSelectedID, item.id, "Tapping \(area) must navigate to course browse")
        }
    }
}
