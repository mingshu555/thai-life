import XCTest
@testable import ThaiLife

final class WordFamilyTests: XCTestCase {

    func testLoadWordFamilies_ReturnsValidData() {
        let families = ContentRepository.loadWordFamilies()
        XCTAssertFalse(families.isEmpty, "Word families should not be empty")
        XCTAssertGreaterThanOrEqual(families.count, 5, "Expected at least 5 root word families")

        for family in families {
            XCTAssertFalse(family.id.isEmpty, "Family ID should not be empty")
            XCTAssertFalse(family.rootThai.isEmpty, "Root Thai should not be empty")
            XCTAssertFalse(family.rootRomanization.isEmpty, "Root romanization should not be empty")
            XCTAssertFalse(family.rootMeaningZhHans.isEmpty, "Root meaning should not be empty")
            XCTAssertFalse(family.items.isEmpty, "Family should contain at least 1 member item")

            for member in family.items {
                XCTAssertFalse(member.id.isEmpty, "Member ID should not be empty")
                XCTAssertFalse(member.thai.isEmpty, "Member Thai should not be empty")
                XCTAssertFalse(member.romanization.isEmpty, "Member romanization should not be empty")
                XCTAssertFalse(member.meaningZhHans.isEmpty, "Member meaning should not be empty")
                if family.id != "family-numbers-100" && family.id != "family-currency-thb" {
                    XCTAssertTrue(member.thai.contains(family.rootThai) || member.thai.hasPrefix(family.rootThai))
                }
            }
        }
    }

    func testMaiWordFamily_ContainsExpectedHighFrequencyWords() {
        let families = ContentRepository.loadWordFamilies()
        guard let maiFamily = families.first(where: { $0.rootThai == "ไม่" }) else {
            XCTFail("Word family 'ไม่' should exist")
            return
        }

        XCTAssertEqual(maiFamily.rootMeaningZhHans, "不 (否定前缀)")
        let thais = maiFamily.items.map(\.thai)
        XCTAssertTrue(thais.contains("ไม่ใช่") || thais.contains("ไม่มี"), "Family 'ไม่' should contain high-frequency words like ไม่ใช่ or ไม่มี")
    }

    func testNumbersCard_CoversKeyFormsThroughOneHundred() {
        let families = ContentRepository.loadWordFamilies()
        guard let card = families.first(where: { $0.id == "family-numbers-100" }) else {
            XCTFail("Number card should exist")
            return
        }

        XCTAssertEqual(card.category, .basics)
        XCTAssertEqual(card.rootThai, "ตัวเลข")
        XCTAssertEqual(card.rootRomanization, "tua-lêek")
        XCTAssertEqual(card.itemCount, card.items.count)
        XCTAssertTrue(card.usageNote.contains("11–19"))
        XCTAssertTrue(card.usageNote.contains("ยี่สิบ"))
        XCTAssertTrue(card.usageNote.contains("หนึ่งร้อย"))

        let thai = Set(card.items.map(\.thai))
        XCTAssertTrue(thai.contains("ศูนย์"))
        XCTAssertTrue(thai.contains("สิบเอ็ด"))
        XCTAssertTrue(thai.contains("ยี่สิบ"))
        XCTAssertTrue(thai.contains("ยี่สิบเอ็ด"))
        XCTAssertTrue(thai.contains("หกสิบ"))
        XCTAssertTrue(thai.contains("แปดสิบ"))
        XCTAssertTrue(thai.contains("หนึ่งร้อย"))
    }

    func testNumbersCard_UsesBundledAudioForBaseDigits() {
        let families = ContentRepository.loadWordFamilies()
        guard let card = families.first(where: { $0.id == "family-numbers-100" }) else {
            XCTFail("Number card should exist")
            return
        }

        let expectedAudioIDs = [
            "0": "audio-numbers-word-001",
            "1": "audio-numbers-word-002",
            "2": "audio-numbers-word-003",
            "3": "audio-numbers-word-004",
            "4": "audio-numbers-word-005",
            "5": "audio-numbers-word-006",
            "6": "audio-numbers-word-007",
            "7": "audio-numbers-word-008",
            "8": "audio-numbers-word-009",
            "9": "audio-numbers-word-010",
            "10": "audio-numbers-word-011"
        ]

        for member in card.items {
            guard let expectedAudioID = expectedAudioIDs[member.meaningZhHans] else { continue }
            XCTAssertEqual(member.audioID, expectedAudioID, "Base number \(member.meaningZhHans) should use its bundled audio")
        }
    }

    func testWordFamilyAudioReferencesAreBundled() {
        let families = ContentRepository.loadWordFamilies()
        let bundle = ContentRepository.resourceBundle

        for family in families {
            for member in family.items {
                guard let audioID = member.audioID, !audioID.isEmpty else { continue }
                XCTAssertNotNil(
                    bundle.url(forResource: audioID, withExtension: "mp3", subdirectory: "Audio"),
                    "Missing bundled word-family audio for \(member.id): \(audioID)"
                )
            }
        }
    }

    func testCurrencyCard_IncludesBahtSatangAndDecimalPointForms() {
        let families = ContentRepository.loadWordFamilies()
        guard let card = families.first(where: { $0.id == "family-currency-thb" }) else {
            XCTFail("Currency card should exist")
            return
        }

        XCTAssertEqual(card.category, .basics)
        XCTAssertEqual(card.rootThai, "บาท")
        XCTAssertEqual(card.rootRomanization, "bàat")
        XCTAssertEqual(card.itemCount, card.items.count)
        XCTAssertTrue(card.usageNote.contains("สตางค์"))
        XCTAssertTrue(card.usageNote.contains("จุด"))

        let thai = Set(card.items.map(\.thai))
        XCTAssertTrue(thai.contains("ยี่สิบเอ็ดบาท"))
        XCTAssertTrue(thai.contains("ห้าสิบสตางค์"))
        XCTAssertTrue(thai.contains("ยี่สิบเอ็ดบาทห้าสิบสตางค์"))
        XCTAssertTrue(thai.contains("ยี่สิบเอ็ดจุดห้าศูนย์"))
    }

}
