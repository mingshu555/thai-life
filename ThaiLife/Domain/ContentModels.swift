import Foundation

// MARK: - Content Kinds

enum ContentKind: String, Codable, Sendable, Hashable, CaseIterable {
    case word
    case chunk
    case sentence
    case dialogue
}

// MARK: - Content Categories

enum ContentCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case basics = "basics"
    case social = "social"
    case numbers = "numbers"
    case foodDining = "food_dining"
    case shopping = "shopping"
    case homeLiving = "home_living"
    case transport = "transport"
    case phoneNetwork = "phone_network"
    case health = "health"
    case safety = "safety"
    case weatherLeisure = "weather_leisure"
    case airport = "airport"
    case hotel = "hotel"
    case localErrands = "local_errands"
    case googleMaps = "google_maps"
    case coreFunction = "core_function"

    static var classifiedCourseCases: [ContentCategory] {
        allCases.filter { !$0.isSpecialExpansion }
    }

    var isSpecialExpansion: Bool {
        self == .coreFunction
    }

    var displayNameZhHans: String {
        switch self {
        case .basics: "开口基础"
        case .social: "社交与人际"
        case .numbers: "数字、时间与数量"
        case .foodDining: "饮食与点餐"
        case .shopping: "购物与付款"
        case .homeLiving: "家与日常生活"
        case .transport: "交通与问路"
        case .phoneNetwork: "手机、网络与服务"
        case .health: "身体、健康与药店"
        case .safety: "安全与紧急求助"
        case .weatherLeisure: "天气、休闲与生活习惯"
        case .airport: "机场与入境"
        case .hotel: "酒店与景点"
        case .localErrands: "本地办事"
        case .googleMaps: "Google地图常用词"
        case .coreFunction: "核心功能词"
        }
    }

    var emoji: String {
        switch self {
        case .basics: "💬"
        case .social: "🤝"
        case .numbers: "🔢"
        case .foodDining: "🍜"
        case .shopping: "🛍️"
        case .homeLiving: "🏠"
        case .transport: "🚗"
        case .phoneNetwork: "📱"
        case .health: "🏥"
        case .safety: "🚨"
        case .weatherLeisure: "☀️"
        case .airport: "✈️"
        case .hotel: "🏨"
        case .localErrands: "🏛️"
        case .googleMaps: "🗺️"
        case .coreFunction: "🔑"
        }
    }
}

// MARK: - Phrase Segment

struct PhraseSegment: Codable, Sendable, Hashable {
    let thai: String
    let romanization: String?
    let gloss: String

    init(thai: String, romanization: String? = nil, gloss: String) {
        self.thai = thai
        self.romanization = romanization
        self.gloss = gloss
    }
}

// MARK: - Chunk Breakdown

struct ChunkBreakdown: Codable, Sendable, Hashable {
    let combinations: [PhraseSegment]
    let minimal: [PhraseSegment]
}

// MARK: - Dialogue Breakdown

struct DialogueTurn: Codable, Sendable, Hashable {
    let speaker: String
    let thai: String
    let meaningZhHans: String
    let segments: [PhraseSegment]
}

// MARK: - Content Item

