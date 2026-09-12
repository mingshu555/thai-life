import SwiftUI

struct ChunkBreakdownSection: Equatable {
    let title: String
    let segments: [PhraseSegment]
}

enum ChunkBreakdownPresentation {
    static func sections(for item: ContentItem) -> [ChunkBreakdownSection] {
        let breakdown: ChunkBreakdown?
        switch item.kind {
        case .chunk:
            breakdown = item.chunkBreakdown
        case .word:
            breakdown = item.wordBreakdown
        default:
            breakdown = nil
        }
        guard let breakdown else { return [] }

        // Word cards already split the headword in 词块拆解 at combination
        // granularity. Combinations are a coarsening of minimal, so showing
        // both layers repeats the same Thai. Keep only the finest unique layer.
        if item.kind == .word {
            return [ChunkBreakdownSection(title: "最小拆解", segments: breakdown.minimal)]
        }
        return [
            ChunkBreakdownSection(title: "组合拆解", segments: breakdown.combinations),
            ChunkBreakdownSection(title: "最小拆解", segments: breakdown.minimal)
        ]
    }
}

enum CardBackExtraContent {
    static func showsHeadwordBreakdown(_ item: ContentItem) -> Bool {
        !ChunkBreakdownPresentation.sections(for: item).isEmpty
    }

    static func exampleSegmentsToDisplay(for item: ContentItem) -> [PhraseSegment] {
        let visible = item.segments.filter {
            !$0.thai.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard item.kind == .word, let breakdown = item.wordBreakdown else {
            return visible
        }
        let headwordPieces = Set(
            (breakdown.combinations + breakdown.minimal).map(\.thai)
        )
        return omittingHeadwordSpan(from: visible, combinations: breakdown.combinations)
            .filter { !headwordPieces.contains($0.thai) }
    }

    static func showsExampleSegmentList(_ item: ContentItem) -> Bool {
        guard item.kind != .chunk, item.kind != .dialogue else { return false }
        if item.kind == .word, item.wordBreakdown != nil {
            let hasExample = !(item.example?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            guard hasExample else { return false }
        }
        return !exampleSegmentsToDisplay(for: item).isEmpty
    }

    static func omittingHeadwordSpan(from segments: [PhraseSegment], combinations: [PhraseSegment]) -> [PhraseSegment] {
        let comboThai = combinations.map(\.thai)
        let count = comboThai.count
        guard count > 0, segments.count >= count else { return segments }
        for start in 0...(segments.count - count) {
            let end = start + count
            if segments[start..<end].map(\.thai) == comboThai {
                return Array(segments[..<start] + segments[end...])
            }
        }
        return segments
    }
}

struct ChunkBreakdownView: View {
    let item: ContentItem
    let onTapSegment: (PhraseSegment) -> Void

    init(item: ContentItem, onTapSegment: @escaping (PhraseSegment) -> Void = { _ in }) {
        self.item = item
        self.onTapSegment = onTapSegment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(ChunkBreakdownPresentation.sections(for: item).enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.system(size: ReviewCardTypography.sectionLabelFontSize, weight: .bold))
                        .foregroundColor(ThaiLifeTheme.textTertiary)
                    ForEach(Array(section.segments.enumerated()), id: \.offset) { _, segment in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
        }
    }
}
