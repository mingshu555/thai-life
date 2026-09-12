import SwiftUI

/// Thai text display with tap-to-play audio and VoiceOver accessibility.
/// No speaker icon or helper text — entire text shape is tappable.
struct ThaiText: View {
    let thai: String
    let romanization: String?
    let meaning: String?
    let audioID: String
    let showMeaning: Bool
    let fontSize: CGFloat

    @EnvironmentObject private var audioService: AudioPlaybackServiceWrapper

    init(
        thai: String,
        romanization: String? = nil,
        meaning: String? = nil,
        audioID: String,
        showMeaning: Bool = false,
        fontSize: CGFloat = 28
    ) {
        self.thai = thai
        self.romanization = romanization
        self.meaning = meaning
        self.audioID = audioID
        self.showMeaning = showMeaning
        self.fontSize = fontSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(thai)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(ThaiLifeTheme.textPrimary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            if showMeaning, let meaning = meaning {
                Text(meaning)
                    .font(.system(size: fontSize * 0.55))
                    .foregroundColor(ThaiLifeTheme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            _ = audioService.service.play(audioID: audioID, thaiText: thai)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(thai)
        .accessibilityHint("播放泰文发音")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "播放泰文发音") {
            _ = audioService.service.play(audioID: audioID, thaiText: thai)
        }
    }
}

// MARK: - Typography scales

enum CourseListTypography {
    /// Current list Thai size was 22pt; 29pt is approximately +30%.
    static let itemThaiFontSize: CGFloat = 29
    static let exampleFontSize: CGFloat = 16
    static let metadataFontSize: CGFloat = 14
}

enum ReviewCardTypography {
    static let frontThaiScale: CGFloat = 1.15
    static let answerThaiScale: CGFloat = 1.05
    static let answerThaiMinimum: CGFloat = 34
    static let answerMeaningScale: CGFloat = 0.8
    static let answerMeaningMinimum: CGFloat = 28
    static let usageFontSize: CGFloat = 18
    static let exampleFontSize: CGFloat = 18
    static let exampleMeaningFontSize: CGFloat = 16
    static let sectionLabelFontSize: CGFloat = 16
    static let segmentThaiFontSize: CGFloat = 18
    static let segmentGlossFontSize: CGFloat = 16
    static let continuationFontSize: CGFloat = 16
    static let ratingFontSize: CGFloat = 18
}

// MARK: - ThaiText Sizing

struct ThaiTextLayout {
    let fontSize: CGFloat
    let lineCount: Int
    let requiresContinuation: Bool
}

enum ThaiTextSizing {
    /// Preferred size for short Thai words and phrases on review cards.
    static let preferredFontSize: CGFloat = 40

    /// Minimum readable size used only when longer text needs to shrink.
    static let minimumFontSize: CGFloat = 30

    /// Calculate font size for available width. Returns requiresContinuation if text won't fit.
    static func font(for thai: String, availableWidth: CGFloat, maxLines: Int = 6) -> ThaiTextLayout {
        let baseFont = UIFont.systemFont(ofSize: preferredFontSize)
        let baseSize = (thai as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: baseFont],
            context: nil
        )

        let lineCount = Int(ceil(baseSize.height / baseFont.lineHeight))

        if lineCount <= maxLines && baseSize.width <= availableWidth * CGFloat(maxLines) {
            return ThaiTextLayout(fontSize: preferredFontSize, lineCount: lineCount, requiresContinuation: false)
        }

        // Try reducing font size
        for size in stride(from: preferredFontSize - 2, through: minimumFontSize, by: -2) {
            let font = UIFont.systemFont(ofSize: size)
            let bounds = (thai as NSString).boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let lines = Int(ceil(bounds.height / font.lineHeight))

            if lines <= maxLines {
                return ThaiTextLayout(fontSize: size, lineCount: lines, requiresContinuation: false)
            }
        }

        return ThaiTextLayout(fontSize: minimumFontSize, lineCount: maxLines, requiresContinuation: true)
    }
}

// MARK: - Environment wrapper for ObservableObject compatibility

final class AudioPlaybackServiceWrapper: ObservableObject {
    let service: AudioPlaybackService

    init(service: AudioPlaybackService) {
        self.service = service
    }
}

// MARK: - Preview

#if DEBUG
struct ThaiText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ThaiText(
                thai: "สวัสดีครับ",
                romanization: "sà-wàt-dii khráp",
                meaning: "你好（男性）",
                audioID: "audio-basics-word-001",
                showMeaning: true
            )
            ThaiText(
                thai: "ขอบคุณมากครับ",
                meaning: "非常感谢",
                audioID: "audio-basics-chunk-001",
                showMeaning: true
            )
        }
        .padding()
        .background(ThaiLifeTheme.warmWhite)
        .environmentObject(AudioPlaybackServiceWrapper(service: AudioPlaybackService()))
    }
}
#endif
