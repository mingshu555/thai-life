@testable import ThaiLife
import XCTest

final class ContentValidatorTests: XCTestCase {

    // MARK: - Segment reconstruction

    func testValidatorRejectsSegmentTextThatDoesNotReconstructPhrase() {
        let item = ContentItem.fixture(
            id: "test-001",
            thai: "น้ำเปล่า",
            segments: [PhraseSegment(thai: "น้ำ", gloss: "水")]
        )
        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let valError = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(valError.errors.contains(where: {
                if case .segmentReconstructionFailed(_, _, _) = $0 { return true }; return false
            }))
        }
    }

    func testValidatorAcceptsCorrectSegmentReconstruction() {
        let item = ContentItem.fixture(
            id: "test-002",
            thai: "น้ำเปล่า",
            segments: [
                PhraseSegment(thai: "น้ำ", gloss: "水"),
                PhraseSegment(thai: "เปล่า", gloss: "空的/纯的")
            ]
        )
        XCTAssertNoThrow(try ContentValidator.validate([item]))
    }

    // MARK: - Dialogue breakdowns

    func testDialogueRequiresBreakdown() {
        let item = ContentItem.fixture(
            kind: .dialogue,
            thai: "A: สวัสดีครับ\nB: สวัสดีค่ะ",
            romanization: "",
            meaningZhHans: "A: 你好\nB: 你好"
        )

        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(.missingDialogueBreakdown(id: "fixture-001")))
        }
    }

    func testDialogueRejectsTurnSegmentsThatDoNotReconstructTurnThai() {
        let item = ContentItem.fixture(
            kind: .dialogue,
            thai: "A: สวัสดีครับ",
            romanization: "",
            meaningZhHans: "A: 你好",
            dialogueBreakdown: [
                DialogueTurn(
                    speaker: "A",
                    thai: "สวัสดีครับ",
                    meaningZhHans: "你好",
                    segments: [PhraseSegment(thai: "สวัสดี", gloss: "你好")]
                )
            ]
        )

        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(
                .dialogueSegmentReconstructionFailed(
                    id: "fixture-001", turn: 0, expected: "สวัสดีครับ", got: "สวัสดี"
                )
            ))
        }
    }

    // MARK: - Chunk breakdowns

    func testChunkRequiresBothBreakdownLayers() {
        let item = ContentItem.fixture(kind: .chunk, thai: "ขอโทษ", chunkBreakdown: nil)

        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(.missingChunkBreakdown(id: "fixture-001")))
        }
    }

    func testChunkBreakdownRequiresEachLayerToReconstructThai() {
        let breakdown = ChunkBreakdown(
            combinations: [PhraseSegment(thai: "ขอโทษ", gloss: "抱歉")],
            minimal: [PhraseSegment(thai: "ขอ", gloss: "请求")]
        )
        let item = ContentItem.fixture(kind: .chunk, thai: "ขอโทษ", chunkBreakdown: breakdown)

        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(
                .chunkBreakdownReconstructionFailed(
                    id: "fixture-001", layer: "minimal", expected: "ขอโทษ", got: "ขอ"
                )
            ))
        }
    }

    func testNonChunkRejectsChunkBreakdown() {
        let breakdown = ChunkBreakdown(
            combinations: [PhraseSegment(thai: "สวัสดี", gloss: "你好")],
            minimal: [PhraseSegment(thai: "สวัสดี", gloss: "你好")]
        )
        let item = ContentItem.fixture(kind: .word, thai: "สวัสดี", chunkBreakdown: breakdown)

        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(.unexpectedChunkBreakdown(id: "fixture-001")))
        }
    }


    // MARK: - Word breakdowns

    func testWordBreakdownIsOptional() {
        XCTAssertNoThrow(try ContentValidator.validate([ContentItem.fixture(kind: .word)]))
    }

    func testNonWordRejectsWordBreakdown() {
        let breakdown = ChunkBreakdown(
            combinations: [PhraseSegment(thai: "หมายเลข", gloss: "号码"), PhraseSegment(thai: "เที่ยวบิน", gloss: "航班")],
            minimal: [PhraseSegment(thai: "หมายเลข", gloss: "号码"), PhraseSegment(thai: "เที่ยวบิน", gloss: "航班")]
        )
        let wordOnSentence = ContentItem.fixture(kind: .sentence, thai: "หมายเลขเที่ยวบิน", wordBreakdown: breakdown)
        XCTAssertThrowsError(try ContentValidator.validate([wordOnSentence])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(.unexpectedWordBreakdown(id: "fixture-001")))
        }
    }

    func testWordBreakdownRequiresAtLeastTwoSegmentsAndReconstruction() {
        let tooSmall = ChunkBreakdown(
            combinations: [PhraseSegment(thai: "หมายเลขเที่ยวบิน", gloss: "航班号")],
            minimal: [PhraseSegment(thai: "หมายเลขเที่ยวบิน", gloss: "航班号")]
        )
        XCTAssertThrowsError(try ContentValidator.validate([
            ContentItem.fixture(kind: .word, thai: "หมายเลขเที่ยวบิน", wordBreakdown: tooSmall)
        ])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(.wordBreakdownTooSmall(id: "fixture-001", layer: "combinations")))
        }

        let broken = ChunkBreakdown(
            combinations: [PhraseSegment(thai: "หมายเลข", gloss: "号码"), PhraseSegment(thai: "เที่ยวบิน", gloss: "航班")],
            minimal: [PhraseSegment(thai: "หมาย", gloss: "标记"), PhraseSegment(thai: "เลข", gloss: "数字")]
        )
        XCTAssertThrowsError(try ContentValidator.validate([
            ContentItem.fixture(kind: .word, thai: "หมายเลขเที่ยวบิน", wordBreakdown: broken)
        ])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(
                .wordBreakdownReconstructionFailed(id: "fixture-001", layer: "minimal", expected: "หมายเลขเที่ยวบิน", got: "หมายเลข")
            ))
        }
    }

    func testWordBreakdownRejectsUnsplitExampleHeadword() {
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
                PhraseSegment(thai: "หมายเลขเที่ยวบิน", gloss: "航班号"),
                PhraseSegment(thai: "คุณ", gloss: "你"),
                PhraseSegment(thai: "คืออะไรครับ", gloss: "是什么")
            ],
            wordBreakdown: breakdown
        )
        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(.wordBreakdownExampleHeadwordUnsplit(id: "fixture-001")))
        }
    }

    func testWordBreakdownAcceptsMatchingExampleSpan() {
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
                PhraseSegment(thai: "คุณ", gloss: "你"),
                PhraseSegment(thai: "คืออะไรครับ", gloss: "是什么")
            ],
            wordBreakdown: breakdown
        )
        XCTAssertNoThrow(try ContentValidator.validate([item]))
    }

    // MARK: - Duplicate IDs
    // MARK: - Duplicate IDs

    func testValidatorRejectsDuplicateIDs() {
        let item1 = ContentItem.fixture(id: "dup-001", thai: "你好")
        let item2 = ContentItem.fixture(id: "dup-001", thai: "谢谢")
        XCTAssertThrowsError(try ContentValidator.validate([item1, item2])) { error in
            guard let valError = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(valError.errors.contains(where: {
                if case .duplicateID(_) = $0 { return true }; return false
            }))
        }
    }

    // MARK: - Empty fields

    func testValidatorRejectsEmptyThai() {
        let item = ContentItem.fixture(id: "empty-thai", thai: "")
        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    func testValidatorRejectsEmptyMeaning() {
        let item = ContentItem.fixture(id: "empty-meaning", meaningZhHans: "")
        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    func testValidatorRejectsEmptyRomanization() {
        let item = ContentItem.fixture(id: "empty-rom", romanization: "")
        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    func testValidatorRejectsMissingAudioID() {
        let item = ContentItem.fixture(id: "no-audio", audioID: "")
        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    // MARK: - Unknown prerequisites

    func testValidatorRejectsUnknownPrerequisite() {
        let item = ContentItem.fixture(
            id: "orphan-pre",
            prerequisiteIDs: ["nonexistent"]
        )
        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let valError = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(valError.errors.contains(where: {
                if case .unknownPrerequisite(_, _) = $0 { return true }; return false
            }))
        }
    }

    // MARK: - Self-referencing prerequisite

    func testValidatorRejectsSelfReferencingPrerequisite() {
        let item = ContentItem.fixture(
            id: "self-ref",
            prerequisiteIDs: ["self-ref"]
        )
        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    // MARK: - Circular prerequisites

    func testValidatorRejectsCircularPrerequisites() {
        let itemA = ContentItem.fixture(id: "circle-a", prerequisiteIDs: ["circle-b"])
        let itemB = ContentItem.fixture(id: "circle-b", prerequisiteIDs: ["circle-a"])
        XCTAssertThrowsError(try ContentValidator.validate([itemA, itemB])) { error in
            guard let valError = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(valError.errors.contains(where: {
                if case .circularPrerequisite(_) = $0 { return true }; return false
            }))
        }
    }

    // MARK: - Unknown related IDs

    func testValidatorRejectsUnknownRelatedIDs() {
        let item = ContentItem.fixture(id: "orphan-rel", relatedIDs: ["nonexistent"])
        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    // MARK: - Missing source ID

    func testValidatorRejectsMissingSourceID() {
        let item = ContentItem.fixture(id: "no-source", sourceID: "")
        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    // MARK: - Example translation integrity

    func testValidatorRejectsExampleMeaningBuiltFromSegmentGlosses() {
        let item = ContentItem.fixture(
            id: "mechanical-example-meaning",
            example: "เมื่อคืน นอนหลับดีไหมครับ",
            exampleMeaning: "昨晚睡睡着好吗吗语气词",
            segments: [
                PhraseSegment(thai: "เมื่อคืน", gloss: "昨晚"),
                PhraseSegment(thai: "นอน", gloss: "睡"),
                PhraseSegment(thai: "หลับ", gloss: "睡着"),
                PhraseSegment(thai: "ดี", gloss: "好吗"),
                PhraseSegment(thai: "ไหม", gloss: "吗"),
                PhraseSegment(thai: "ครับ", gloss: "语气词(男)")
            ]
        )

        XCTAssertThrowsError(try ContentValidator.validate([item])) { error in
            guard let validation = error as? ContentValidator.ValidationFailedError else {
                return XCTFail("Expected ValidationFailedError")
            }
            XCTAssertTrue(validation.errors.contains(where: {
                if case .mechanicalExampleMeaning = $0 { return true }
                return false
            }))
        }
    }

    func testValidatorRejectsExampleWithoutExampleMeaning() {
        let item = ContentItem.fixture(
            id: "missing-example-meaning",
            example: "สวัสดีครับ",
            segments: [PhraseSegment(thai: "สวัสดีครับ", gloss: "你好")]
        )

        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    func testValidatorRejectsExampleMeaningWithoutExample() {
        let item = ContentItem.fixture(
            id: "orphan-example-meaning",
            exampleMeaning: "你好"
        )

        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    func testValidatorRejectsExampleSegmentsThatDoNotReconstructExample() {
        let item = ContentItem.fixture(
            id: "broken-example-segments",
            example: "สวัสดีครับ",
            exampleMeaning: "你好",
            segments: [PhraseSegment(thai: "สวัสดี", gloss: "问候")]
        )

        XCTAssertThrowsError(try ContentValidator.validate([item]))
    }

    // MARK: - Happy path

    func testValidatorAcceptsValidItem() {
        let item = ContentItem.fixture(
            id: "valid-001",
            thai: "สวัสดี",
            romanization: "sà-wàt-dii",
            meaningZhHans: "你好",
            audioID: "audio-001",
            sourceID: "author-001"
        )
        XCTAssertNoThrow(try ContentValidator.validate([item]))
    }
}

final class ExampleMeaningDisplayTests: XCTestCase {

    func testDisplayExampleMeaningRemovesRecognizedMalePoliteParticleGloss() {
        let item = ContentItem.fixture(
            exampleMeaning: "昨晚睡得好吗礼貌语气词(男)",
            segments: [PhraseSegment(thai: "ครับ", gloss: "礼貌语气词(男)")]
        )

        XCTAssertEqual(item.displayExampleMeaning, "昨晚睡得好吗")
        XCTAssertEqual(item.segments.last?.gloss, "礼貌语气词(男)")
    }

    func testDisplayExampleMeaningRemovesRecognizedFemalePoliteParticleGloss() {
        let item = ContentItem.fixture(
            exampleMeaning: "谢谢礼貌语气词(女)",
            segments: [PhraseSegment(thai: "ค่ะ", gloss: "礼貌语气词(女)")]
        )

        XCTAssertEqual(item.displayExampleMeaning, "谢谢")
    }

    func testDisplayExampleMeaningRemovesRecognizedQuestionParticleGloss() {
        let item = ContentItem.fixture(
            exampleMeaning: "可以吗语气词(女)",
            segments: [PhraseSegment(thai: "คะ", gloss: "语气词(女)")]
        )

        XCTAssertEqual(item.displayExampleMeaning, "可以吗")
    }

    func testDisplayExampleMeaningRemovesAcceptedPoliteParticleGlossVariants() {
        let cases = [
            (thai: "ครับ", suffix: "语气词(男)"),
            (thai: "ค่ะ", suffix: "礼貌语气词"),
            (thai: "คะ", suffix: "语气词")
        ]

        for testCase in cases {
            let item = ContentItem.fixture(
                exampleMeaning: "测试释义\(testCase.suffix)",
                segments: [PhraseSegment(thai: testCase.thai, gloss: testCase.suffix)]
            )

            XCTAssertEqual(item.displayExampleMeaning, "测试释义", "Unexpected result for \(testCase.thai) / \(testCase.suffix)")
        }
    }

    func testDisplayExampleMeaningPreservesMeaningForNormalFinalWord() {
        let item = ContentItem.fixture(
            exampleMeaning: "我喜欢米饭",
            segments: [PhraseSegment(thai: "ข้าว", gloss: "米饭")]
        )

        XCTAssertEqual(item.displayExampleMeaning, "我喜欢米饭")
    }

    func testDisplayExampleMeaningPreservesMeaningWhenRecognizedParticleSuffixDoesNotMatch() {
        let item = ContentItem.fixture(
            exampleMeaning: "我睡得很好",
            segments: [PhraseSegment(thai: "ครับ", gloss: "礼貌语气词(男)")]
        )

        XCTAssertEqual(item.displayExampleMeaning, "我睡得很好")
    }

    func testDisplayExampleMeaningPreservesCustomGlossAndNonFinalParticle() {
        let customGlossItem = ContentItem.fixture(
            exampleMeaning: "你好custom label",
            segments: [PhraseSegment(thai: "ครับ", gloss: "custom label")]
        )
        let nonFinalParticleItem = ContentItem.fixture(
            exampleMeaning: "你好礼貌语气词(男)世界",
            segments: [
                PhraseSegment(thai: "ครับ", gloss: "礼貌语气词(男)"),
                PhraseSegment(thai: "โลก", gloss: "世界")
            ]
        )

        XCTAssertEqual(customGlossItem.displayExampleMeaning, "你好custom label")
        XCTAssertEqual(nonFinalParticleItem.displayExampleMeaning, "你好礼貌语气词(男)世界")
    }

    func testDisplayExampleMeaningPreservesRawValueWhenMeaningOrSegmentsAreMissing() {
        let missingMeaning = ContentItem.fixture(
            segments: [PhraseSegment(thai: "ครับ", gloss: "礼貌语气词(男)")]
        )
        let missingSegments = ContentItem.fixture(exampleMeaning: "你好")

        XCTAssertNil(missingMeaning.displayExampleMeaning)
        XCTAssertEqual(missingSegments.displayExampleMeaning, "你好")
    }
}

final class ReviewCardTextTests: XCTestCase {
    func testWordCardDoesNotSplitExampleSegmentsIntoCardText() {
        let item = ContentItem.fixture(
            id: "word-with-example",
            thai: "นอน",
            example: "เมื่อคืน นอนหลับดีไหมครับ",
            segments: [
                PhraseSegment(thai: "เมื่อคืน", gloss: "昨晚"),
                PhraseSegment(thai: "นอน", gloss: "睡"),
                PhraseSegment(thai: "หลับ", gloss: "睡着"),
                PhraseSegment(thai: "ดี", gloss: "好"),
                PhraseSegment(thai: "ไหม", gloss: "吗"),
                PhraseSegment(thai: "ครับ", gloss: "语气词(男)")
            ]
        )

        XCTAssertEqual(
            ReviewCardText.displayedThai(for: item, isContinuation: false, continuationPart: 0),
            "นอน"
        )
    }

    func testCourseBrowseSentenceBackShowsCompleteThaiDespiteSegments() {
        let item = ContentItem.fixture(
            id: "browse-sentence",
            kind: .sentence,
            thai: "ฉันอยากไปตลาดตอนเย็นนี้",
            segments: [
                PhraseSegment(thai: "ฉัน", gloss: "我"),
                PhraseSegment(thai: "อยาก", gloss: "想要"),
                PhraseSegment(thai: "ไป", gloss: "去"),
                PhraseSegment(thai: "ตลาด", gloss: "市场"),
                PhraseSegment(thai: "ตอน", gloss: "时候"),
                PhraseSegment(thai: "เย็น", gloss: "傍晚"),
                PhraseSegment(thai: "นี้", gloss: "这"),
            ]
        )

        XCTAssertEqual(
            ReviewCardText.displayedThai(
                for: item,
                isContinuation: false,
                continuationPart: 0,
                isBrowsing: true
            ),
            "ฉันอยากไปตลาดตอนเย็นนี้"
        )
    }

    func testFavoriteSentenceBackShowsCompleteThaiInsteadOfOnlyFirstSegmentHalf() {
        let item = ContentItem.fixture(
            id: "favorite-sentence",
            kind: .sentence,
            thai: "ฉันอยากไปตลาดตอนเย็นนี้",
            segments: [
                PhraseSegment(thai: "ฉัน", gloss: "我"),
                PhraseSegment(thai: "อยาก", gloss: "想要"),
                PhraseSegment(thai: "ไป", gloss: "去"),
                PhraseSegment(thai: "ตลาด", gloss: "市场"),
                PhraseSegment(thai: "ตอน", gloss: "时候"),
                PhraseSegment(thai: "เย็น", gloss: "傍晚"),
                PhraseSegment(thai: "นี้", gloss: "这")
            ]
        )

        XCTAssertEqual(
            ReviewCardText.displayedThai(for: item, isContinuation: false, continuationPart: 0),
            "ฉันอยากไปตลาดตอนเย็นนี้"
        )
    }

    func testReviewContinuationStillUsesSecondSegmentHalf() {
        let item = ContentItem.fixture(
            id: "review-sentence",
            kind: .sentence,
            thai: "ฉันอยากไปตลาดตอนเย็นนี้",
            segments: [
                PhraseSegment(thai: "ฉัน", gloss: "我"),
                PhraseSegment(thai: "อยาก", gloss: "想要"),
                PhraseSegment(thai: "ไป", gloss: "去"),
                PhraseSegment(thai: "ตลาด", gloss: "市场"),
                PhraseSegment(thai: "ตอน", gloss: "时候"),
                PhraseSegment(thai: "เย็น", gloss: "傍晚"),
                PhraseSegment(thai: "นี้", gloss: "这"),
            ]
        )

        XCTAssertEqual(
            ReviewCardText.displayedThai(
                for: item,
                isContinuation: true,
                continuationPart: 1
            ),
            "ตลาดตอนเย็นนี้"
        )
    }
}

final class FavoriteListPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    func testFavoriteListGroupsByDateOrdersNewestAndFiltersMissingItems() {
        let content = [ContentItem.fixture(id: "earlier"), ContentItem.fixture(id: "later"), ContentItem.fixture(id: "yesterday")]
        let records = [
            FavoriteSnapshot(contentID: "earlier", favoritedAt: date("2026-08-16 08:00")),
            FavoriteSnapshot(contentID: "missing", favoritedAt: date("2026-08-16 11:00")),
            FavoriteSnapshot(contentID: "later", favoritedAt: date("2026-08-16 10:00")),
            FavoriteSnapshot(contentID: "yesterday", favoritedAt: date("2026-08-15 20:00"))
        ]

        let sections = FavoriteListPresentation.sections(records: records, content: content, now: date("2026-08-16 12:00"), calendar: calendar)

        XCTAssertEqual(sections.map(\.title), ["今天 · 8月16日", "昨天 · 8月15日"])
        XCTAssertEqual(sections[0].entries.map(\.id), ["later", "earlier"])
        XCTAssertEqual(sections.flatMap(\.entries).map(\.id), ["later", "earlier", "yesterday"])
    }

    func testFavoriteListIncludesMenuCardsAlongsideContentItems() {
        let content = [ContentItem.fixture(id: "content-01", thai: "สวัสดี", meaningZhHans: "你好")]
        let menuCards = [
            ThaiMenuCard(
                id: "thai-menu-pad-thai",
                category: "主食",
                thai: "ผัดไทย",
                meaningZhHans: "泰式炒河粉",
                audioID: "thai-menu-pad-thai",
                imageAssetID: "thai_menu_pad_thai",
                breakdown: ThaiMenuBreakdown(combinations: [], minimal: [])
            )
        ]
        let records = [
            FavoriteSnapshot(contentID: "content-01", favoritedAt: date("2026-08-16 08:00")),
            FavoriteSnapshot(contentID: "missing-id", favoritedAt: date("2026-08-16 09:00")),
            FavoriteSnapshot(contentID: "thai-menu-pad-thai", favoritedAt: date("2026-08-16 10:00")),
        ]

        let sections = FavoriteListPresentation.sections(
            records: records,
            content: content,
            menuCards: menuCards,
            now: date("2026-08-16 12:00"),
            calendar: calendar
        )

        XCTAssertEqual(sections.map(\.title), ["今天 · 8月16日"])
        XCTAssertEqual(sections[0].entries.map(\.id), ["thai-menu-pad-thai", "content-01"])
        guard sections[0].entries.count == 2 else {
            return XCTFail("Expected 2 entries")
        }

        let firstEntry = sections[0].entries[0]
        XCTAssertEqual(firstEntry.id, "thai-menu-pad-thai")
        if case .menu(let card) = firstEntry.kind {
            XCTAssertEqual(card.thai, "ผัดไทย")
            XCTAssertEqual(card.meaningZhHans, "泰式炒河粉")
        } else {
            XCTFail("Expected first entry to be a menu card")
        }

        let secondEntry = sections[0].entries[1]
        XCTAssertEqual(secondEntry.id, "content-01")
        if case .content(let item) = secondEntry.kind {
            XCTAssertEqual(item.thai, "สวัสดี")
        } else {
            XCTFail("Expected second entry to be content item")
        }
    }
}


