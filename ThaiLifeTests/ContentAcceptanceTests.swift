@testable import ThaiLife
import XCTest

final class ContentAcceptanceTests: XCTestCase {

    func testBundledContentMatchesApprovedCategoryCounts() throws {
        let items = try ContentRepository.loadBundled()
        XCTAssertEqual(items.count, 1404, "Total items must be 1404")

        let groups = Dictionary(grouping: items, by: \.category)
        XCTAssertEqual(groups[.foodDining]?.count, 148, "饮食与点餐 should have 148 items")
        XCTAssertEqual(groups[.localErrands]?.count, 70, "本地办事 should have 70 items")
        XCTAssertEqual(groups[.basics]?.count, 160, "开口基础 should have 160 items")
        XCTAssertEqual(groups[.social]?.count, 90, "社交与人际 should have 90 items")
        XCTAssertEqual(groups[.numbers]?.count, 110, "数字、时间与数量 should have 110 items")
        XCTAssertEqual(groups[.shopping]?.count, 80, "购物与付款 should have 80 items")
        XCTAssertEqual(groups[.homeLiving]?.count, 90, "家与日常生活 should have 90 items")
        XCTAssertEqual(groups[.transport]?.count, 100, "交通与问路 should have 100 items")
        XCTAssertEqual(groups[.phoneNetwork]?.count, 60, "手机、网络与服务 should have 60 items")
        XCTAssertEqual(groups[.health]?.count, 80, "身体、健康与药店 should have 80 items")
        XCTAssertEqual(groups[.safety]?.count, 50, "安全与紧急求助 should have 50 items")
        XCTAssertEqual(groups[.weatherLeisure]?.count, 70, "天气、休闲与生活习惯 should have 70 items")
        XCTAssertEqual(groups[.airport]?.count, 50, "机场与入境 should have 50 items")
        XCTAssertEqual(groups[.hotel]?.count, 60, "酒店与景点 should have 60 items")
        XCTAssertEqual(groups[.googleMaps]?.count, 62, "Google地图常用词 should have 62 items")
        XCTAssertEqual(groups[.coreFunction]?.count, 124, "核心功能词 should have 124 items")
    }

    func testFoodDiningPlacesFruitImmediatelyAfterBaseFoodAndBeforeDrinks() throws {
        let words = try ContentRepository.loadBundled().filter {
            $0.category == .foodDining && $0.kind == .word
        }
        let ids = words.map(\.id)
        let expectedPrefix = [
            "food_dining-word-001", "food_dining-word-003", "food_dining-word-005",
            "food_dining-word-006", "food_dining-word-007", "food_dining-word-008",
            "food_dining-word-009", "food_dining-word-010",
            "food_dining-word-004",
            "food_dining-word-060", "food_dining-word-061", "food_dining-word-062",
            "food_dining-word-063", "food_dining-word-064", "food_dining-word-065",
            "food_dining-word-066", "food_dining-word-067", "food_dining-word-068",
            "food_dining-word-069",
            "food_dining-word-002", "food_dining-word-030", "food_dining-word-031",
            "food_dining-word-032", "food_dining-word-033", "food_dining-word-034",
            "food_dining-word-035", "food_dining-word-070", "food_dining-word-071",
            "food_dining-word-072", "food_dining-word-073", "food_dining-word-074",
            "food_dining-word-075"
        ]

        XCTAssertEqual(Array(ids.prefix(expectedPrefix.count)), expectedPrefix)
    }

    func testBundledDialoguesHaveCompleteBreakdowns() throws {
        let dialogues = try ContentRepository.loadBundled().filter { $0.kind == .dialogue }
        XCTAssertEqual(dialogues.count, 11)
        XCTAssertTrue(dialogues.allSatisfy { item in
            guard let turns = item.dialogueBreakdown else { return false }
            return !turns.isEmpty && turns.allSatisfy { !$0.segments.isEmpty }
        })
    }

    func testBundledChunksHaveCompleteDualLayerBreakdowns() throws {
        let chunks = try ContentRepository.loadBundled().filter { $0.kind == .chunk }

        XCTAssertEqual(chunks.count, 215)
        XCTAssertTrue(chunks.allSatisfy { item in
            guard let breakdown = item.chunkBreakdown else { return false }
            return !breakdown.combinations.isEmpty && !breakdown.minimal.isEmpty
        })
    }

