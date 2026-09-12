import Foundation

enum ContentValidator {
    enum ValidationError: LocalizedError, Equatable {
        case duplicateID(String)
        case emptyThai(id: String)
        case emptyMeaning(id: String)
        case emptyRomanization(id: String)
        case missingAudioID(id: String)
        case unknownPrerequisite(id: String, prerequisite: String)
        case unknownRelated(id: String, related: String)
        case selfReferencingPrerequisite(id: String)
        case circularPrerequisite(chain: [String])
        case segmentReconstructionFailed(id: String, expected: String, got: String)
        case emptyCategory(id: String)
        case invalidFrequencyTier(id: String, tier: Int)
        case missingSourceID(id: String)
        case missingExampleMeaning(id: String)
        case exampleMeaningWithoutExample(id: String)
        case exampleCountMismatch(expected: Int, actual: Int)
        case exampleCategoryCountMismatch(category: ContentCategory, expected: Int, actual: Int)
        case mechanicalExampleMeaning(id: String)
        case missingChunkBreakdown(id: String)
        case unexpectedChunkBreakdown(id: String)
        case emptyChunkBreakdown(id: String, layer: String)
        case chunkBreakdownReconstructionFailed(id: String, layer: String, expected: String, got: String)
        case unexpectedWordBreakdown(id: String)
        case emptyWordBreakdown(id: String, layer: String)
        case wordBreakdownTooSmall(id: String, layer: String)
        case wordBreakdownReconstructionFailed(id: String, layer: String, expected: String, got: String)
        case wordBreakdownRefinementFailed(id: String)
        case wordBreakdownExampleHeadwordMissing(id: String)
        case wordBreakdownExampleHeadwordUnsplit(id: String)
        case wordBreakdownExampleSpanMismatch(id: String)
        case missingDialogueBreakdown(id: String)
        case unexpectedDialogueBreakdown(id: String)
        case emptyDialogueBreakdown(id: String)
        case dialogueLineReconstructionFailed(id: String, turn: Int)
        case dialogueSegmentReconstructionFailed(id: String, turn: Int, expected: String, got: String)

        var errorDescription: String? {
            switch self {
            case .duplicateID(let id): "重复 ID: \(id)"
            case .emptyThai(let id): "泰文为空: \(id)"
            case .emptyMeaning(let id): "中文释义为空: \(id)"
            case .emptyRomanization(let id): "转写为空: \(id)"
            case .missingAudioID(let id): "缺少音频 ID: \(id)"
            case .unknownPrerequisite(let id, let pre): "前置 ID 不存在: \(id) → \(pre)"
            case .unknownRelated(let id, let rel): "关联 ID 不存在: \(id) → \(rel)"
            case .selfReferencingPrerequisite(let id): "自引用前置: \(id)"
            case .circularPrerequisite(let chain): "循环前置引用: \(chain.joined(separator: " → "))"
            case .segmentReconstructionFailed(let id, let expected, let got):
                "片段重组失败: \(id), 期望 '\(expected)', 得到 '\(got)'"
            case .emptyCategory(let id): "分类为空: \(id)"
            case .invalidFrequencyTier(let id, let tier): "频率等级无效: \(id), tier=\(tier)"
            case .missingSourceID(let id): "缺少来源 ID: \(id)"
            case .missingExampleMeaning(let id): "例句缺少整句中文翻译: \(id)"
            case .exampleMeaningWithoutExample(let id): "存在例句中文翻译但缺少例句: \(id)"
            case .exampleCountMismatch(let expected, let actual):
                "例句数量不匹配: 期望 \(expected)，实际 \(actual)"
            case .exampleCategoryCountMismatch(let category, let expected, let actual):
                "例句分类数量不匹配: \(category.rawValue)，期望 \(expected)，实际 \(actual)"
            case .mechanicalExampleMeaning(let id): "例句翻译疑似由词块释义机械拼接: \(id)"
            case .missingChunkBreakdown(let id): "缺少词块拆解: \(id)"
            case .unexpectedChunkBreakdown(let id): "非词块内容不应包含词块拆解: \(id)"
            case .emptyChunkBreakdown(let id, let layer): "词块拆解层为空: \(id), 层=\(layer)"
            case .chunkBreakdownReconstructionFailed(let id, let layer, let expected, let got):
                "词块拆解重组失败: \(id), 层=\(layer), 期望 '\(expected)', 得到 '\(got)'"
            case .unexpectedWordBreakdown(let id): "非单词内容不应包含单词拆解: \(id)"
            case .emptyWordBreakdown(let id, let layer): "单词拆解层为空: \(id), 层=\(layer)"
            case .wordBreakdownTooSmall(let id, let layer): "单词拆解层少于两段: \(id), 层=\(layer)"
            case .wordBreakdownReconstructionFailed(let id, let layer, let expected, let got):
                "单词拆解重组失败: \(id), 层=\(layer), 期望 '\(expected)', 得到 '\(got)'"
            case .wordBreakdownRefinementFailed(let id): "单词最小拆解未细化组合层: \(id)"
            case .wordBreakdownExampleHeadwordMissing(let id): "例句未覆盖主词: \(id)"
            case .wordBreakdownExampleHeadwordUnsplit(let id): "例句仍把主词当作一整段: \(id)"
            case .wordBreakdownExampleSpanMismatch(let id): "例句主词词块与组合层不一致: \(id)"
            case .missingDialogueBreakdown(let id): "缺少对话拆解: \(id)"
            case .unexpectedDialogueBreakdown(let id): "非对话内容不应包含对话拆解: \(id)"
            case .emptyDialogueBreakdown(let id): "对话拆解为空: \(id)"
            case .dialogueLineReconstructionFailed(let id, let turn): "对话行重组失败: \(id), turn=\(turn)"
            case .dialogueSegmentReconstructionFailed(let id, let turn, let expected, let got):
                "对话拆解片段重组失败: \(id), turn=\(turn), 期望 '\(expected)', 得到 '\(got)'"
            }
        }
    }

