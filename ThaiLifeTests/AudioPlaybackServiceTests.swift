import AVFAudio
@testable import ThaiLife
import XCTest

private final class MockStartedAudioPlayer: AudioPlayerProtocol {
    var delegate: AVAudioPlayerDelegate?
    func prepareToPlay() -> Bool { true }
    func play() -> Bool { true }
    func stop() {}
}

private final class MockFailedAudioPlayer: AudioPlayerProtocol {
    var delegate: AVAudioPlayerDelegate?
    func prepareToPlay() -> Bool { true }
    func play() -> Bool { false }
    func stop() {}
}

@MainActor
final class AudioPlaybackServiceTests: XCTestCase {
    var service: AudioPlaybackService!

    override func setUp() {
        service = AudioPlaybackService()
    }

    override func tearDown() {
        service.stop()
        service = nil
    }

    // MARK: - Unavailable when no audio & no thaiText

    func testMissingThaiTextWithMissingAudioReturnsUnavailable() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })
        let result = service.play(audioID: "nonexistent-audio-id", thaiText: nil)
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(service.lastPlaybackSource, .none)
    }

    func testEmptyThaiTextWithMissingAudioReturnsUnavailable() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })
        let result = service.play(audioID: "nonexistent-audio-id", thaiText: "")
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(service.lastPlaybackSource, .none)
    }

    // MARK: - Main word strategy tests

    func testValidMainWordMP3UsesBundleAudio() {
        let mockPlayer = MockStartedAudioPlayer()
        let service = AudioPlaybackService(
            audioURLResolver: { _ in URL(fileURLWithPath: "/tmp/bundled-word.mp3") },
            audioPlayerFactory: { _ in mockPlayer }
        )
        let result = service.play(audioID: "audio-numbers-word-007", thaiText: "หก")
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "audio-numbers-word-007"))
    }

    func testMissingMainWordMP3FallsBackToTTS() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })
        let result = service.play(audioID: "nonexistent-word-999", thaiText: "ทดสอบ")
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "ทดสอบ"))
    }

    func testUndecodableMainWordMP3FallsBackToTTS() throws {
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("invalid_\(UUID().uuidString).mp3")
        try "invalid content".write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }

        let service = AudioPlaybackService(audioURLResolver: { _ in tempFileURL })
        let result = service.play(audioID: "corrupt-word", thaiText: "ทดสอบ")
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "ทดสอบ"))
    }

    func testMainWordAsyncDecodeErrorTriggersTTSFallback() {
        let mockPlayer = MockStartedAudioPlayer()
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.mp3")
        let service = AudioPlaybackService(
            audioURLResolver: { _ in dummyURL },
            audioPlayerFactory: { _ in mockPlayer }
        )

        let result = service.play(audioID: "audio-numbers-word-007", thaiText: "หก")
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "audio-numbers-word-007"))

        service.handleAudioPlayerDecodeError(mockPlayer)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "หก"))
    }

    // MARK: - Restarted & switching contracts

    func testReplayingSameAudioReturnsRestartedContract() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })
        let result1 = service.play(audioID: "test-id", thaiText: "สวัสดี")
        XCTAssertEqual(result1, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "สวัสดี"))

        let result2 = service.play(audioID: "test-id", thaiText: "สวัสดี")
        XCTAssertEqual(result2, .restarted)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "สวัสดี"))
    }

    func testReplayingSameAudioWhenPlayerPlayFailsReturnsRestarted() {
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.mp3")
        let service = AudioPlaybackService(
            audioURLResolver: { _ in dummyURL },
            audioPlayerFactory: { _ in MockFailedAudioPlayer() }
        )

        let result1 = service.play(audioID: "same-id", thaiText: "สวัสดี")
        XCTAssertEqual(result1, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "สวัสดี"))

        let result2 = service.play(audioID: "same-id", thaiText: "สวัสดี")
        XCTAssertEqual(result2, .restarted)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "สวัสดี"))
    }

    func testPlayingDifferentAudioReturnsStarted() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })
        let result1 = service.play(audioID: "test-id-1", thaiText: "สวัสดี")
        XCTAssertEqual(result1, .started)

        let result2 = service.play(audioID: "test-id-2", thaiText: "ขอบคุณ")
        XCTAssertEqual(result2, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "ขอบคุณ"))
    }

    func testStalePlayerDecodeErrorIsIgnoredAfterNewPlay() {
        let mockPlayer1 = MockStartedAudioPlayer()
        let mockPlayer2 = MockStartedAudioPlayer()
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.mp3")
        var factoryCallCount = 0

        let service = AudioPlaybackService(
            audioURLResolver: { _ in dummyURL },
            audioPlayerFactory: { _ in
                factoryCallCount += 1
                return factoryCallCount == 1 ? mockPlayer1 : mockPlayer2
            }
        )

        _ = service.play(audioID: "word-1", thaiText: "หนึ่ง")
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "word-1"))

        _ = service.play(audioID: "word-2", thaiText: "สอง")
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "word-2"))

        // Stale decode error from player 1
        service.handleAudioPlayerDecodeError(mockPlayer1)
        // Must stay on word-2 bundle playback and NOT trigger TTS for word-1
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "word-2"))
    }

    func testStalePlayerDecodeErrorIsIgnoredAfterUserStop() {
        let mockPlayer = MockStartedAudioPlayer()
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.mp3")
        let service = AudioPlaybackService(
            audioURLResolver: { _ in dummyURL },
            audioPlayerFactory: { _ in mockPlayer }
        )

        _ = service.play(audioID: "word-1", thaiText: "หนึ่ง")
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "word-1"))

        service.stop()

        service.handleAudioPlayerDecodeError(mockPlayer)
        XCTAssertEqual(service.lastPlaybackSource, .none)
    }

    func testStaleTTSCompletionIsIgnoredAfterSwitchingToBundlePlayer() {
        let mockPlayerB = MockStartedAudioPlayer()
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.mp3")
        let service = AudioPlaybackService(
            audioURLResolver: { id in id == "word-b" ? dummyURL : nil },
            audioPlayerFactory: { _ in mockPlayerB }
        )

        // 1. Word A (missing MP3) starts TTS utterance A
        let resultA = service.play(audioID: "word-a", thaiText: "ข้อ A")
        XCTAssertEqual(resultA, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "ข้อ A"))

        let utteranceA = AVSpeechUtterance(string: "ข้อ A")

        // 2. User immediately taps Word B (has bundle MP3)
        let resultB = service.play(audioID: "word-b", thaiText: "ข้อ B")
        XCTAssertEqual(resultB, .started)
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "word-b"))

        // 3. Stale didCancel/didFinish for Utterance A arrives late
        service.handleSpeechSynthesizerCompletion(for: utteranceA)

        // 4. Verify B's bundle source, playing state, and context are preserved
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "word-b"))

        // 5. Trigger B decode error: must still fall back to B's TTS
        service.handleAudioPlayerDecodeError(mockPlayerB)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "ข้อ B"))
    }

    func testStaleTTSCompletionIsIgnoredAfterSwitchingToNewTTS() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })

        _ = service.play(audioID: "word-a", thaiText: "ข้อ A")
        let utteranceA = AVSpeechUtterance(string: "ข้อ A")

        _ = service.play(audioID: "word-b", thaiText: "ข้อ B")
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "ข้อ B"))

        // Stale completion for A
        service.handleSpeechSynthesizerCompletion(for: utteranceA)

        // Must stay on word-b TTS
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "ข้อ B"))
    }
}

