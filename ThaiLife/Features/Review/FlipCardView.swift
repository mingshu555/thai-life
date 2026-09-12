import SwiftUI

/// Text shown on the answer side of a review card.
///
/// A word card's segments describe its example sentence; they are not a
/// continuation of the headword. Only content without an example may use
/// segments for continuation layout.
enum ReviewCardText {
    static func displayedThai(
        for item: ContentItem,
        isContinuation: Bool,
        continuationPart: Int,
        isBrowsing: Bool = false
    ) -> String {
        if isBrowsing {
            return item.thai
        }
        if item.kind == .dialogue {
            let lines = item.thai.components(separatedBy: "\n").filter { !$0.isEmpty }
            if continuationPart < lines.count {
                return lines[continuationPart]
            }
            return item.thai
        }

        // A normal sentence has one complete answer side. Its segments are
        // tappable breakdown blocks, not separate answer-card text.
        if item.kind == .sentence, !isContinuation {
            return item.thai
        }

        guard item.example?.isEmpty ?? true, !item.segments.isEmpty else {
            return item.thai
        }

        let mid = item.segments.count / 2
        if isContinuation && continuationPart == 1 {
            return item.segments.suffix(item.segments.count - mid).map(\.thai).joined()
        }
        if !isContinuation {
            return item.segments.prefix(mid).map(\.thai).joined()
        }
        return item.thai
    }
}

enum FlipCardGestureAction: Equatable {
    case flip
    case next
    case previous
    case reset

    static func resolve(translation: CGSize, canGoPrevious: Bool, canGoNext: Bool, threshold: CGFloat = 80) -> Self {
        if translation.width < -threshold { return canGoNext ? .next : .reset }
        if translation.width > threshold { return canGoPrevious ? .previous : .reset }
        return .reset
    }
}

struct FlipCardView: View {
    let item: ContentItem
    let isFlipped: Bool
    let direction: String
    let isContinuation: Bool
    let continuationPart: Int  // 0 = first part, 1 = second part
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isBrowsing: Bool
    let onTapThai: () -> Void
    let onTapExample: () -> Void
    let onTapSegment: (PhraseSegment) -> Void
    let onFlip: () -> Void
    let onRate: (String) -> Void
    let onSwipeNext: () -> Void
    let onSwipePrevious: () -> Void

    init(
        item: ContentItem,
        isFlipped: Bool,
        direction: String,
        isContinuation: Bool,
        continuationPart: Int,
        canGoPrevious: Bool,
        canGoNext: Bool = true,
        isBrowsing: Bool = false,
        onTapThai: @escaping () -> Void,
        onTapExample: @escaping () -> Void,
        onTapSegment: @escaping (PhraseSegment) -> Void,
        onFlip: @escaping () -> Void,
        onRate: @escaping (String) -> Void,
        onSwipeNext: @escaping () -> Void,
        onSwipePrevious: @escaping () -> Void
    ) {
        self.item = item
        self.isFlipped = isFlipped
        self.direction = direction
        self.isContinuation = isContinuation
        self.continuationPart = continuationPart
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.isBrowsing = isBrowsing
        self.onTapThai = onTapThai
        self.onTapExample = onTapExample
        self.onTapSegment = onTapSegment
        self.onFlip = onFlip
        self.onRate = onRate
        self.onSwipeNext = onSwipeNext
        self.onSwipePrevious = onSwipePrevious
    }

    @State private var dragOffset: CGSize = .zero

    private let swipeThreshold: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let layout = ThaiTextSizing.font(
                    for: isFlipped ? item.thai : cueText,
                    availableWidth: geo.size.width - 48,
                    maxLines: 8
                )

