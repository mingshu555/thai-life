@testable import ThaiLife
import XCTest

final class ThaiMenuTests: XCTestCase {
    func testMenuLoadsCardsWithBreakdowns() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        XCTAssertEqual(reference.cards.count, 50)
        XCTAssertTrue(reference.cards.allSatisfy { !$0.breakdown.combinations.isEmpty && !$0.breakdown.minimal.isEmpty })
    }

    func testMenuBreakdownsReconstructCardNames() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        for card in reference.cards {
            XCTAssertEqual(card.breakdown.combinations.map(\.thai).joined(), card.thai, card.id)
            XCTAssertFalse(card.imageAssetID.isEmpty)
            XCTAssertFalse(card.audioID.isEmpty)
        }
    }

    func testCatalogOffersThaiMenuList() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ThaiLife/Features/Catalog/CatalogView.swift")
        let source = try String(contentsOf: path)
        XCTAssertTrue(source.contains("ThaiMenuListView"))
        XCTAssertTrue(source.contains("泰国常见菜单"))
    }


    func testMenuCardFaceCullingHidesEdgeOnAndBackFaces() {
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 0))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 89.9))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: 90))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: 180))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: -90))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: -89.9))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 0, isBack: false))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: 0, isBack: true))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: 90, isBack: false))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 90, isBack: true))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: 180, isBack: false))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 180, isBack: true))
    }

    func testMenuBrowserUsesIndependentFaceModifiers() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift")
        let source = try String(contentsOf: path)
        XCTAssertTrue(source.contains("ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0, isBack: false)"))
        XCTAssertTrue(source.contains("ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0, isBack: true)"))
        XCTAssertTrue(source.contains(".degrees(isFlipped ? 180 : 0)"))
        XCTAssertTrue(source.contains("transaction.animation = nil"))
        XCTAssertTrue(source.contains("let isVisible = ThaiMenuCardFace.isFacingViewer(at: rotation, isBack: isBack)"))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        XCTAssertFalse(source.contains(".frame(maxHeight: 280)"))
        XCTAssertFalse(source.contains(".id(reference.cards[index].id + (isFlipped"))
        XCTAssertTrue(source.contains("index -= 1; isFlipped = false"))
        XCTAssertTrue(source.contains("index += 1; isFlipped = false"))
    }

    func testMenuThaiTextControlsUseEachCardsOwnBundledAudioID() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let listSource = try String(contentsOf: root.appendingPathComponent("ThaiLife/Features/Catalog/ThaiMenuListView.swift"))
        let browserSource = try String(contentsOf: root.appendingPathComponent("ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift"))

        for source in [listSource, browserSource] {
            XCTAssertTrue(source.contains("@EnvironmentObject private var audioService: AudioPlaybackServiceWrapper"))
            XCTAssertTrue(source.contains("audioService.service.play(audioID: card.audioID, thaiText: card.thai)"))
            XCTAssertTrue(source.contains("Button"))
            XCTAssertTrue(source.contains(".buttonStyle(.plain)"))
        }
        XCTAssertTrue(browserSource.contains("SegmentAudioID.audioID(for: part.thai)"))
        XCTAssertTrue(browserSource.contains("播放拆解词块发音"))
    }

    func testMenuBackUsesTheCourseBreakdownPresentation() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift")
        let source = try String(contentsOf: path)

        XCTAssertTrue(source.contains("Text(\"最小拆解\")"))
        XCTAssertFalse(source.contains("组合拆解"))
        XCTAssertFalse(source.contains("breakdown.combinations"))
        XCTAssertTrue(source.contains("ReviewCardTypography.answerThaiMinimum"))
        XCTAssertTrue(source.contains("ReviewCardTypography.answerMeaningMinimum"))
        XCTAssertTrue(source.contains("ReviewCardTypography.sectionLabelFontSize"))
        XCTAssertTrue(source.contains("ReviewCardTypography.segmentThaiFontSize"))
        XCTAssertTrue(source.contains("ReviewCardTypography.segmentGlossFontSize"))
        XCTAssertFalse(source.contains("Text(\"词语拆解\")"))
        XCTAssertFalse(source.contains("Text(\"更细拆解\")"))
    }

    func testUnbreakableMenuWordsDoNotRepeatOnTheBack() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        let sushi = try XCTUnwrap(reference.cards.first(where: { $0.id == "sushi" }))
        let namTok = try XCTUnwrap(reference.cards.first(where: { $0.id == "nam-tok-moo" }))

        XCTAssertFalse(ThaiMenuBrowserView.shouldShowMinimalBreakdown(for: sushi))
        XCTAssertTrue(ThaiMenuBrowserView.shouldShowMinimalBreakdown(for: namTok))
    }

    func testInitialIndexResolvesMatchingCardAndFallsBackToZero() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        guard let secondCard = reference.cards.dropFirst().first else {
            return XCTFail("Expected at least 2 cards")
        }

        XCTAssertEqual(ThaiMenuBrowserView.initialIndex(cards: reference.cards, startCardID: secondCard.id), 1)
        XCTAssertEqual(ThaiMenuBrowserView.initialIndex(cards: reference.cards, startCardID: "nonexistent-id"), 0)
        XCTAssertEqual(ThaiMenuBrowserView.initialIndex(cards: reference.cards, startCardID: nil), 0)
    }

    func testFavoriteMenuCardBrowserOnlyDisplaysCustomFavoriteCards() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        let favoriteCards = [reference.cards[2], reference.cards[5]]
        
        let view = ThaiMenuBrowserView(startCardID: favoriteCards[1].id, cards: favoriteCards)
        XCTAssertEqual(view.cards?.count, 2)
        XCTAssertEqual(view.startCardID, favoriteCards[1].id)

        let initialIdx = ThaiMenuBrowserView.initialIndex(cards: favoriteCards, startCardID: favoriteCards[1].id)
        XCTAssertEqual(initialIdx, 1)

        let entry = FavoriteListEntry(kind: .menu(favoriteCards[0]), favoritedAt: Date())
        XCTAssertEqual(entry.menuCard?.id, favoriteCards[0].id)
        XCTAssertNil(entry.content)
    }
}

