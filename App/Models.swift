import Foundation

struct LocalBootstrapConfig: Codable {
    var serverUrl: String?
    var pairKey: String?
}

struct UserAndPeerProfile: Codable, Equatable {
    var hajimiName: String = "哈基米"
    var ownerName: String = ""
    var hasCustomHajimiAvatar: Bool = false
    var hasCustomOwnerAvatar: Bool = false
    var hasCustomPortrait: Bool = false
    var avatarRev: Int = 1
    var hajimiAvatarUrl: String = "/assets/hajimi-avatar.png?v=1"
    var ownerAvatarUrl: String = "/assets/owner-avatar.png?v=1"
    var portraitUrl: String = "/assets/hajimi-full.jpg?v=1"

    enum CodingKeys: String, CodingKey {
        case hajimiName, ownerName, hasCustomHajimiAvatar, hasCustomOwnerAvatar, hasCustomPortrait
        case avatarRev, hajimiAvatarUrl, ownerAvatarUrl, portraitUrl
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hajimiName = (try? c.decode(String.self, forKey: .hajimiName)) ?? "哈基米"
        ownerName = (try? c.decode(String.self, forKey: .ownerName)) ?? ""
        hasCustomHajimiAvatar = (try? c.decode(Bool.self, forKey: .hasCustomHajimiAvatar)) ?? false
        hasCustomOwnerAvatar = (try? c.decode(Bool.self, forKey: .hasCustomOwnerAvatar)) ?? false
        hasCustomPortrait = (try? c.decode(Bool.self, forKey: .hasCustomPortrait)) ?? false
        avatarRev = (try? c.decode(Int.self, forKey: .avatarRev)) ?? 1
        hajimiAvatarUrl = (try? c.decode(String.self, forKey: .hajimiAvatarUrl)) ?? "/assets/hajimi-avatar.png"
        ownerAvatarUrl = (try? c.decode(String.self, forKey: .ownerAvatarUrl)) ?? "/assets/owner-avatar.png"
        portraitUrl = (try? c.decode(String.self, forKey: .portraitUrl)) ?? "/assets/hajimi-full.jpg"
    }
}

struct PortraitMood: Codable, Equatable {
    var id: String = "online"
    var emoji: String = "😊"
    var tag: String = "在线陪伴"
    var desc: String = "随时等你发消息"
    var accent: String = "#22c55e"

    init() {}

    enum CodingKeys: String, CodingKey { case id, emoji, tag, desc, accent }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? "online"
        emoji = (try? c.decode(String.self, forKey: .emoji)) ?? "😊"
        tag = (try? c.decode(String.self, forKey: .tag)) ?? "在线陪伴"
        desc = (try? c.decode(String.self, forKey: .desc)) ?? ""
        accent = (try? c.decode(String.self, forKey: .accent)) ?? "#22c55e"
    }
}

struct ModelSelectionInfo: Codable, Equatable {
    var provider: String = "google"
    var model: String = "gemini-4-argon"
    var reasoningEffort: String? = "low"
}

struct SessionCard: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var shortName: String
    var chatTitle: String
    var userNick: String
    var pokeAction: String
    var roleId: String
    var roleBadge: String
    var status: String
    var portrait: PortraitMood
    var modelSelection: ModelSelectionInfo?
    var modelLabel: String
    var lastPreview: String
    var updatedAtMs: Double?
    var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, shortName, chatTitle, userNick, pokeAction
        case roleId, roleBadge, status, portrait, modelSelection, modelLabel, lastPreview, updatedAt, enabled
    }

    init(
        id: String,
        title: String = "哈基米",
        shortName: String = "哈基米",
        chatTitle: String = "哈基米 · 女友",
        userNick: String = "老公",
        pokeAction: String = "轻轻捏了捏脸颊",
        roleId: String = "girlfriend",
        roleBadge: String = "💕 女友",
        status: String = "idle",
        portrait: PortraitMood = PortraitMood(),
        modelSelection: ModelSelectionInfo? = nil,
        modelLabel: String = "默认模型",
        lastPreview: String = "",
        updatedAtMs: Double? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.shortName = shortName
        self.chatTitle = chatTitle
        self.userNick = userNick
        self.pokeAction = pokeAction
        self.roleId = roleId
        self.roleBadge = roleBadge
        self.status = status
        self.portrait = portrait
        self.modelSelection = modelSelection
        self.modelLabel = modelLabel
        self.lastPreview = lastPreview
        self.updatedAtMs = updatedAtMs
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? id
        shortName = (try? c.decode(String.self, forKey: .shortName)) ?? title
        chatTitle = (try? c.decode(String.self, forKey: .chatTitle)) ?? title
        userNick = (try? c.decode(String.self, forKey: .userNick)) ?? "我"
        pokeAction = (try? c.decode(String.self, forKey: .pokeAction)) ?? "戳了戳对方"
        roleId = (try? c.decode(String.self, forKey: .roleId)) ?? "girlfriend"
        roleBadge = (try? c.decode(String.self, forKey: .roleBadge)) ?? "💕 女友"
        status = (try? c.decode(String.self, forKey: .status)) ?? "idle"
        portrait = (try? c.decode(PortraitMood.self, forKey: .portrait)) ?? PortraitMood()
        modelSelection = try? c.decode(ModelSelectionInfo.self, forKey: .modelSelection)
        modelLabel = (try? c.decode(String.self, forKey: .modelLabel)) ?? "默认模型"
        lastPreview = (try? c.decode(String.self, forKey: .lastPreview)) ?? ""
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? true
        if let num = try? c.decode(Double.self, forKey: .updatedAt) {
            updatedAtMs = num
        } else if let str = try? c.decode(String.self, forKey: .updatedAt),
                  let d = ISO8601DateFormatter().date(from: str) {
            updatedAtMs = d.timeIntervalSince1970 * 1000
        } else {
            updatedAtMs = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(shortName, forKey: .shortName)
        try c.encode(chatTitle, forKey: .chatTitle)
        try c.encode(userNick, forKey: .userNick)
        try c.encode(pokeAction, forKey: .pokeAction)
        try c.encode(roleId, forKey: .roleId)
        try c.encode(roleBadge, forKey: .roleBadge)
        try c.encode(status, forKey: .status)
        try c.encode(portrait, forKey: .portrait)
        try c.encodeIfPresent(modelSelection, forKey: .modelSelection)
        try c.encode(modelLabel, forKey: .modelLabel)
        try c.encode(lastPreview, forKey: .lastPreview)
        try c.encodeIfPresent(updatedAtMs, forKey: .updatedAt)
        try c.encode(enabled, forKey: .enabled)
    }
}

