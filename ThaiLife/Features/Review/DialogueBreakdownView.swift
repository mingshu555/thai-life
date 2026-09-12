import SwiftUI

enum DialogueBreakdownPresentation {
    static func turns(
        for item: ContentItem,
        isBrowsing: Bool,
        continuationPart: Int
    ) -> [DialogueTurn] {
        guard item.kind == .dialogue, let turns = item.dialogueBreakdown else { return [] }
        if isBrowsing { return turns }
        guard turns.indices.contains(continuationPart) else { return [] }
        return [turns[continuationPart]]
    }
}

struct DialogueBreakdownView: View {
    let item: ContentItem
    let isBrowsing: Bool
    let continuationPart: Int
    let onTapSegment: (PhraseSegment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(DialogueBreakdownPresentation.turns(
                for: item,
                isBrowsing: isBrowsing,
                continuationPart: continuationPart
            ).enumerated()), id: \.offset) { _, turn in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(turn.speaker): \(turn.thai)")
                        .font(.system(size: ReviewCardTypography.exampleFontSize, weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                    Text(turn.meaningZhHans)
                        .font(.system(size: ReviewCardTypography.exampleMeaningFontSize))
                        .foregroundColor(ThaiLifeTheme.textTertiary)
                    ForEach(Array(turn.segments.enumerated()), id: \.offset) { _, segment in
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
