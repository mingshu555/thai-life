@testable import ThaiLife
import XCTest

final class LooplessSignageContentTests: XCTestCase {
    func testReferenceLoadsWithFiveMandatoryScenesAndConfusionGroups() throws {
        let reference = try ContentRepository.loadLooplessSignageReference()
        XCTAssertTrue(Set(reference.scenes.map(\.id)).isSuperset(of: LooplessSignageValidator.mandatorySceneIDs))
        XCTAssertGreaterThan(reference.scenes.count, LooplessSignageValidator.mandatorySceneIDs.count)
        XCTAssertFalse(reference.glyphs.isEmpty)
        XCTAssertFalse(reference.confusionGroups.isEmpty)
    }

    func testEveryCharacterUsedByExamplesHasAnExplicitGlyphEntry() throws {
        let reference = try ContentRepository.loadLooplessSignageReference()
        let covered = Set(reference.glyphs.flatMap { $0.standardThai.unicodeScalars })
        let ignored: Set<Unicode.Scalar> = [" ", "/"]
        for scene in reference.scenes {
            for scalar in scene.standardThaiWord.unicodeScalars where !ignored.contains(scalar) {
                XCTAssertTrue(covered.contains(scalar), "Missing glyph entry for \(String(scalar)) in \(scene.id)")
            }
        }
    }

    func testReferenceSceneWordsHaveCompleteAudioIDsAndMeaning() throws {
        let reference = try ContentRepository.loadLooplessSignageReference()
        for scene in reference.scenes {
            XCTAssertFalse(scene.thaiWord.isEmpty)
            XCTAssertFalse(scene.audioID.isEmpty)
            XCTAssertFalse(scene.meaningZhHans.isEmpty)
        }
    }
    func testCombiningVowelsAndToneMarksUseVisibleCarrierForms() throws {
        let glyphs = try ContentRepository.loadLooplessSignageReference().glyphs
        let textByID = Dictionary(uniqueKeysWithValues: glyphs.map { ($0.id, $0.comparisonText) })
        XCTAssertEqual(textByID["sara-i"], "อิ")
        XCTAssertEqual(textByID["sara-ii"], "อี")
        XCTAssertEqual(textByID["mai-ek"], "อ่")
        XCTAssertEqual(textByID["mai-tho"], "อ้")
        XCTAssertEqual(textByID["sara-e"], "เอ")
        XCTAssertEqual(textByID["sara-ae"], "แอ")
    }

}