struct OtherSessionItem: Codable, Identifiable, Equatable {
    var id: String
    var title: String
}

struct ChatImageAttachment: Codable, Equatable, Identifiable {
    var id: String
    var mediaType: String?
    var localPreviewData: Data?

    enum CodingKeys: String, CodingKey { case id, mediaType }

    init(id: String = UUID().uuidString, mediaType: String? = "image/jpeg", localPreviewData: Data? = nil) {
        self.id = id
        self.mediaType = mediaType
        self.localPreviewData = localPreviewData
    }
}

struct ChatMessageItem: Codable, Identifiable, Equatable {
    var id: String
    var kind: String // "user" | "assistant" | "system"
    var text: String
    var images: [ChatImageAttachment]

    enum CodingKeys: String, CodingKey { case id, kind, text, images }

    init(id: String = UUID().uuidString, kind: String, text: String, images: [ChatImageAttachment] = []) {
        self.id = id
        self.kind = kind
        self.text = text
        self.images = images
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "assistant"
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        images = (try? c.decode([ChatImageAttachment].self, forKey: .images)) ?? []
    }
}

struct EffortOption: Codable, Identifiable, Equatable {
    var id: String
    var name: String
}

struct ModelCatalogEntry: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var defaultEffort: String
    var efforts: [EffortOption]

    enum CodingKeys: String, CodingKey { case id, name, defaultEffort, efforts }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? id
        defaultEffort = (try? c.decode(String.self, forKey: .defaultEffort)) ?? ""
        efforts = (try? c.decode([EffortOption].self, forKey: .efforts)) ?? []
    }
}

struct ProviderCatalogEntry: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var models: [ModelCatalogEntry]
}

struct SharedMemoryEntry: Codable, Identifiable, Equatable {
    var id: String
    var category: String
    var content: String
    var pinned: Bool
    var source: String
    var createdAt: String

    enum CodingKeys: String, CodingKey { case id, category, content, pinned, source, createdAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        category = (try? c.decode(String.self, forKey: .category)) ?? "memory"
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
        source = (try? c.decode(String.self, forKey: .source)) ?? "user"
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}

struct EvolutionHistoryItem: Codable, Identifiable, Equatable {
    var id: String
    var version: Int
    var at: String
    var summary: String
    var currentVibe: String
    var livingTraits: [String]
}

struct PersonaEvolutionState: Codable, Equatable {
    var version: Int = 1
    var enabled: Bool = true
    var cycleEveryTurns: Int = 12
    var cycleEveryHours: Int = 24
    var turnsSinceLast: Int = 0
    var lastEvolvedAt: String = ""
    var currentVibe: String = ""
    var livingTraits: [String] = []
    var lastDiary: String = ""
    var history: [EvolutionHistoryItem] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, enabled, cycleEveryTurns, cycleEveryHours, turnsSinceLast
        case lastEvolvedAt, currentVibe, livingTraits, lastDiary, history
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? true
        cycleEveryTurns = (try? c.decode(Int.self, forKey: .cycleEveryTurns)) ?? 12
        cycleEveryHours = (try? c.decode(Int.self, forKey: .cycleEveryHours)) ?? 24
        turnsSinceLast = (try? c.decode(Int.self, forKey: .turnsSinceLast)) ?? 0
        lastEvolvedAt = (try? c.decode(String.self, forKey: .lastEvolvedAt)) ?? ""
        currentVibe = (try? c.decode(String.self, forKey: .currentVibe)) ?? ""
        livingTraits = (try? c.decode([String].self, forKey: .livingTraits)) ?? []
        lastDiary = (try? c.decode(String.self, forKey: .lastDiary)) ?? ""
        history = (try? c.decode([EvolutionHistoryItem].self, forKey: .history)) ?? []
    }
}

struct OverviewResponse: Codable {
    var ok: Bool?
    var profile: UserAndPeerProfile?
    var enabledSessions: [SessionCard]?
    var otherSessions: [OtherSessionItem]?
}

struct HistoryResponse: Codable {
    var ok: Bool?
    var profile: UserAndPeerProfile?
    var session: SessionCard?
    var messages: [ChatMessageItem]?
}

struct ModelsResponse: Codable {
    var ok: Bool?
    var providers: [ProviderCatalogEntry]?
}

struct MemoriesResponse: Codable {
    var ok: Bool?
    var memories: [SharedMemoryEntry]?
}

struct EvolutionResponse: Codable {
    var ok: Bool?
    var evolution: PersonaEvolutionState?
}

struct PairResponse: Codable {
    var ok: Bool?
    var pairKey: String?
    var error: String?
    var profile: UserAndPeerProfile?
}
