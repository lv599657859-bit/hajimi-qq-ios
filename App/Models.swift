import Foundation

struct LocalBootstrapConfig: Codable {
    var serverUrl: String?
    var fallbackUrls: [String]?
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

// MARK: - SoulOS v3.0 Telemetry, PAD Emotion, Vitals, Bond & Diary Models

struct PadEmotionState: Codable, Equatable {
    var pleasure: Double = 0.30
    var arousal: Double = 0.20
    var dominance: Double = 0.05
    var moodKey: String = "online"
    var moodEmoji: String = "😊"
    var moodLabel: String = "松弛在线陪伴"
    var moodDesc: String = "心情舒展自然，随时等你开口"

    init() {}

    enum CodingKeys: String, CodingKey {
        case pleasure, arousal, dominance, moodKey, moodEmoji, moodLabel, moodDesc
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pleasure = (try? c.decode(Double.self, forKey: .pleasure)) ?? 0.30
        arousal = (try? c.decode(Double.self, forKey: .arousal)) ?? 0.20
        dominance = (try? c.decode(Double.self, forKey: .dominance)) ?? 0.05
        moodKey = (try? c.decode(String.self, forKey: .moodKey)) ?? "online"
        moodEmoji = (try? c.decode(String.self, forKey: .moodEmoji)) ?? "😊"
        moodLabel = (try? c.decode(String.self, forKey: .moodLabel)) ?? "松弛在线陪伴"
        moodDesc = (try? c.decode(String.self, forKey: .moodDesc)) ?? ""
    }
}

struct CircadianState: Codable, Equatable {
    var id: String = "daytime"
    var emoji: String = "☀️"
    var label: String = "白日在线"
    var promptHint: String = ""

    init() {}

    enum CodingKeys: String, CodingKey { case id, emoji, label, promptHint }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? "daytime"
        emoji = (try? c.decode(String.self, forKey: .emoji)) ?? "☀️"
        label = (try? c.decode(String.self, forKey: .label)) ?? "白日在线"
        promptHint = (try? c.decode(String.self, forKey: .promptHint)) ?? ""
    }
}

struct CatgirlVitals: Codable, Equatable {
    var satiety: Int = 86
    var energy: Int = 90
    var treatsFed: Int = 0
    var headpats: Int = 0

    init() {}

    enum CodingKeys: String, CodingKey { case satiety, energy, treatsFed, headpats }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        satiety = (try? c.decode(Int.self, forKey: .satiety)) ?? 86
        energy = (try? c.decode(Int.self, forKey: .energy)) ?? 90
        treatsFed = (try? c.decode(Int.self, forKey: .treatsFed)) ?? 0
        headpats = (try? c.decode(Int.self, forKey: .headpats)) ?? 0
    }
}

struct RelationshipBondState: Codable, Equatable {
    var level: Int = 2
    var title: String = "热络默契"
    var desc: String = "已经摸清你的说话节奏，接梗与干活越来越顺手"
    var xp: Int = 95
    var nextLevelXp: Int = 240
    var progress: Double = 0.1
    var streakDays: Int = 1
    var totalTurns: Int = 0

    init() {}

    enum CodingKeys: String, CodingKey {
        case level, title, desc, xp, nextLevelXp, progress, streakDays, totalTurns
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = (try? c.decode(Int.self, forKey: .level)) ?? 2
        title = (try? c.decode(String.self, forKey: .title)) ?? "热络默契"
        desc = (try? c.decode(String.self, forKey: .desc)) ?? ""
        xp = (try? c.decode(Int.self, forKey: .xp)) ?? 95
        nextLevelXp = (try? c.decode(Int.self, forKey: .nextLevelXp)) ?? 240
        progress = (try? c.decode(Double.self, forKey: .progress)) ?? 0.1
        streakDays = (try? c.decode(Int.self, forKey: .streakDays)) ?? 1
        totalTurns = (try? c.decode(Int.self, forKey: .totalTurns)) ?? 0
    }
}

struct HeartbeatConfigState: Codable, Equatable {
    var proactiveEnabled: Bool = true
    var minIdleMinutes: Int = 180
    var proactiveCountToday: Int = 0
    var autoExpandThoughts: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case proactiveEnabled, minIdleMinutes, proactiveCountToday, autoExpandThoughts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        proactiveEnabled = (try? c.decode(Bool.self, forKey: .proactiveEnabled)) ?? true
        minIdleMinutes = (try? c.decode(Int.self, forKey: .minIdleMinutes)) ?? 180
        proactiveCountToday = (try? c.decode(Int.self, forKey: .proactiveCountToday)) ?? 0
        autoExpandThoughts = (try? c.decode(Bool.self, forKey: .autoExpandThoughts)) ?? false
    }
}

struct SoulTelemetry: Codable, Equatable {
    var pad: PadEmotionState = PadEmotionState()
    var circadian: CircadianState = CircadianState()
    var vitals: CatgirlVitals = CatgirlVitals()
    var bond: RelationshipBondState = RelationshipBondState()
    var heartbeat: HeartbeatConfigState = HeartbeatConfigState()

    init() {}