    func testBundledWordBreakdownsFollowAllowlistAndRequiredAirportCompounds() throws {
        let items = try ContentRepository.loadBundled()
        let words = items.filter { $0.kind == .word }
        let broken = words.filter { $0.wordBreakdown != nil }
        XCTAssertFalse(broken.isEmpty)
        XCTAssertTrue(items.filter { $0.kind != .word }.allSatisfy { $0.wordBreakdown == nil })

        let denied: Set<String> = [
            "basics-word-001", "social-word-001", "airport-word-003", "airport-word-011",
            "airport-word-018", "airport-word-025", "airport-word-043", "hotel-word-003",
            "phone_network-word-015", "phone_network-word-035"
        ]
        XCTAssertTrue(broken.allSatisfy { !denied.contains($0.id) })

        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        XCTAssertEqual(byID["airport-word-016"]?.wordBreakdown?.combinations.map(\.thai), ["หมายเลข", "เที่ยวบิน"])
        XCTAssertEqual(byID["airport-word-019"]?.wordBreakdown?.minimal.map(\.thai), ["ตรวจ", "คน", "เข้า", "เมือง"])
        XCTAssertEqual(byID["airport-word-013"]?.wordBreakdown?.combinations.map(\.thai), ["ประตู", "ขึ้นเครื่อง"])
        XCTAssertEqual(byID["airport-word-017"]?.wordBreakdown?.combinations.map(\.thai), ["หนังสือ", "เดินทาง"])
    }

    func testBundledContentContainsExactly654ExampleTranslationsByCategory() throws {
        let items = try ContentRepository.loadBundled()
        let examples = items.filter { !($0.example?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
        let overlayExamples = examples.filter { $0.category != .coreFunction }
        XCTAssertEqual(overlayExamples.count, 654, "Bundled overlay content must contain exactly 654 examples")
        XCTAssertEqual(examples.filter { $0.category == .coreFunction }.count, 124)
        XCTAssertEqual(
            Dictionary(grouping: overlayExamples, by: \.category).mapValues(\.count),
            [
                .basics: 40,
                .social: 40,
                .numbers: 40,
                .foodDining: 59,
                .shopping: 40,
                .homeLiving: 45,
                .transport: 50,
                .phoneNetwork: 40,
                .health: 50,
                .safety: 50,
                .weatherLeisure: 50,
                .airport: 50,
                .hotel: 50,
                .localErrands: 50
            ]
        )
        XCTAssertTrue(examples.allSatisfy { !$0.exampleMeaning!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    func testGoogleMapsIncludesPopularBangkokLandmarksWithBreakdowns() throws {
        let items = try ContentRepository.loadBundled().filter { $0.category == .googleMaps }
        let byThai = Dictionary(uniqueKeysWithValues: items.map { ($0.thai, $0) })
        let expected = [
            "สุขุมวิท", "สยาม", "พระบรมมหาราชวัง", "วัดพระแก้ว", "วัดอรุณ", "วัดโพธิ์",
            "ถนนข้าวสาร", "ตลาดนัดจตุจักร", "เยาวราช", "ไอคอนสยาม", "สนามหลวง", "ศาลท้าวมหาพรหม"
        ]
        XCTAssertTrue(expected.allSatisfy { byThai[$0] != nil })
        XCTAssertEqual(byThai["วัดพระแก้ว"]?.segments.map(\.thai), ["วัด", "พระแก้ว"])
        XCTAssertEqual(byThai["ถนนข้าวสาร"]?.segments.map(\.thai), ["ถนน", "ข้าวสาร"])
        XCTAssertEqual(byThai["ตลาดนัดจตุจักร"]?.segments.map(\.thai), ["ตลาดนัด", "จตุจักร"])
        XCTAssertEqual(byThai["พระบรมมหาราชวัง"]?.segments.count, 0)
    }

    func testBundledContentPassesValidation() throws {
        let items = try ContentRepository.loadBundled()
        XCTAssertNoThrow(try ContentValidator.validate(items), "All bundled items should pass validation")
    }

    func testBundledContentContainsNoPlaceholderTemplates() throws {
        let items = try ContentRepository.loadBundled()
        let placeholders = items.filter {
            $0.thai.contains("ตัวอย่าง") && $0.meaningZhHans.contains("实用表达")
        }

        XCTAssertTrue(
            placeholders.isEmpty,
            "Packaged content must not contain template placeholders: \(placeholders.map(\.id).joined(separator: ", "))"
        )
    }

    func testAllItemsHaveRequiredFields() throws {
        let items = try ContentRepository.loadBundled()
        for item in items {
            XCTAssertFalse(item.id.isEmpty, "Item should have id")
            XCTAssertFalse(item.thai.isEmpty, "Item \(item.id) should have thai")
            XCTAssertFalse(item.meaningZhHans.isEmpty, "Item \(item.id) should have meaning")
            XCTAssertFalse(item.audioID.isEmpty, "Item \(item.id) should have audioID")
            XCTAssertFalse(item.sourceID.isEmpty, "Item \(item.id) should have sourceID")
        }
    }

    func testPrerequisiteIDsExist() throws {
        let items = try ContentRepository.loadBundled()
        let allIDs = Set(items.map(\.id))
        for item in items {
            for preID in item.prerequisiteIDs {
                XCTAssertTrue(allIDs.contains(preID), "\(item.id): prerequisite \(preID) not found")
            }
        }
    }
}
