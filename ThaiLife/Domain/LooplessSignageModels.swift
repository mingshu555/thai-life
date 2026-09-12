import Foundation

struct LooplessSignageReference: Codable, Equatable, Sendable {
    let introductionZhHans: String
    let glyphs: [LooplessGlyphEntry]
    let confusionGroups: [LooplessConfusionGroup]
    let scenes: [LooplessScene]
}

struct LooplessGlyphEntry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let standardThai: String
    let looplessThai: String
    let thaiName: String
    let audioID: String
    let visualHintZhHans: String
    let exampleWords: [String]
}

struct LooplessConfusionGroup: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let glyphIDs: [String]
    let comparisonHintZhHans: String
}

struct LooplessScene: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let titleZhHans: String
    let imageAssetID: String?
    let thaiWord: String
    let standardThaiWord: String
    let meaningZhHans: String
    let audioID: String
    let glyphExplanationZhHans: String
}

extension LooplessGlyphEntry {
    /// Combining Thai vowels and tone marks need a carrier consonant to be visible.
    /// The carrier is presentation-only; audio still uses the standalone glyph.
    var comparisonText: String {
        switch standardThai {
        case "า": "อา"
        case "ิ": "อิ"
        case "ี": "อี"
        case "เ": "เอ"
        case "แ": "แอ"
        case "่": "อ่"
        case "้": "อ้"
        default: standardThai
        }
    }
}
