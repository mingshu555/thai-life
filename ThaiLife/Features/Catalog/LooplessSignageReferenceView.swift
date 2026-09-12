import SwiftUI

private enum LooplessSignageFont {
    static let standard = "Sarabun-Regular"
    static let loopless = "Prompt-Regular"
}

struct LooplessSignageReferenceView: View {
    @State private var reference: LooplessSignageReference?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let reference {
                referencePage(reference)
            } else if let loadError {
                ContentUnavailableView("无头字资料加载失败", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ProgressView()
            }
        }
        .navigationTitle("泰国招牌无头字对照")
        .task { loadReference() }
    }

    @ViewBuilder
    private func referencePage(_ reference: LooplessSignageReference) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(reference.introductionZhHans)
                    .font(.body)
                    .foregroundColor(ThaiLifeTheme.textSecondary)
                    .padding(.horizontal)

                sectionTitle("高频字形对照")
                VStack(spacing: 0) {
                    ForEach(reference.glyphs) { glyph in
                        GlyphComparisonRow(glyph: glyph)
                        Divider()
                    }
                }
                .padding(.horizontal)

                sectionTitle("易混提醒")
                VStack(spacing: 12) {
                    ForEach(reference.confusionGroups) { group in
                        ConfusionGroupCard(group: group, glyphs: reference.glyphs)
                    }
                }
                .padding(.horizontal)

                sectionTitle("真实招牌例子")
                VStack(spacing: 16) {
                    ForEach(reference.scenes) { scene in
                        SceneReferenceCard(scene: scene)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(ThaiLifeTheme.warmWhite)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundColor(ThaiLifeTheme.deepGreen)
            .padding(.horizontal)
    }

    private func loadReference() {
        do { reference = try ContentRepository.loadLooplessSignageReference() }
        catch { loadError = error.localizedDescription }
    }
}

private struct GlyphComparisonRow: View {
    let glyph: LooplessGlyphEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 3) {
                Text(glyph.comparisonText)
                    .font(.custom(LooplessSignageFont.standard, size: 34, relativeTo: .title))
                    .foregroundColor(ThaiLifeTheme.textPrimary)
                Text("标准")
                    .font(.caption)
                    .foregroundColor(ThaiLifeTheme.textTertiary)
            }
            .frame(width: 82)

            Text("→")
                .foregroundColor(ThaiLifeTheme.textTertiary)

            VStack(spacing: 3) {
                Text(glyph.comparisonText)
                    .font(.custom(LooplessSignageFont.loopless, size: 34, relativeTo: .title))
                    .foregroundColor(ThaiLifeTheme.deepGreen)
                Text("无头")
                    .font(.caption)
                    .foregroundColor(ThaiLifeTheme.textTertiary)
            }
            .frame(width: 82)

            VStack(alignment: .leading, spacing: 3) {
                Text(glyph.thaiName)
                    .font(.caption.bold())
                    .foregroundColor(ThaiLifeTheme.textPrimary)
                Text(glyph.visualHintZhHans)
                    .font(.caption)
                    .foregroundColor(ThaiLifeTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct ConfusionGroupCard: View {
    let group: LooplessConfusionGroup
    let glyphs: [LooplessGlyphEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                ForEach(group.glyphIDs.compactMap { id in glyphs.first { $0.id == id } }) { glyph in
                    VStack(spacing: 2) {
                        Text(glyph.comparisonText)
                            .font(.custom(LooplessSignageFont.standard, size: 30, relativeTo: .title))
                        Text(glyph.comparisonText)
                            .font(.custom(LooplessSignageFont.loopless, size: 30, relativeTo: .title))
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                    }
                }
                Spacer()
            }
            Text(group.comparisonHintZhHans)
                .font(.subheadline)
                .foregroundColor(ThaiLifeTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThaiLifeTheme.cardWhite)
        .cornerRadius(12)
    }
}

private struct SceneReferenceCard: View {
    let scene: LooplessScene

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageAssetID = scene.imageAssetID,
               let url = ContentRepository.resourceBundle.url(forResource: imageAssetID, withExtension: "png", subdirectory: "LooplessSignage"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit().cornerRadius(10)
            }
            Text(scene.titleZhHans)
                .font(.headline)
                .foregroundColor(ThaiLifeTheme.deepGreen)

            VStack(alignment: .leading, spacing: 3) {
                Text(scene.thaiWord)
                    .font(.custom(LooplessSignageFont.loopless, size: 30, relativeTo: .title))
                    .foregroundColor(ThaiLifeTheme.deepGreen)
                Text("标准写法：\(scene.standardThaiWord) · \(scene.meaningZhHans)")
                    .font(.subheadline)
                    .foregroundColor(ThaiLifeTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(scene.glyphExplanationZhHans)
                .font(.subheadline)
                .foregroundColor(ThaiLifeTheme.textSecondary)
        }
        .padding()
        .background(ThaiLifeTheme.cardWhite)
        .cornerRadius(14)
    }
}