struct ContentItem: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let kind: ContentKind
    let category: ContentCategory
    let tags: [String]
    let thai: String
    let romanization: String
    let meaningZhHans: String
    let usageNote: String?
    let frequencyTier: Int
    let audioID: String
    let prerequisiteIDs: [String]
    let relatedIDs: [String]
    let example: String?
    let exampleMeaning: String?
    let segments: [PhraseSegment]
    let chunkBreakdown: ChunkBreakdown?
    let wordBreakdown: ChunkBreakdown?
    let dialogueBreakdown: [DialogueTurn]?
    let sourceID: String
    let contentVersion: Int
    let stepIndex: Int?
    let dialogueRole: String?
    let dialogueTurn: Int?

    init(
        id: String,
        kind: ContentKind,
        category: ContentCategory,
        tags: [String] = [],
        thai: String,
        romanization: String,
        meaningZhHans: String,
        usageNote: String? = nil,
        frequencyTier: Int = 1,
        audioID: String,
        prerequisiteIDs: [String] = [],
        relatedIDs: [String] = [],
        example: String? = nil,
        exampleMeaning: String? = nil,
        segments: [PhraseSegment] = [],
        chunkBreakdown: ChunkBreakdown? = nil,
        wordBreakdown: ChunkBreakdown? = nil,
        dialogueBreakdown: [DialogueTurn]? = nil,
        sourceID: String,
        contentVersion: Int = 1,
        stepIndex: Int? = nil,
        dialogueRole: String? = nil,
        dialogueTurn: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.category = category
        self.tags = tags
        self.thai = thai
        self.romanization = romanization
        self.meaningZhHans = meaningZhHans
        self.usageNote = usageNote
        self.frequencyTier = frequencyTier
        self.audioID = audioID
        self.prerequisiteIDs = prerequisiteIDs
        self.relatedIDs = relatedIDs
        self.example = example
        self.exampleMeaning = exampleMeaning
        self.segments = segments
        self.chunkBreakdown = chunkBreakdown
        self.wordBreakdown = wordBreakdown
        self.dialogueBreakdown = dialogueBreakdown
        self.sourceID = sourceID
        self.contentVersion = contentVersion
        self.stepIndex = stepIndex
        self.dialogueRole = dialogueRole
        self.dialogueTurn = dialogueTurn
    }
}

// MARK: - Content Manifest

struct ContentManifest: Codable, Sendable {
    let version: Int
    let itemCount: Int
    let generatedAt: String
    let checksumSHA256: String

    init(version: Int, itemCount: Int, generatedAt: String, checksumSHA256: String) {
        self.version = version
        self.itemCount = itemCount
        self.generatedAt = generatedAt
        self.checksumSHA256 = checksumSHA256
    }
}

// MARK: - Fixture Helpers

extension ContentItem {
    static func fixture(
        id: String = "fixture-001",
        kind: ContentKind = .word,
        category: ContentCategory = .basics,
        thai: String = "สวัสดี",
        romanization: String = "sà-wàt-dii",
        meaningZhHans: String = "你好",
        audioID: String = "audio-001",
        prerequisiteIDs: [String] = [],
        relatedIDs: [String] = [],
        example: String? = nil,
        exampleMeaning: String? = nil,
        segments: [PhraseSegment] = [],
        chunkBreakdown: ChunkBreakdown? = nil,
        wordBreakdown: ChunkBreakdown? = nil,
        dialogueBreakdown: [DialogueTurn]? = nil,
        sourceID: String = "author-001"
    ) -> ContentItem {
        ContentItem(
            id: id,
            kind: kind,
            category: category,
            thai: thai,
            romanization: romanization,
            meaningZhHans: meaningZhHans,
            audioID: audioID,
            prerequisiteIDs: prerequisiteIDs,
            relatedIDs: relatedIDs,
            example: example,
            exampleMeaning: exampleMeaning,
            segments: segments,
            chunkBreakdown: chunkBreakdown,
            wordBreakdown: wordBreakdown,
            dialogueBreakdown: dialogueBreakdown,
            sourceID: sourceID
        )
    }
}

extension ContentItem {
    private static let finalPoliteParticles: Set<String> = ["ครับ", "ค่ะ", "คะ"]
    // Keep longer variants before their shorter prefixes.
    private static let politeParticleGlossSuffixes: [String] = [
        "礼貌语气词(男)",
        "礼貌语气词(女)",
        "语气词(男)",
        "语气词(女)",
        "礼貌语气词",
        "语气词"
    ]

    var displayExampleMeaning: String? {
        guard let exampleMeaning, let finalSegment = segments.last,
              Self.finalPoliteParticles.contains(finalSegment.thai) else {
            return exampleMeaning
        }

        guard let suffix = Self.politeParticleGlossSuffixes.first(where: exampleMeaning.hasSuffix) else {
            return exampleMeaning
        }

        return String(exampleMeaning.dropLast(suffix.count))
    }
}