                ZStack {
                    if !isFlipped {
                        CardFront(
                            item: item,
                            direction: direction,
                            fontSize: layout.fontSize,
                            onTapThai: onTapThai
                        )
                    } else {
                        CardBack(
                            item: item,
                            layout: layout,
                            continuationPart: continuationPart,
                            isContinuation: isContinuation,
                            isBrowsing: isBrowsing,
                            onTapThai: onTapThai,
                            onTapExample: onTapExample,
                            onTapSegment: onTapSegment,
                            onRate: onRate
                        )
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ThaiLifeTheme.cardWhite)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                // Card tilt and offset when swiping like a playing card
                .offset(x: dragOffset.width, y: dragOffset.height)
                .rotationEffect(.degrees(Double(dragOffset.width / 15)))
                // 180-degree 3D flip effect
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
                .contentShape(Rectangle())
                .gesture(cardGesture, including: .gesture)
            }

            if isContinuation {
                Text("（接上段）")
                    .font(.system(size: ReviewCardTypography.continuationFontSize))
                    .foregroundColor(ThaiLifeTheme.paleGreen)
                    .padding(.top, 2)
            }
        }
    }

    private var cardGesture: some Gesture {
        let drag = DragGesture(minimumDistance: 10)
            .onChanged { dragOffset = $0.translation }
        return TapGesture().exclusively(before: drag).onEnded { value in
            switch value {
            case .first:
                onFlip()
            case .second(let dragValue):
                switch FlipCardGestureAction.resolve(
                    translation: dragValue.translation,
                    canGoPrevious: canGoPrevious,
                    canGoNext: canGoNext,
                    threshold: swipeThreshold
                ) {
                case .next:
                    dragOffset = .zero
                    onSwipeNext()
                case .previous:
                    dragOffset = .zero
                    onSwipePrevious()
                case .flip, .reset:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { dragOffset = .zero }
                }
            }
        }
    }

    private var cueText: String {
        switch direction {
        case "thai→zh": return item.thai
        case "zh→thai": return item.meaningZhHans
        default: return item.thai
        }
    }
}

// MARK: - Card Front (cue only)

struct CardFront: View {
    let item: ContentItem
    let direction: String
    let fontSize: CGFloat
    let onTapThai: () -> Void

    private var isThaiCue: Bool {
        direction == "thai→zh"
    }

    private var cueText: String {
        switch direction {
        case "thai→zh": return item.thai
        case "zh→thai": return item.meaningZhHans
        default: return item.thai
        }
    }