    enum CodingKeys: String, CodingKey { case pad, circadian, vitals, bond, heartbeat }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pad = (try? c.decode(PadEmotionState.self, forKey: .pad)) ?? PadEmotionState()
        circadian = (try? c.decode(CircadianState.self, forKey: .circadian)) ?? CircadianState()
        vitals = (try? c.decode(CatgirlVitals.self, forKey: .vitals)) ?? CatgirlVitals()
        bond = (try? c.decode(RelationshipBondState.self, forKey: .bond)) ?? RelationshipBondState()
        heartbeat = (try? c.decode(HeartbeatConfigState.self, forKey: .heartbeat)) ?? HeartbeatConfigState()
    }
}

struct CatgirlDiaryEntry: Codable, Identifiable, Equatable {
    var id: String
    var at: String
    var title: String
    var content: String
    var moodEmoji: String
    var phaseLabel: String
    var evoVersion: Int

    enum CodingKeys: String, CodingKey { case id, at, title, content, moodEmoji, phaseLabel, evoVersion }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        at = (try? c.decode(String.self, forKey: .at)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? "日常心事"
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        moodEmoji = (try? c.decode(String.self, forKey: .moodEmoji)) ?? "🐾"
        phaseLabel = (try? c.decode(String.self, forKey: .phaseLabel)) ?? ""
        evoVersion = (try? c.decode(Int.self, forKey: .evoVersion)) ?? 1
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

    private static let isoFormatterMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

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
                  let d = Self.isoFormatterMs.date(from: str) ?? Self.isoFormatterPlain.date(from: str) {
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
    var innerThought: String
    var images: [ChatImageAttachment]

    enum CodingKeys: String, CodingKey { case id, kind, text, innerThought, images }

    init(id: String = UUID().uuidString, kind: String, text: String, innerThought: String = "", images: [ChatImageAttachment] = []) {
        self.id = id
        self.kind = kind
        self.text = text
        self.innerThought = innerThought
        self.images = images
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "assistant"
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        innerThought = (try? c.decode(String.self, forKey: .innerThought)) ?? ""
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
    var importance: Int
    var recallCount: Int
    var lastRecalledAt: String
    var strength: Double

    enum CodingKeys: String, CodingKey {
        case id, category, content, pinned, source, createdAt
        case importance, recallCount, lastRecalledAt, strength
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        category = (try? c.decode(String.self, forKey: .category)) ?? "preference"
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        let isPinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
        pinned = isPinned
        source = (try? c.decode(String.self, forKey: .source)) ?? "user"
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        importance = (try? c.decode(Int.self, forKey: .importance)) ?? (isPinned ? 5 : 3)
        recallCount = (try? c.decode(Int.self, forKey: .recallCount)) ?? 0
        lastRecalledAt = (try? c.decode(String.self, forKey: .lastRecalledAt)) ?? createdAt
        strength = (try? c.decode(Double.self, forKey: .strength)) ?? (isPinned ? 1.0 : 0.85)
    }
}

struct EvolutionHistoryItem: Codable, Identifiable, Equatable {
    var id: String
    var version: Int
    var at: String
    var summary: String
    var currentVibe: String
    var livingTraits: [String]
    var selfOptimizeRules: [String]?
}

struct PersonaEvolutionState: Codable, Equatable {
    var version: Int = 1
    var enabled: Bool = true
    var cycleEveryTurns: Int = 12
    var cycleEveryHours: Int = 24
    var turnsSinceLast: Int = 0
    var lastEvolvedAt: String = ""
    var currentVibe: String = ""
    var mindFlowActivity: String = ""
    var learnedExpressions: [String] = []
    var selfOptimizeRules: [String] = []
    var livingTraits: [String] = []
    var lastDiary: String = ""
    var history: [EvolutionHistoryItem] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, enabled, cycleEveryTurns, cycleEveryHours, turnsSinceLast
        case lastEvolvedAt, currentVibe, mindFlowActivity, learnedExpressions, selfOptimizeRules
        case livingTraits, lastDiary, history
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
        mindFlowActivity = (try? c.decode(String.self, forKey: .mindFlowActivity)) ?? ""
        learnedExpressions = (try? c.decode([String].self, forKey: .learnedExpressions)) ?? []
        selfOptimizeRules = (try? c.decode([String].self, forKey: .selfOptimizeRules)) ?? []
        livingTraits = (try? c.decode([String].self, forKey: .livingTraits)) ?? []
        lastDiary = (try? c.decode(String.self, forKey: .lastDiary)) ?? ""
        history = (try? c.decode([EvolutionHistoryItem].self, forKey: .history)) ?? []
    }
}

struct ContextPreviewResponse: Codable {
    var ok: Bool?
    var telemetry: SoulTelemetry?
    var mindFlow: String?
    var livingPersonaBlock: String?
    var sharedMemoryBlock: String?
    var activeRolePrompt: String?
}

struct OverviewResponse: Codable {
    var ok: Bool?
    var profile: UserAndPeerProfile?
    var telemetry: SoulTelemetry?
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

struct SoulStateResponse: Codable {
    var ok: Bool?
    var telemetry: SoulTelemetry?
    var diaryEntries: [CatgirlDiaryEntry]?
    var evolution: PersonaEvolutionState?
    var memoriesCount: Int?
}

struct SoulInteractResponse: Codable {
    var ok: Bool?
    var reactionToast: String?
    var telemetry: SoulTelemetry?
    var evolution: PersonaEvolutionState?
}

struct PairResponse: Codable {
    var ok: Bool?
    var pairKey: String?
    var error: String?
    var profile: UserAndPeerProfile?
}
