@testable import ThaiLife
import XCTest

final class ChunkBreakdownViewTests: XCTestCase {
    func testChunkProducesCombinationAndMinimalSectionsInOrder() {
        let item = ContentItem.fixture(
            kind: .chunk,
            thai: "ขอโทษ",
            chunkBreakdown: ChunkBreakdown(
                combinations: [PhraseSegment(thai: "ขอโทษ", gloss: "抱歉")],
                minimal: [
                    PhraseSegment(thai: "ขอ", gloss: "请求"),
                    PhraseSegment(thai: "โทษ", gloss: "过错")
                ]
            )
        )

        XCTAssertEqual(
            ChunkBreakdownPresentation.sections(for: item),
            [
                ChunkBreakdownSection(title: "组合拆解", segments: [PhraseSegment(thai: "ขอโทษ", gloss: "抱歉")]),
                ChunkBreakdownSection(title: "最小拆解", segments: [
                    PhraseSegment(thai: "ขอ", gloss: "请求"),
                    PhraseSegment(thai: "โทษ", gloss: "过错")
                ])
            ]
        )
    }

    func testNonChunkProducesNoChunkBreakdownSections() {
        XCTAssertEqual(ChunkBreakdownPresentation.sections(for: ContentItem.fixture(kind: .word)), [])
    }

    func testWordWithBreakdownProducesCombinationAndMinimalSections() {
        let breakdown = ChunkBreakdown(
            combinations: [PhraseSegment(thai: "หมายเลข", gloss: "号码"), PhraseSegment(thai: "เที่ยวบิน", gloss: "航班")],
            minimal: [
                PhraseSegment(thai: "หมาย", gloss: "标记"),
                PhraseSegment(thai: "เลข", gloss: "数字"),
                PhraseSegment(thai: "เที่ยว", gloss: "趟；班次"),
                PhraseSegment(thai: "บิน", gloss: "飞")
            ]
        )
        let item = ContentItem.fixture(
            kind: .word,
            thai: "หมายเลขเที่ยวบิน",
            example: "หมายเลขเที่ยวบินคุณคืออะไรครับ",
            exampleMeaning: "你的航班号是多少？",
            segments: [
                PhraseSegment(thai: "หมายเลข", gloss: "号码"),
                PhraseSegment(thai: "เที่ยวบิน", gloss: "航班"),
                PhraseSegment(thai: "คุณ", gloss: "你")
            ],
            wordBreakdown: breakdown
        )

        XCTAssertEqual(
            ChunkBreakdownPresentation.sections(for: item),
            [
                ChunkBreakdownSection(title: "最小拆解", segments: breakdown.minimal)
            ]
        )
        XCTAssertTrue(CardBackExtraContent.showsHeadwordBreakdown(item))
        XCTAssertTrue(CardBackExtraContent.showsExampleSegmentList(item))
        XCTAssertEqual(
            CardBackExtraContent.exampleSegmentsToDisplay(for: item).map(\.thai),
            ["คุณ"]
        )
        XCTAssertFalse(CardBackExtraContent.showsHeadwordBreakdown(ContentItem.fixture(kind: .word)))
        XCTAssertFalse(CardBackExtraContent.showsExampleSegmentList(ContentItem.fixture(kind: .chunk, chunkBreakdown: ChunkBreakdown(
            combinations: [PhraseSegment(thai: "ขอโทษ", gloss: "抱歉")],
            minimal: [PhraseSegment(thai: "ขอโทษ", gloss: "抱歉")]
        ))))
    }

    func testWordWithIdenticalLayersHidesDuplicateMinimalSection() {
        let parts = [
            PhraseSegment(thai: "ทาง", gloss: "路"),
            PhraseSegment(thai: "ออก", gloss: "出")
        ]
        let item = ContentItem.fixture(
            kind: .word,
            thai: "ทางออก",
            wordBreakdown: ChunkBreakdown(combinations: parts, minimal: parts)
        )

        XCTAssertEqual(
            ChunkBreakdownPresentation.sections(for: item),
            [ChunkBreakdownSection(title: "最小拆解", segments: parts)]
        )
    }

    func testWordExampleSegmentListHidesHeadwordCombinationSpan() {
        let breakdown = ChunkBreakdown(
            combinations: [PhraseSegment(thai: "หนังสือ", gloss: "证件/书"), PhraseSegment(thai: "เดินทาง", gloss: "旅行")],
            minimal: [
                PhraseSegment(thai: "หนังสือ", gloss: "证件/书"),
                PhraseSegment(thai: "เดิน", gloss: "走"),
                PhraseSegment(thai: "ทาง", gloss: "路")
            ]
        )
        let item = ContentItem.fixture(
            kind: .word,
            thai: "หนังสือเดินทาง",
            example: "ขอหนังสือเดินทางด้วยครับ",
            exampleMeaning: "请出示护照。",
            segments: [
                PhraseSegment(thai: "ขอ", gloss: "请出示"),
                PhraseSegment(thai: "หนังสือ", gloss: "证件/书"),
                PhraseSegment(thai: "เดินทาง", gloss: "旅行"),
                PhraseSegment(thai: "ด้วย", gloss: "也"),
                PhraseSegment(thai: "ครับ", gloss: "语气词(男)")
            ],
            wordBreakdown: breakdown
        )

        XCTAssertEqual(
            CardBackExtraContent.exampleSegmentsToDisplay(for: item).map(\.thai),
            ["ขอ", "ด้วย", "ครับ"]
        )
        XCTAssertEqual(ChunkBreakdownPresentation.sections(for: item).map(\.title), ["最小拆解"])
    }

    func testDialoguePresentationShowsOnlyCurrentTurnWhenReviewing() {
        let turns = [
            DialogueTurn(speaker: "A", thai: "สวัสดี", meaningZhHans: "你好", segments: [PhraseSegment(thai: "สวัสดี", gloss: "你好")]),
            DialogueTurn(speaker: "B", thai: "ครับ", meaningZhHans: "好", segments: [PhraseSegment(thai: "ครับ", gloss: "男性礼貌词")])
        ]
        let item = ContentItem.fixture(kind: .dialogue, thai: "A: สวัสดี\nB: ครับ", romanization: "", meaningZhHans: "A: 你好\nB: 好", dialogueBreakdown: turns)

        XCTAssertEqual(DialogueBreakdownPresentation.turns(for: item, isBrowsing: false, continuationPart: 1), [turns[1]])
        XCTAssertEqual(DialogueBreakdownPresentation.turns(for: item, isBrowsing: false, continuationPart: 2), [])
    }

    func testDialoguePresentationShowsAllTurnsWhenBrowsing() {
        let item = ContentItem.fixture(
            kind: .dialogue,
            thai: "A: สวัสดี\nB: ครับ",
            romanization: "",
            meaningZhHans: "A: 你好\nB: 好",
            dialogueBreakdown: [
                DialogueTurn(speaker: "A", thai: "สวัสดี", meaningZhHans: "你好", segments: [PhraseSegment(thai: "สวัสดี", gloss: "你好")]),
                DialogueTurn(speaker: "B", thai: "ครับ", meaningZhHans: "好", segments: [PhraseSegment(thai: "ครับ", gloss: "男性礼貌词")])
            ]
        )

        XCTAssertEqual(
            DialogueBreakdownPresentation.turns(for: item, isBrowsing: true, continuationPart: 0),
            item.dialogueBreakdown
        )
    }

}