    private var cueTextView: some View {
        Text(cueText)
            .font(.system(size: fontSize * ReviewCardTypography.frontThaiScale, weight: .bold))
            .foregroundColor(ThaiLifeTheme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.vertical, 6)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Group {
                if isThaiCue {
                    Button(action: onTapThai) { cueTextView }
                        .buttonStyle(.plain)
                } else {
                    cueTextView
                }
            }

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Card Back (full answer)

struct CardBack: View {
    let item: ContentItem
    let layout: ThaiTextLayout
    let continuationPart: Int
    let isContinuation: Bool
    let isBrowsing: Bool
    let onTapThai: () -> Void
    let onTapExample: () -> Void
    let onTapSegment: (PhraseSegment) -> Void
    let onRate: (String) -> Void

    private var displayedThai: String {
        ReviewCardText.displayedThai(
            for: item,
            isContinuation: isContinuation,
            continuationPart: continuationPart,
            isBrowsing: isBrowsing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Thai text (tap to pronounce)
                    Button(action: onTapThai) {
                        Text(displayedThai)
                            .font(.system(size: max(layout.fontSize * ReviewCardTypography.answerThaiScale, ReviewCardTypography.answerThaiMinimum), weight: .bold))
                            .foregroundColor(ThaiLifeTheme.textPrimary)
                            .lineSpacing(8)
                    }
                    .buttonStyle(.plain)

                    // Continuation warning
                    if layout.requiresContinuation {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: ReviewCardTypography.sectionLabelFontSize))
                            Text("此内容已拆分为连续卡片")
                                .font(.system(size: ReviewCardTypography.sectionLabelFontSize))
                        }
                        .foregroundColor(ThaiLifeTheme.warning)
                        .padding(.vertical, 4)
                    }

                    // Chinese meaning
                    Text(item.meaningZhHans)
                        .font(.system(size: max(layout.fontSize * ReviewCardTypography.answerMeaningScale, ReviewCardTypography.answerMeaningMinimum), weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.deepGreen)

                    // Usage note
                    if let note = item.usageNote, !note.isEmpty {
                        Text(note)
                            .font(.system(size: ReviewCardTypography.usageFontSize))
                            .foregroundColor(ThaiLifeTheme.textTertiary)
                    }

                    // Dialogue, chunk/word dual-layer breakdown, example, then example segments.
                    if item.kind == .dialogue {
                        DialogueBreakdownView(
                            item: item,
                            isBrowsing: isBrowsing,
                            continuationPart: continuationPart,
                            onTapSegment: onTapSegment
                        )
                    } else {
                        if let example = item.example, !example.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("例句")
                                    .font(.system(size: ReviewCardTypography.sectionLabelFontSize, weight: .bold))
                                    .foregroundColor(ThaiLifeTheme.textTertiary)
                                Button(action: onTapExample) {
                                    Text(example)
                                        .font(.system(size: ReviewCardTypography.exampleFontSize))
                                        .foregroundColor(ThaiLifeTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                                if let exampleMeaning = item.displayExampleMeaning, !exampleMeaning.isEmpty {
                                    Text(exampleMeaning)
                                        .font(.system(size: ReviewCardTypography.exampleMeaningFontSize))
                                        .foregroundColor(ThaiLifeTheme.textTertiary)
                                }
                            }
                        }

                        if CardBackExtraContent.showsExampleSegmentList(item) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("词块拆解")
                                    .font(.system(size: ReviewCardTypography.sectionLabelFontSize, weight: .bold))
                                    .foregroundColor(ThaiLifeTheme.textTertiary)

                                ForEach(Array(CardBackExtraContent.exampleSegmentsToDisplay(for: item).enumerated()), id: \.offset) { _, segment in
                                    HStack(spacing: 8) {
                                        Button(action: { onTapSegment(segment) }) {
                                            Text(segment.thai)
                                                .font(.system(size: ReviewCardTypography.segmentThaiFontSize, weight: .bold))
                                                .foregroundColor(ThaiLifeTheme.deepGreen)
                                        }
                                        .buttonStyle(.plain)
                                        Text(segment.gloss)
                                            .font(.system(size: ReviewCardTypography.segmentGlossFontSize))
                                            .foregroundColor(ThaiLifeTheme.textTertiary)
                                    }
                                }
                            }
                        }

                        if CardBackExtraContent.showsHeadwordBreakdown(item) {
                            ChunkBreakdownView(item: item, onTapSegment: onTapSegment)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .frame(maxHeight: .infinity)

            // Rating buttons (or continuation button) - hidden in browse mode
            if !isBrowsing {
                VStack(spacing: 0) {
                    Divider()
                    if isContinuation {
                        Button(action: { onRate("") }) {
                            Text("继续 →")
                                .font(.system(size: ReviewCardTypography.ratingFontSize, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(ThaiLifeTheme.paleGreen)
                        }
                    } else {
                        HStack(spacing: 0) {
                            RatingButton(title: "重来", color: ThaiLifeTheme.ratingAgain, action: { onRate("again") })
                            RatingButton(title: "困难", color: ThaiLifeTheme.ratingHard, action: { onRate("hard") })
                            RatingButton(title: "记得", color: ThaiLifeTheme.ratingGood, action: { onRate("good") })
                            RatingButton(title: "简单", color: ThaiLifeTheme.ratingEasy, action: { onRate("easy") })
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Rating Button

struct RatingButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: ReviewCardTypography.ratingFontSize, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
        }
    }
}