@MainActor
final class SegmentAudioIDTests: XCTestCase {
    func testSegmentAudioIDUsesTheStableNormalizedThaiHash() {
        XCTAssertEqual(
            SegmentAudioID.audioID(for: "  สวัสดี  "),
            "audio-segment-4ad434bd60c467ad71c61029edf3a84f65dc5ec5742aa0c0dc2afaa1e226198a"
        )
        XCTAssertEqual(
            SegmentAudioID.audioID(for: "ไม่เป็นไร"),
            "audio-segment-d65362a11e13c2a57f2e66518d64b3d4d7c247b7f0e26e9349f8a1a9eabed756"
        )
    }

    func testSegmentPlaybackUsesOnlyTheSegmentAudioIDAndText() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })

        XCTAssertEqual(service.playSegment(PhraseSegment(thai: "สวัสดี", gloss: "你好")), .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "สวัสดี"))
    }
}

final class ThaiSpeechTextTests: XCTestCase {
    func testFullSentenceNormalizesWhitespaceAndAddsSentenceBoundary() {
        XCTAssertEqual(
            ThaiSpeechText.fullSentence("  เมื่อคืน   นอนหลับดีไหมครับ  "),
            "เมื่อคืน นอนหลับดีไหมครับ。"
        )
    }

    func testFullSentenceKeepsExistingSentencePunctuation() {
        XCTAssertEqual(
            ThaiSpeechText.fullSentence("สวัสดีครับ สบายดีไหมครับ。"),
            "สวัสดีครับ。 สบายดีไหมครับ。"
        )
    }
}

