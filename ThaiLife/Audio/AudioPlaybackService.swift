import AVFAudio
import CryptoKit
import Foundation

enum SegmentAudioID {
    static func normalizedThai(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func audioID(for text: String) -> String {
        let digest = SHA256.hash(data: Data(normalizedThai(text).utf8))
        return "audio-segment-" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum ThaiSpeechText {
    private static let terminalPunctuation = CharacterSet(charactersIn: ".!?。！？")

    /// Prepare one complete Thai example for a single TTS utterance.
    ///
    /// Examples are stored as sentences, while `segments` are only a visual
    /// word breakdown. Never synthesize one utterance per segment: doing that
    /// loses Thai prosody and makes the example sound like a word list.
    static func fullSentence(_ text: String) -> String {
        var sentence = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sentence.isEmpty else { return sentence }

        // A few authored examples contain two clauses separated by a space
        // after a sentence-final polite particle. Mark that boundary for TTS
        // without changing the text shown to the learner.
        sentence = sentence
            .replacingOccurrences(of: "ครับ ", with: "ครับ。 ")
            .replacingOccurrences(of: "ค่ะ ", with: "ค่ะ。 ")
            .replacingOccurrences(of: "คะ ", with: "คะ。 ")

        if sentence.unicodeScalars.last.map({ !terminalPunctuation.contains($0) }) ?? false {
            sentence.append("。")
        }
        return sentence
    }
}

protocol AudioPlayerProtocol: AnyObject {
    var delegate: AVAudioPlayerDelegate? { get set }
    @discardableResult func prepareToPlay() -> Bool
    @discardableResult func play() -> Bool
    func stop()
}

extension AVAudioPlayer: AudioPlayerProtocol {}

/// Plays Thai pronunciation from bundled Google Cloud TTS MP3s when available,
/// with the iOS Thai voice as a local fallback.
///
/// Example assets use the derived ID `<audioID>-example` and contain the whole
/// example sentence as one utterance. Segment data is never synthesized.
@MainActor
final class AudioPlaybackService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
    enum PlaybackResult: Equatable {
        /// New playback started (no prior audio was playing, or a different
        /// audioID was playing).
        case started
        /// The same audioID was currently playing and has been interrupted
        /// and restarted from the beginning.
        case restarted
        /// No thaiText was provided — nothing to pronounce.
        case unavailable
    }

    enum PlaybackSource: Equatable {
        case bundle(audioID: String)
        case tts(text: String)
        case none
    }

    private struct ActivePlaybackContext {
        let audioID: String
        let fallbackText: String?
    }

    typealias AudioURLResolver = (String) -> URL?
    typealias AudioPlayerFactory = (URL) throws -> AudioPlayerProtocol

    private(set) var lastPlaybackSource: PlaybackSource = .none
    private var currentAudioID: String?
    private var isCurrentlyPlaying: Bool = false
    private var desiredRate: Float = 1.0
    private var audioPlayer: AudioPlayerProtocol?
    private var activeFallbackContext: ActivePlaybackContext?
    private var currentUtterance: AVSpeechUtterance?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let audioURLResolver: AudioURLResolver
    private let audioPlayerFactory: AudioPlayerFactory

    init(
        bundle: Bundle = .main,
        audioURLResolver: AudioURLResolver? = nil,
        audioPlayerFactory: AudioPlayerFactory? = nil
    ) {
        self.audioURLResolver = audioURLResolver ?? { audioID in
            guard !audioID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return bundle.url(forResource: audioID, withExtension: "mp3", subdirectory: "Audio")
        }
        self.audioPlayerFactory = audioPlayerFactory ?? { url in
            try AVAudioPlayer(contentsOf: url)
        }
        super.init()
        speechSynthesizer.delegate = self
        activateAudioSession()
    }

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("AudioSession activation warning: \(error)")
        }
    }

    /// Play Thai headword or phrase pronunciation.
    ///
    /// First attempts to play bundled Google Cloud TTS MP3 (`Audio/<audioID>.mp3`).
    /// If missing, invalid format, or unplayable, falls back to a single complete `th-TH` AVSpeechUtterance.
    @discardableResult
    func play(audioID: String, thaiText: String? = nil) -> PlaybackResult {
        activateAudioSession()
        let wasPlayingSameAudio = currentAudioID == audioID && isCurrentlyPlaying
        if let result = playBundledAudio(audioID: audioID, fallbackText: thaiText, wasPlayingSameAudio: wasPlayingSameAudio) {
            return result
        }
        return playTTSFallback(audioID: audioID, text: thaiText, wasPlayingSameAudio: wasPlayingSameAudio)
    }

