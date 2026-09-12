@testable import ThaiLife
import XCTest
import AVFAudio
import CryptoKit

final class AudioAssetManifestTests: XCTestCase {

    private var resourceBundle: Bundle {
        for b in Bundle.allBundles {
            if b.url(forResource: "items", withExtension: "json", subdirectory: "Content") != nil ||
               b.url(forResource: "items", withExtension: "json") != nil {
                return b
            }
        }
        return Bundle.main
    }

    private func audioURL(for audioID: String) -> URL? {
        let b = resourceBundle
        return b.url(forResource: audioID, withExtension: "mp3", subdirectory: "Audio") ??
               b.url(forResource: audioID, withExtension: "mp3")
    }

    func testEveryContentItemHasBundledAudio() throws {
        for item in try ContentRepository.loadBundled() {
            XCTAssertNotNil(
                audioURL(for: item.audioID),
                "Missing audio for \(item.id): \(item.audioID)"
            )
        }
    }

    func testEveryIndependentlyPlayableSegmentHasBundledAudio() throws {
        let items = try ContentRepository.loadBundled()
        let segmentIDs = Set(items.flatMap { item -> [String] in
            var segments = item.segments
            if let breakdown = item.chunkBreakdown {
                segments += breakdown.combinations + breakdown.minimal
            }
            for turn in item.dialogueBreakdown ?? [] {
                segments += turn.segments
            }
            return segments.compactMap { segment in
                segment.thai.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : SegmentAudioID.audioID(for: segment.thai)
            }
        })

        XCTAssertFalse(segmentIDs.isEmpty)
        for audioID in segmentIDs {
            XCTAssertNotNil(audioURL(for: audioID), "Missing segment audio: \(audioID)")
        }
    }

    func testAudioFilesAreDecodable() throws {
        let items = try ContentRepository.loadBundled()
        let sampleIDs = Array(items.map(\.audioID).shuffled().prefix(20))
        for audioID in sampleIDs {
            guard let url = audioURL(for: audioID) else {
                XCTFail("Missing audio: \(audioID)")
                continue
            }
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 100, "Audio \(audioID) too small: \(data.count) bytes")
            guard let player = try? AVAudioPlayer(contentsOf: url) else {
                XCTFail("Audio \(audioID) not decodable")
                continue
            }
            XCTAssertGreaterThan(player.duration, 0, "Audio \(audioID) has zero duration")
        }
    }

    func testAudioNotAllIdentical() throws {
        let items = try ContentRepository.loadBundled()
        var seenHashes = Set<String>()
        var duplicateCount = 0
        let sample = Array(items.prefix(50))
        for item in sample {
            guard let url = audioURL(for: item.audioID) else { continue }
            let data = try Data(contentsOf: url)
            let hash = Data.sha256Hash(data)
            if seenHashes.contains(hash) { duplicateCount += 1 }
            seenHashes.insert(hash)
        }
        XCTAssertLessThan(duplicateCount, 25, "Too many identical audio files (\(duplicateCount)/50)")
    }

    // MARK: - Pure-tone placeholder detection

    /// Detect pure-tone (sine-wave) placeholder MP3s by analysing short-time
    /// energy variability. Real speech has syllable-driven amplitude variation;
    /// synthetic pure tones have near-constant energy across all time windows.
    func testBaseNumberTenAndElevenAudioAreNotTruncated() throws {
        let expectedMinimumDuration: [String: TimeInterval] = [
            "audio-numbers-word-011": 0.9,
            "audio-numbers-chunk-001": 0.9
        ]

        for (audioID, minimumDuration) in expectedMinimumDuration {
            guard let url = audioURL(for: audioID) else {
                XCTFail("Missing audio: \(audioID)")
                continue
            }
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(
                player.duration,
                minimumDuration,
                "\(audioID) should contain a complete natural pronunciation"
            )
        }
    }

    func testAudioFilesAreNotPureTonePlaceholders() throws {
        let items = try ContentRepository.loadBundled()
        let sample = Array(items.shuffled().prefix(30))
        var pureToneCount = 0

        for item in sample {
            guard let url = audioURL(for: item.audioID) else { continue }
            if isSuspiciouslyUniformEnergy(url: url) {
                pureToneCount += 1
            }
        }

        XCTAssertEqual(pureToneCount, 0,
            "\(pureToneCount)/\(sample.count) sampled audio files have near-constant energy " +
            "(characteristic of pure-tone placeholders, not real speech). " +
            "Replace these files with actual Thai speech recordings.")
    }

    /// Returns `true` when the audio at `url` exhibits energy uniformity
    /// consistent with a synthetic pure tone rather than natural speech.
    private func isSuspiciouslyUniformEnergy(url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else { return true }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0 else { return true }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return true
        }
        do {
            try file.read(into: buffer)
        } catch {
            return true
        }

        guard let channelData = buffer.floatChannelData?[0] else { return true }
        let samples = UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength))
        guard samples.count >= 100 else { return true }

        // Compute RMS energy per ~10ms window, then measure CV.
        let sampleRate = Int(format.sampleRate)
        let windowSize = max(sampleRate / 100, 64) // ~10ms, min 64 samples
        var windowEnergies: [Float] = []

        for start in stride(from: 0, to: samples.count - windowSize, by: windowSize) {
            var sumSq: Float = 0
            for i in start..<(start + windowSize) {
                sumSq += samples[i] * samples[i]
            }
            windowEnergies.append(sqrt(sumSq / Float(windowSize)))
        }

        guard windowEnergies.count >= 3 else { return true }

        let mean = windowEnergies.reduce(0, +) / Float(windowEnergies.count)
        guard mean > 0.0001 else { return true } // near-silence → suspicious

        let variance = windowEnergies.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(windowEnergies.count)
        let cv = sqrt(variance) / mean

        // Pure sine waves: CV < 0.12.  Real speech: CV typically > 0.25.
        return cv < 0.12
    }
}

extension Data {
    static func sha256Hash(_ data: Data) -> String {
        var hasher = CryptoKit.SHA256()
        hasher.update(data: data)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