@MainActor
final class ExampleSentencePlaybackTests: XCTestCase {
    var service: AudioPlaybackService!

    override func setUp() {
        service = AudioPlaybackService()
    }

    override func tearDown() {
        service.stop()
        service = nil
    }

    func testExampleSentencePlaybackPrioritizesExampleMP3() {
        let mockPlayer = MockStartedAudioPlayer()
        let service = AudioPlaybackService(
            audioURLResolver: { _ in URL(fileURLWithPath: "/tmp/bundled-example.mp3") },
            audioPlayerFactory: { _ in mockPlayer }
        )
        let result = service.playSentence(
            audioID: "audio-basics-word-022-example",
            text: "เมื่อคืน นอนหลับดีไหมครับ"
        )
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "audio-basics-word-022-example"))
    }

    func testExampleSentencePlaybackMissingMP3FallsBackToTTS() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })
        let result = service.playSentence(
            audioID: "nonexistent-example",
            text: "เมื่อคืน นอนหลับดีไหมครับ"
        )
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "เมื่อคืน นอนหลับดีไหมครับ。"))
    }

    func testExampleSentencePlaybackCorruptMP3FallsBackToNormalizedTTS() throws {
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("invalid_\(UUID().uuidString).mp3")
        try "invalid content".write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }

        let service = AudioPlaybackService(audioURLResolver: { _ in tempFileURL })
        let result = service.playSentence(
            audioID: "corrupt-example",
            text: "  เมื่อคืน   นอนหลับดีไหมครับ  "
        )
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "เมื่อคืน นอนหลับดีไหมครับ。"))
    }

    func testExampleSentenceAsyncDecodeErrorTriggersNormalizedTTSFallback() {
        let mockPlayer = MockStartedAudioPlayer()
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.mp3")
        let service = AudioPlaybackService(
            audioURLResolver: { _ in dummyURL },
            audioPlayerFactory: { _ in mockPlayer }
        )

        let result = service.playSentence(
            audioID: "audio-basics-word-022-example",
            text: "  เมื่อคืน   นอนหลับดีไหมครับ  "
        )
        XCTAssertEqual(result, .started)
        XCTAssertEqual(service.lastPlaybackSource, .bundle(audioID: "audio-basics-word-022-example"))

        service.handleAudioPlayerDecodeError(mockPlayer)
        XCTAssertEqual(service.lastPlaybackSource, .tts(text: "เมื่อคืน นอนหลับดีไหมครับ。"))
    }

    func testExampleSentencePlaybackWithoutTextAndMissingMP3IsUnavailable() {
        let service = AudioPlaybackService(audioURLResolver: { _ in nil })
        let result = service.playSentence(
            audioID: "nonexistent-example",
            text: nil
        )
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(service.lastPlaybackSource, .none)
    }
}
