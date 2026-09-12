import Foundation

enum ThaiMenuValidator {
    enum ValidationError: LocalizedError, Equatable {
        case emptyReference
        case duplicateID(String)
        case incompleteCard(String)
        case emptyBreakdown(String)
        case breakdownDoesNotReconstruct(String)

        var errorDescription: String? {
            switch self {
            case .emptyReference: "菜单资源为空"
            case .duplicateID(let id): "菜单卡片 ID 重复: \(id)"
            case .incompleteCard(let id): "菜单卡片字段不完整: \(id)"
            case .emptyBreakdown(let id): "菜单卡片缺少拆解: \(id)"
            case .breakdownDoesNotReconstruct(let id): "菜单拆解无法还原菜名: \(id)"
            }
        }
    }

    static func validate(_ reference: ThaiMenuReference) throws {
        guard !reference.introductionZhHans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !reference.cards.isEmpty else { throw ValidationError.emptyReference }
        var ids = Set<String>()
        for card in reference.cards {
            guard ids.insert(card.id).inserted else { throw ValidationError.duplicateID(card.id) }
            guard !card.category.isEmpty, !card.thai.isEmpty, !card.meaningZhHans.isEmpty,
                  !card.audioID.isEmpty, !card.imageAssetID.isEmpty else {
                throw ValidationError.incompleteCard(card.id)
            }
            guard !card.breakdown.combinations.isEmpty, !card.breakdown.minimal.isEmpty,
                  card.breakdown.combinations.allSatisfy({ !$0.thai.isEmpty && !$0.glossZhHans.isEmpty }),
                  card.breakdown.minimal.allSatisfy({ !$0.thai.isEmpty && !$0.glossZhHans.isEmpty }) else {
                throw ValidationError.emptyBreakdown(card.id)
            }
            let combinationText = card.breakdown.combinations.map(\.thai).joined().filter { !$0.isWhitespace }
            let minimalText = card.breakdown.minimal.map(\.thai).joined().filter { !$0.isWhitespace }
            let cardText = card.thai.filter { !$0.isWhitespace }
            guard combinationText == cardText || minimalText == cardText else {
                throw ValidationError.breakdownDoesNotReconstruct(card.id)
            }
        }
    }
}

enum ThaiMenuLoadError: LocalizedError {
    case resourceNotFound
    case decode(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound: "未找到泰国常见菜单资源"
        case .decode(let message): "泰国常见菜单解码失败: \(message)"
        case .invalid(let message): "泰国常见菜单校验失败: \(message)"
        }
    }
}
