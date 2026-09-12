import Foundation

struct ThaiMenuReference: Codable, Equatable, Sendable {
    let introductionZhHans: String
    let cards: [ThaiMenuCard]
}

struct ThaiMenuCard: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let category: String
    let thai: String
    let meaningZhHans: String
    let audioID: String
    let imageAssetID: String
    var explanationZhHans: String?
    let breakdown: ThaiMenuBreakdown

    init(
        id: String,
        category: String,
        thai: String,
        meaningZhHans: String,
        audioID: String,
        imageAssetID: String,
        explanationZhHans: String? = nil,
        breakdown: ThaiMenuBreakdown
    ) {
        self.id = id
        self.category = category
        self.thai = thai
        self.meaningZhHans = meaningZhHans
        self.audioID = audioID
        self.imageAssetID = imageAssetID
        self.explanationZhHans = explanationZhHans
        self.breakdown = breakdown
    }
}

struct ThaiMenuBreakdown: Codable, Equatable, Sendable {
    let combinations: [ThaiMenuBreakdownPart]
    let minimal: [ThaiMenuBreakdownPart]
}

struct ThaiMenuBreakdownPart: Codable, Equatable, Identifiable, Sendable {
    let thai: String
    let glossZhHans: String
    var id: String { thai + "-" + glossZhHans }
}
