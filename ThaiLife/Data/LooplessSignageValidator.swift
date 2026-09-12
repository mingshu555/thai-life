import Foundation

enum LooplessSignageValidator {
    enum ValidationError: LocalizedError, Equatable {
        case emptyIntroduction
        case duplicateID(String)
        case emptyGlyph(String)
        case unknownGlyph(String)
        case emptyConfusionGroup(String)
        case emptyScene(String)
        case duplicateSceneID(String)
        case missingMandatoryScene(String)

        var errorDescription: String? {
            switch self {
            case .emptyIntroduction: "无头字对照页缺少说明"
            case .duplicateID(let id): "无头字条目 ID 重复: \(id)"
            case .emptyGlyph(let id): "无头字条目为空: \(id)"
            case .unknownGlyph(let id): "无头字引用了未知字形: \(id)"
            case .emptyConfusionGroup(let id): "易混组为空: \(id)"
            case .emptyScene(let id): "场景数据为空: \(id)"
            case .duplicateSceneID(let id): "场景 ID 重复: \(id)"
            case .missingMandatoryScene(let id): "缺少必需场景: \(id)"
            }
        }
    }

    static let mandatorySceneIDs = ["milk-tea", "discount", "open-close", "pharmacy", "station-exit"]

    static func validate(_ reference: LooplessSignageReference) throws {
        guard !reference.introductionZhHans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyIntroduction
        }
        var ids = Set<String>()
        for glyph in reference.glyphs {
            guard ids.insert(glyph.id).inserted else { throw ValidationError.duplicateID(glyph.id) }
            guard !glyph.standardThai.isEmpty, !glyph.looplessThai.isEmpty, !glyph.thaiName.isEmpty,
                  !glyph.audioID.isEmpty, !glyph.visualHintZhHans.isEmpty else {
                throw ValidationError.emptyGlyph(glyph.id)
            }
        }
        let glyphIDs = Set(reference.glyphs.map(\.id))
        for group in reference.confusionGroups {
            guard !group.glyphIDs.isEmpty, !group.comparisonHintZhHans.isEmpty else {
                throw ValidationError.emptyConfusionGroup(group.id)
            }
            guard group.glyphIDs.allSatisfy(glyphIDs.contains) else {
                throw ValidationError.unknownGlyph(group.id)
            }
        }
        var sceneIDs = Set<String>()
        for scene in reference.scenes {
            guard sceneIDs.insert(scene.id).inserted else { throw ValidationError.duplicateSceneID(scene.id) }
            guard !scene.titleZhHans.isEmpty, !scene.thaiWord.isEmpty,
                  !scene.standardThaiWord.isEmpty, !scene.meaningZhHans.isEmpty, !scene.audioID.isEmpty,
                  !scene.glyphExplanationZhHans.isEmpty else { throw ValidationError.emptyScene(scene.id) }
        }
        for id in mandatorySceneIDs where !sceneIDs.contains(id) {
            throw ValidationError.missingMandatoryScene(id)
        }
    }
}

enum LooplessSignageLoadError: LocalizedError {
    case resourceNotFound
    case decode(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound: "未找到无头字对照资源"
        case .decode(let message): "无头字对照资源解码失败: \(message)"
        case .invalid(let message): "无头字对照资源校验失败: \(message)"
        }
    }
}
