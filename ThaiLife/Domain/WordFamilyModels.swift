import Foundation

// MARK: - Word Family Models (词根/前缀词族卡片数据模型)

struct WordFamilyMember: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let thai: String
    let romanization: String
    let meaningZhHans: String
    let audioID: String?

    init(
        id: String,
        thai: String,
        romanization: String,
        meaningZhHans: String,
        audioID: String? = nil
    ) {
        self.id = id
        self.thai = thai
        self.romanization = romanization
        self.meaningZhHans = meaningZhHans
        self.audioID = audioID
    }
}

struct WordFamily: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let rootThai: String
    let rootRomanization: String
    let rootMeaningZhHans: String
    let rootAudioID: String?
    let usageNote: String
    let category: ContentCategory
    let itemCount: Int
    let items: [WordFamilyMember]

    init(
        id: String,
        rootThai: String,
        rootRomanization: String,
        rootMeaningZhHans: String,
        rootAudioID: String? = nil,
        usageNote: String,
        category: ContentCategory,
        itemCount: Int,
        items: [WordFamilyMember]
    ) {
        self.id = id
        self.rootThai = rootThai
        self.rootRomanization = rootRomanization
        self.rootMeaningZhHans = rootMeaningZhHans
        self.rootAudioID = rootAudioID
        self.usageNote = usageNote
        self.category = category
        self.itemCount = itemCount
        self.items = items
    }
}
