@testable import ThaiLife
import XCTest
import UIKit

final class ThaiMenuResourceTests: XCTestCase {
    func testNewFoodDiningFruitAndDrinkAudioIsBundled() throws {
        let bundle = ContentRepository.resourceBundle
        let reference = try ContentRepository.loadThaiMenuReference()
        XCTAssertEqual(reference.cards.count, 50)
        for card in reference.cards {
            XCTAssertNotNil(
                bundle.url(forResource: card.audioID, withExtension: "mp3", subdirectory: "Audio"),
                "Missing menu audio: \(card.audioID)"
            )
            for part in card.breakdown.combinations + card.breakdown.minimal {
                let audioID = SegmentAudioID.audioID(for: part.thai)
                XCTAssertNotNil(
                    bundle.url(forResource: audioID, withExtension: "mp3", subdirectory: "Audio"),
                    "Missing menu breakdown audio: \(part.thai) / \(audioID)"
                )
            }
        }
    }

    func testBreakdownGlossesDoNotRepeatTheirThaiTerm() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        for card in reference.cards {
            for part in card.breakdown.combinations + card.breakdown.minimal {
                XCTAssertFalse(
                    part.glossZhHans.contains(part.thai),
                    "Breakdown gloss repeats the Thai term for \(card.id): \(part.thai)"
                )
            }
        }
    }

    func testNamTokMooUsesActualMinimalBreakdown() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        let card = try XCTUnwrap(reference.cards.first(where: { $0.id == "nam-tok-moo" }))
        XCTAssertEqual(card.breakdown.minimal.map(\.thai), ["น้ำ", "ตก", "หมู"])
        XCTAssertEqual(card.breakdown.minimal.map(\.glossZhHans), ["水；液体", "落下；滴落", "猪肉"])
    }

    func testMinimalBreakdownHasNoRepeatedTerms() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        for card in reference.cards {
            let terms = card.breakdown.minimal.map(\.thai)
            XCTAssertEqual(Set(terms).count, terms.count, "Repeated minimal breakdown term for \(card.id)")
        }
    }

    func testEveryMenuCardImageIsBundledAndReadable() throws {
        let reference = try ContentRepository.loadThaiMenuReference()
        let bundle = ContentRepository.resourceBundle
        for card in reference.cards {
            guard let url = bundle.url(forResource: card.imageAssetID, withExtension: "jpg", subdirectory: "ThaiMenu") else {
                return XCTFail("Missing menu image: \(card.imageAssetID)")
            }
            XCTAssertNotNil(UIImage(contentsOfFile: url.path))
            XCTAssertNotNil(bundle.url(forResource: card.audioID, withExtension: "mp3", subdirectory: "Audio"), "Missing menu audio: \(card.audioID)")
        }
        XCTAssertNotNil(bundle.url(forResource: "thai-menu-assets", withExtension: "md", subdirectory: "Attributions"))
    }
}