    /// Play one independently selectable visual segment. This intentionally does not
    /// use `playSentence`, so it never adds sentence prosody or concatenates segments.
    @discardableResult
    func playSegment(_ segment: PhraseSegment) -> PlaybackResult {
        play(audioID: SegmentAudioID.audioID(for: segment.thai), thaiText: segment.thai)
    }

    /// Play a complete example sentence from a bundled MP3 when available.
    /// Falls back to one normalized iOS TTS utterance when the asset is absent.
    @discardableResult
    func playSentence(audioID: String, text: String?) -> PlaybackResult {
        activateAudioSession()
        let wasPlayingSameAudio = currentAudioID == audioID && isCurrentlyPlaying
        let normalizedFallbackText = text.map { ThaiSpeechText.fullSentence($0) }
        guard let text, !text.isEmpty else {
            return playTTSFallback(audioID: audioID, text: nil, wasPlayingSameAudio: wasPlayingSameAudio)
        }

        if let result = playBundledAudio(audioID: audioID, fallbackText: normalizedFallbackText, wasPlayingSameAudio: wasPlayingSameAudio) {
            return result
        }
        return playTTSFallback(audioID: audioID, text: normalizedFallbackText, wasPlayingSameAudio: wasPlayingSameAudio)
    }

    private func playBundledAudio(audioID: String, fallbackText: String?, wasPlayingSameAudio: Bool) -> PlaybackResult? {
        guard !audioID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard let url = audioURLResolver(audioID) else {
            return nil
        }

        do {
            let player = try audioPlayerFactory(url)
            stopPlayback()
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { return nil }
            audioPlayer = player
            currentAudioID = audioID
            isCurrentlyPlaying = true
            activeFallbackContext = ActivePlaybackContext(audioID: audioID, fallbackText: fallbackText)
            lastPlaybackSource = .bundle(audioID: audioID)
            return wasPlayingSameAudio ? .restarted : .started
        } catch {
            print("Bundled audio playback warning for \(audioID): \(error)")
            return nil
        }
    }

    private func playTTSFallback(audioID: String, text: String?, wasPlayingSameAudio: Bool) -> PlaybackResult {
        stopPlayback()

        guard let text = text, !text.isEmpty else {
            lastPlaybackSource = .none
            return .unavailable
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = desiredRate * AVSpeechUtteranceDefaultSpeechRate
        currentUtterance = utterance
        speechSynthesizer.speak(utterance)
        currentAudioID = audioID
        isCurrentlyPlaying = true
        lastPlaybackSource = .tts(text: text)
        return wasPlayingSameAudio ? .restarted : .started
    }

    private func stopPlayback() {
        currentUtterance = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        currentAudioID = nil
        isCurrentlyPlaying = false
        activeFallbackContext = nil
        lastPlaybackSource = .none
    }

    /// Stop current audio playback.
    func stop() {
        stopPlayback()
    }

    /// Handle audio player decode error on MainActor.
    func handleAudioPlayerDecodeError(_ player: AudioPlayerProtocol, error: Error? = nil) {
        guard self.audioPlayer === player else { return }
        let context = activeFallbackContext
        stopPlayback()

        if let context, let text = context.fallbackText, !text.isEmpty {
            _ = playTTSFallback(audioID: context.audioID, text: text, wasPlayingSameAudio: false)
        }
    }

    /// Handle speech synthesizer completion/cancellation on MainActor.
    func handleSpeechSynthesizerCompletion(for utterance: AVSpeechUtterance) {
        guard self.currentUtterance === utterance else { return }
        self.currentUtterance = nil
        self.currentAudioID = nil
        self.isCurrentlyPlaying = false
        self.activeFallbackContext = nil
    }

    /// Set playback rate (1.0 = normal, 0.75 = slow).
    func setRate(_ rate: Float) {
        desiredRate = rate
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.handleSpeechSynthesizerCompletion(for: utterance)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.handleSpeechSynthesizerCompletion(for: utterance)
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.audioPlayer === player else { return }
            self.audioPlayer = nil
            self.currentAudioID = nil
            self.isCurrentlyPlaying = false
            self.activeFallbackContext = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.handleAudioPlayerDecodeError(player, error: error)
        }
    }
}