    static func validate(_ items: [ContentItem]) throws {
        var errors: [ValidationError] = []

        // 1. Duplicate IDs
        let idCounts = Dictionary(grouping: items, by: \.id).mapValues { $0.count }
        for (id, count) in idCounts where count > 1 {
            errors.append(.duplicateID(id))
        }

        let idSet = Set(items.map(\.id))

        // 2. Per-item validation
        for item in items {
            if item.thai.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.emptyThai(id: item.id))
            }
            if item.meaningZhHans.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.emptyMeaning(id: item.id))
            }
            if item.kind != .dialogue && item.romanization.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.emptyRomanization(id: item.id))
            }
            if item.audioID.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.missingAudioID(id: item.id))
            }
            if item.sourceID.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.missingSourceID(id: item.id))
            }
            if item.frequencyTier < 0 || item.frequencyTier > 5 {
                errors.append(.invalidFrequencyTier(id: item.id, tier: item.frequencyTier))
            }

            let hasExample = !(item.example?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasExampleMeaning = !(item.exampleMeaning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            if hasExample && !hasExampleMeaning {
                errors.append(.missingExampleMeaning(id: item.id))
            } else if !hasExample && hasExampleMeaning {
                errors.append(.exampleMeaningWithoutExample(id: item.id))
            }

            // 3. Prerequisite references
            for preID in item.prerequisiteIDs {
                if preID == item.id {
                    errors.append(.selfReferencingPrerequisite(id: item.id))
                } else if !idSet.contains(preID) {
                    errors.append(.unknownPrerequisite(id: item.id, prerequisite: preID))
                }
            }

            // 4. Related references
            for relID in item.relatedIDs {
                if !idSet.contains(relID) {
                    errors.append(.unknownRelated(id: item.id, related: relID))
                }
            }

            if let exampleMeaning = item.exampleMeaning,
               !item.segments.isEmpty,
               normalizedExampleMeaning(exampleMeaning) == normalizedExampleMeaning(item.segments.map(\.gloss).joined()) {
                errors.append(.mechanicalExampleMeaning(id: item.id))
            }

            // 5. Segment reconstruction for either the complete example or the item text.
            if !item.segments.isEmpty {
                let expectedText = hasExample ? item.example! : item.thai
                let reconstructed = item.segments.map(\.thai).joined()
                if reconstructed.replacingOccurrences(of: " ", with: "") != expectedText.replacingOccurrences(of: " ", with: "") {
                    errors.append(.segmentReconstructionFailed(
                        id: item.id,
                        expected: expectedText,
                        got: reconstructed
                    ))
                }
            }

            if item.kind == .chunk {
                guard let breakdown = item.chunkBreakdown else {
                    errors.append(.missingChunkBreakdown(id: item.id))
                    continue
                }

                for (layer, segments) in [("combinations", breakdown.combinations), ("minimal", breakdown.minimal)] {
                    guard !segments.isEmpty,
                          segments.allSatisfy({
                              !$0.thai.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                              !$0.gloss.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          }) else {
                        errors.append(.emptyChunkBreakdown(id: item.id, layer: layer))
                        continue
                    }

                    let reconstructed = segments.map(\.thai).joined()
                    if normalizedThai(reconstructed) != normalizedThai(item.thai) {
                        errors.append(.chunkBreakdownReconstructionFailed(
                            id: item.id,
                            layer: layer,
                            expected: item.thai,
                            got: reconstructed
                        ))
                    }
                }
            } else if item.chunkBreakdown != nil {
                errors.append(.unexpectedChunkBreakdown(id: item.id))
            }

            if item.kind == .word {
                if let breakdown = item.wordBreakdown {
                    errors.append(contentsOf: validateWordBreakdown(item, breakdown: breakdown))
                }
            } else if item.wordBreakdown != nil {
                errors.append(.unexpectedWordBreakdown(id: item.id))
            }

            if item.kind == .dialogue {
                guard let turns = item.dialogueBreakdown else {
                    errors.append(.missingDialogueBreakdown(id: item.id))
                    continue
                }
                guard !turns.isEmpty else {
                    errors.append(.emptyDialogueBreakdown(id: item.id))
                    continue
                }
                let thaiLines = item.thai.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                let meaningLines = item.meaningZhHans.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                guard thaiLines.count == turns.count, meaningLines.count == turns.count else {
                    errors.append(.dialogueLineReconstructionFailed(id: item.id, turn: -1))
                    continue
                }
                for (index, turn) in turns.enumerated() {
                    let prefix = "\(turn.speaker):"
                    guard thaiLines[index].hasPrefix(prefix), meaningLines[index].hasPrefix(prefix),
                          normalizedDialoguePayload(String(thaiLines[index].dropFirst(prefix.count))) == normalizedDialoguePayload(turn.thai),
                          normalizedDialoguePayload(String(meaningLines[index].dropFirst(prefix.count))) == normalizedDialoguePayload(turn.meaningZhHans) else {
                        errors.append(.dialogueLineReconstructionFailed(id: item.id, turn: index))
                        continue
                    }
                    let reconstructed = turn.segments.map(\.thai).joined()
                    if normalizedThai(reconstructed) != normalizedThai(turn.thai) {
                        errors.append(.dialogueSegmentReconstructionFailed(id: item.id, turn: index, expected: turn.thai, got: reconstructed))
                    }
                }
            } else if item.dialogueBreakdown != nil {
                errors.append(.unexpectedDialogueBreakdown(id: item.id))
            }
        }

        if items.count == 1200 {
            validateBundledExampleCoverage(items, errors: &errors)
        }

        // 6. Circular prerequisite detection
        if let cycle = detectCycle(in: items) {
            errors.append(.circularPrerequisite(chain: cycle))
        }

        if !errors.isEmpty {
            throw ValidationFailedError(errors: errors)
        }
    }

    private static let expectedExampleCategoryCounts: [ContentCategory: Int] = [
        .basics: 40,
        .social: 40,
        .numbers: 40,
        .foodDining: 59,
        .shopping: 40,
        .homeLiving: 45,
        .transport: 50,
        .phoneNetwork: 40,
        .health: 50,
        .safety: 50,
        .weatherLeisure: 50,
        .airport: 50,
        .hotel: 50,
        .localErrands: 50
    ]

    private static func validateBundledExampleCoverage(_ items: [ContentItem], errors: inout [ValidationError]) {
        let examples = items.filter { !($0.example?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
        if examples.count != 654 {
            errors.append(.exampleCountMismatch(expected: 654, actual: examples.count))
        }
        let counts = Dictionary(grouping: examples, by: \.category).mapValues(\.count)
        for (category, expected) in expectedExampleCategoryCounts {
            let actual = counts[category, default: 0]
            if actual != expected {
                errors.append(.exampleCategoryCountMismatch(category: category, expected: expected, actual: actual))
            }
        }
    }

    private static func normalizedThai(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    private static func normalizedDialoguePayload(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedExampleMeaning(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    private static func validateWordBreakdown(_ item: ContentItem, breakdown: ChunkBreakdown) -> [ValidationError] {
        var errors: [ValidationError] = []
        for (layer, segments) in [("combinations", breakdown.combinations), ("minimal", breakdown.minimal)] {
            if segments.contains(where: {
                $0.thai.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                $0.gloss.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) || segments.isEmpty {
                errors.append(.emptyWordBreakdown(id: item.id, layer: layer))
                continue
            }
            if segments.count < 2 {
                errors.append(.wordBreakdownTooSmall(id: item.id, layer: layer))
                continue
            }
            let reconstructed = segments.map(\.thai).joined()
            if normalizedThai(reconstructed) != normalizedThai(item.thai) {
                errors.append(.wordBreakdownReconstructionFailed(
                    id: item.id,
                    layer: layer,
                    expected: item.thai,
                    got: reconstructed
                ))
            }
        }
        if !errors.isEmpty {
            return errors
        }
        if !minimalRefinesCombinations(combinations: breakdown.combinations, minimal: breakdown.minimal) {
            errors.append(.wordBreakdownRefinementFailed(id: item.id))
        }

        let hasExample = !(item.example?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard hasExample, let example = item.example else {
            return errors
        }
        let headword = normalizedThai(item.thai)
        if !normalizedThai(example).contains(headword) {
            errors.append(.wordBreakdownExampleHeadwordMissing(id: item.id))
            return errors
        }
        if item.segments.contains(where: { normalizedThai($0.thai) == headword }) {
            errors.append(.wordBreakdownExampleHeadwordUnsplit(id: item.id))
        }
        guard let span = headwordSpan(in: item.segments, headword: item.thai) else {
            errors.append(.wordBreakdownExampleHeadwordMissing(id: item.id))
            return errors
        }
        if span.map(\.thai) != breakdown.combinations.map(\.thai) ||
            span.map(\.gloss) != breakdown.combinations.map(\.gloss) {
            errors.append(.wordBreakdownExampleSpanMismatch(id: item.id))
        }
        return errors
    }

    private static func minimalRefinesCombinations(combinations: [PhraseSegment], minimal: [PhraseSegment]) -> Bool {
        var rest = minimal.map { normalizedThai($0.thai) }
        for combo in combinations {
            let target = normalizedThai(combo.thai)
            var acc = ""
            var used = 0
            while used < rest.count, acc != target {
                acc += rest[used]
                used += 1
                if acc.count > target.count {
                    return false
                }
            }
            if acc != target {
                return false
            }
            rest.removeFirst(used)
        }
        return rest.isEmpty
    }

    private static func headwordSpan(in segments: [PhraseSegment], headword: String) -> ArraySlice<PhraseSegment>? {
        let target = normalizedThai(headword)
        guard !segments.isEmpty else { return nil }
        for i in segments.indices {
            var acc = ""
            for j in i..<segments.count {
                acc += normalizedThai(segments[j].thai)
                if acc == target {
                    return segments[i...j]
                }
                if acc.count > target.count {
                    break
                }
            }
        }
        return nil
    }

    private static func detectCycle(in items: [ContentItem]) -> [String]? {
        let adj = Dictionary(items.map { ($0.id, $0.prerequisiteIDs) }, uniquingKeysWith: { first, _ in first })
        var visited: Set<String> = []
        var stack: Set<String> = []
        var path: [String] = []

        func dfs(_ node: String) -> Bool {
            visited.insert(node)
            stack.insert(node)
            path.append(node)
            for next in adj[node] ?? [] {
                if !visited.contains(next) {
                    if dfs(next) { return true }
                } else if stack.contains(next) {
                    path.append(next)
                    return true
                }
            }
            stack.remove(node)
            path.removeLast()
            return false
        }

        for item in items where !visited.contains(item.id) {
            path = []
            if dfs(item.id) {
                return path
            }
        }
        return nil
    }

    struct ValidationFailedError: LocalizedError {
        let errors: [ValidationError]
        var errorDescription: String? {
            "内容验证失败: \(errors.count) 个错误\n" + errors.map { "  - \($0.errorDescription ?? "")" }.joined(separator: "\n")
        }
    }
}
