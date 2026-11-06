import SwiftUI

struct SoulMemoryTabView: View {
    @EnvironmentObject var store: HajimiStore
    @State private var selectedSegment: Int = 0
    @State private var showAddMemorySheet: Bool = false
    @State private var showEditTraitsSheet: Bool = false
    @State private var showContextInspector: Bool = false
    @State private var isEvolving: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视图切换", selection: $selectedSegment) {
                    Text("🐾 生命内核").tag(0)
                    Text("🌌 记忆星海").tag(1)
                    Text("📔 秘密日记").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGroupedBackground))

                List {
                    if selectedSegment == 0 {
                        catgirlVitalsAndBondSection
                        proactiveHeartbeatSection
                        personaEvolutionSection
                        if !store.evolution.history.isEmpty {
                            evolutionHistorySection
                        }
                    } else if selectedSegment == 1 {
                        StarSeaObservatorySection(showAddMemorySheet: $showAddMemorySheet)
                        sharedMemorySection
                    } else {
                        CatgirlSecretDiarySection(isEvolving: $isEvolving)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("🧠 数字生命 SoulOS 3.0")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await store.loadSoulState()
                await store.loadMemories()
                await store.loadEvolution()
            }
            .task {
                await store.loadSoulState()
            }
            .sheet(isPresented: $showAddMemorySheet) {
                AddSharedMemorySheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showEditTraitsSheet) {
                EditLivingTraitsSheet(
                    initialVibe: store.evolution.currentVibe,
                    initialTraits: store.evolution.livingTraits,
                    initialRules: store.evolution.selfOptimizeRules
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showContextInspector) {
                ContextInspectorSheet()
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - 1. Catgirl Vitals, 3D PAD Emotion & Bond Level
    private var catgirlVitalsAndBondSection: some View {
        let tel = store.telemetry
        return Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    CachedAvatarImage(
                        urlString: store.hajimiAvatarFullUrl,
                        pairKey: store.pairKey,
                        size: 52
                    ) {
                        Circle().fill(Color.pink.opacity(0.18)).overlay(Text("🐱"))
                    }
                    .overlay(Circle().stroke(Color.pink.opacity(0.45), lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(store.profile.hajimiName)
                                .font(.system(size: 16.5, weight: .bold))
                            Text("Lv.\(tel.bond.level) \(tel.bond.title)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2.5)
                                .background(
                                    LinearGradient(
                                        colors: [Color.pink.opacity(0.20), Color.purple.opacity(0.20)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.pink)
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 6) {
                            Text("\(tel.circadian.emoji) \(tel.circadian.label)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.indigo)
                            Text("·")
                                .foregroundColor(.secondary)
                            Text("\(tel.pad.moodEmoji) \(tel.pad.moodLabel)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("🔥 \(tel.bond.streakDays)天")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text("共\(tel.bond.totalTurns)轮")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                }

                // Bond XP Progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("💞 灵魂羁绊进度：\(tel.bond.desc)")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(tel.bond.xp)/\(tel.bond.nextLevelXp)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.pink)
                    }
                    ProgressView(value: max(0.03, min(1.0, tel.bond.progress)))
                        .tint(.pink)
                }

                // Vitals: Satiety & Energy
                HStack(spacing: 12) {
                    vitalMeter(
                        icon: "🐟",
                        title: "饱腹度",
                        percent: tel.vitals.satiety,
                        tint: tel.vitals.satiety < 35 ? .orange : .mint
                    )
                    vitalMeter(
                        icon: "⚡",
                        title: "精力值",
                        percent: tel.vitals.energy,
                        tint: tel.vitals.energy < 30 ? .purple : .blue
                    )
                }

                // 3D PAD Emotion Coordinates
                VStack(alignment: .leading, spacing: 6) {
                    Text("🎛️ 三维 PAD 情绪稳态场（随对话刺激跳动 · 随昼夜自然回归）")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        padBadge(name: "愉悦 P", val: tel.pad.pleasure, color: .pink)
                        padBadge(name: "唤醒 A", val: tel.pad.arousal, color: .orange)
                        padBadge(name: "主动 D", val: tel.pad.dominance, color: .indigo)
                    }
                }

                // 4 Care Interaction Buttons
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    careButton(emoji: "🐟", title: "投喂小鱼干", subtitle: "已喂 \(tel.vitals.treatsFed) 次", action: "feed_fish")
                    careButton(emoji: "🐾", title: "摸头顺顺毛", subtitle: "已摸 \(tel.vitals.headpats) 次", action: "headpat")
                    careButton(emoji: "🪶", title: "逗猫棒玩耍", subtitle: "唤醒活力 +A", action: "play_teaser")
                    careButton(emoji: "💤", title: "哄她小憩", subtitle: "恢复满格精力", action: "nap_rest")
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)
        } header: {
            Text("🐱 猫娘生命体征与三维情绪场")
        }
    }

    private func vitalMeter(icon: String, title: String, percent: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(icon) \(title)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundColor(tint)
            }
            ProgressView(value: Double(max(0, min(100, percent))) / 100.0)
                .tint(tint)
        }
        .padding(9)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private func padBadge(name: String, val: Double, color: Color) -> some View {
        let norm = max(0.0, min(1.0, (val + 1.0) / 2.0))
        let signStr = String(format: "%+.2f", val)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(signStr)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.16))
                    Capsule()
                        .fill(color.opacity(0.82))
                        .frame(width: max(6, g.size.width * norm))
                }
            }
            .frame(height: 5)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.07))
        .cornerRadius(9)
    }

    private func careButton(emoji: String, title: String, subtitle: String, action: String) -> some View {
        Button {
            Task { await store.interactWithCatgirl(action: action) }
        } label: {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(11)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Autonomous Heartbeat & Subconscious Mind-Reading
    private var proactiveHeartbeatSection: some View {
        let hb = store.telemetry.heartbeat
        return Section {
            Toggle(
                "💓 允许闲暇时主动发消息关心我",
                isOn: Binding(
                    get: { hb.proactiveEnabled },
                    set: { v in
                        Task { await store.updateHeartbeatConfig(proactiveEnabled: v) }
                    }
                )
            )

            Picker(
                "主动搭话安静间隔",
                selection: Binding(
                    get: { hb.minIdleMinutes },
                    set: { mins in
                        Task { await store.updateHeartbeatConfig(minIdleMinutes: mins) }
                    }
                )
            ) {
                Text("闲置 90 分钟后").tag(90)
                Text("闲置 3 小时后 (推荐)").tag(180)
                Text("闲置 5 小时后").tag(300)
                Text("闲置 8 小时后").tag(480)
            }

            Toggle(
                "💭 聊天室默认展开「偷看心声」",
                isOn: Binding(
                    get: { hb.autoExpandThoughts },
                    set: { v in
                        Task { await store.updateHeartbeatConfig(autoExpandThoughts: v) }
                    }
                )
            )

            Button {
                let targetSid = store.enabledSessions.first(where: { $0.roleId != "work" })?.id
                Task { await store.triggerProactiveGreetingNow(sessionId: targetSid) }
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("💌 现在让她主动发一条贴心搭话（今日已主动 \(hb.proactiveCountToday) 次）")
                        .font(.system(size: 13.5, weight: .semibold))
                }
            }
        } header: {
            Text("自主心跳节律 & 猫耳读心术（深夜 01:00–08:00 自动静音免打扰）")
        }
    }

    // MARK: - 3. 4D Self-Evolving Persona Section
    private var personaEvolutionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🧬 四维自我更迭状态 (v\(store.evolution.version))")
                        .font(.system(size: 14.5, weight: .bold))
                    Spacer()
                    Button("手动编辑") {
                        showEditTraitsSheet = true
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                }

                if !store.evolution.mindFlowActivity.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Text("🌊")
                        Text("此刻心流：\(store.evolution.mindFlowActivity)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                }

                if !store.evolution.currentVibe.isEmpty {
                    Text(store.evolution.currentVibe)
                        .font(.system(size: 13.5))
                        .foregroundColor(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(10)
                }

                if !store.evolution.selfOptimizeRules.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("🧭 自主总结的交互进化准则：")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.indigo)
                        ForEach(Array(store.evolution.selfOptimizeRules.enumerated()), id: \.offset) { _, rule in
                            HStack(alignment: .top, spacing: 6) {
                                Text("✦")
                                    .foregroundColor(.indigo)
                                    .font(.system(size: 11, weight: .bold))
                                Text(rule)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.88))
                            }
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.indigo.opacity(0.07))
                    .cornerRadius(10)
                }

                if !store.evolution.learnedExpressions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🗣️ 已吸收的表达默契：")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(store.evolution.learnedExpressions, id: \.self) { expr in
                                    Text(expr)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.pink.opacity(0.12))
                                        .foregroundColor(.pink)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                ForEach(Array(store.evolution.livingTraits.enumerated()), id: \.offset) { _, trait in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.purple)
                            .bold()
                        Text(trait)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                if !store.evolution.lastDiary.isEmpty {
                    Text("💭 最近演化心声：\(store.evolution.lastDiary)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)

            Toggle(
                "开启特定周期自动微调人设",
                isOn: Binding(
                    get: { store.evolution.enabled },
                    set: { newVal in
                        Task {
                            await store.updateEvolutionConfig(
                                enabled: newVal,
                                cycleEveryTurns: store.evolution.cycleEveryTurns,
                                cycleEveryHours: store.evolution.cycleEveryHours
                            )
                        }
                    }
                )
            )

            Picker(
                "触发对话轮数周期",
                selection: Binding(
                    get: { store.evolution.cycleEveryTurns },
                    set: { turns in
                        Task {
                            await store.updateEvolutionConfig(
                                enabled: store.evolution.enabled,
                                cycleEveryTurns: turns,
                                cycleEveryHours: store.evolution.cycleEveryHours
                            )
                        }
                    }
                )
            ) {
                Text("每 5 轮对话").tag(5)
                Text("每 12 轮对话 (推荐)").tag(12)
                Text("每 20 轮对话").tag(20)
                Text("每 35 轮对话").tag(35)
            }

            HStack {
                Text("距下次自动演化进度")
                    .font(.system(size: 13.5))
                Spacer()
                Text("\(store.evolution.turnsSinceLast) / \(store.evolution.cycleEveryTurns) 轮")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.blue)
            }

            Button {
                guard !isEvolving else { return }
                isEvolving = true
                Task {
                    await store.triggerEvolveNow()
                    isEvolving = false
                }
            } label: {
                HStack {
                    if isEvolving {
                        ProgressView().padding(.trailing, 4)
                    }
                    Text(isEvolving ? "正在复盘记忆、自我更迭并写日记..." : "✨ 立即让她复盘并自我更迭一次")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(isEvolving)

            Button {
                showContextInspector = true
            } label: {
                Label("🕵️ 潜意识上下文透视镜（查看实时注入提示词）", systemImage: "eye.circle")
                    .font(.system(size: 13.5, weight: .medium))
            }
        } header: {
            Text("特定周期自我更迭（锁死核心直白铁律，进化默契与交互策略）")
        }
    }

    // MARK: - 4. Shared Memory List (with Ebbinghaus Strength + Swipe Reinforce/Pin/Delete)
    private var sharedMemorySection: some View {
        Section {
            Button {
                showAddMemorySheet = true
            } label: {
                Label("手动新增一条跨会话共享记忆", systemImage: "plus.circle.fill")
                    .font(.system(size: 14.5, weight: .semibold))
            }

            if store.memories.isEmpty {
                Text("暂无共享记忆。聊天中提到的重要偏好、约定或项目细节，\(store.profile.hajimiName)会自动记在这里，跨会话永久生效。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(store.memories) { mem in
                    let pct = Int(round(max(0, min(1, mem.strength)) * 100))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(categoryLabel(mem.category))
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())

                            if mem.source == "hajimi" {
                                Text("自动凝结")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.purple)
                            }

                            Spacer()

                            Text(mem.pinned ? "📌 恒星 100%" : "留存 \(pct)%")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(mem.pinned ? .orange : (pct >= 70 ? .green : .secondary))
                        }

                        Text(mem.content)
                            .font(.system(size: 14.5))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await store.reinforceMemory(id: mem.id) }
                        } label: {
                            Label("强化", systemImage: "bolt.heart.fill")
                        }
                        .tint(.purple)

                        Button {
                            Task { await store.togglePinMemory(id: mem.id) }
                        } label: {
                            Label(mem.pinned ? "取消置顶" : "置顶", systemImage: "pin.fill")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await store.deleteMemory(id: mem.id) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("🧠 全部记忆星辰清单 (\(store.memories.count) 条 · 右滑强化/置顶)")
        }
    }

    private var evolutionHistorySection: some View {
        Section("🕰️ 人设更迭历史记录（可一键回滚）") {
            ForEach(store.evolution.history) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("v\(item.version) · \(item.summary)")
                            .font(.system(size: 13.5, weight: .semibold))
                        Text(item.currentVibe)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("回滚") {
                        Task { await store.revertEvolution(historyId: item.id) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func categoryLabel(_ raw: String) -> String {
        switch raw {
        case "preference": return "❤️ 喜好偏好"
        case "promise": return "🤝 重要约定"
        case "project": return "🛠️ 项目工程"
        case "habit": return "🌙 生活习惯"
        case "episodic": return "✨ 共同经历"
        default: return "📌 重要记忆"
        }
    }
}

struct ContextInspectorSheet: View {
    @EnvironmentObject var store: HajimiStore
    @Environment(\.dismiss) private var dismiss
    @State private var preview: ContextPreviewResponse?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("正在读取电脑端 DSH 实时潜意识上下文...")
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if let p = preview {
                        if let tel = p.telemetry {
                            blockCard(
                                title: "🎛️ SoulOS 3.0 情绪与昼夜遥测",
                                text: "昼夜节律：\(tel.circadian.emoji) \(tel.circadian.label)\n实时心情：\(tel.pad.moodEmoji) \(tel.pad.moodLabel) (P=\(String(format: "%+.2f", tel.pad.pleasure)), A=\(String(format: "%+.2f", tel.pad.arousal)), D=\(String(format: "%+.2f", tel.pad.dominance)))\n生命体征：饱腹 \(tel.vitals.satiety)% · 精力 \(tel.vitals.energy)% · 羁绊 Lv.\(tel.bond.level) \(tel.bond.title)"
                            )
                        }
                        blockCard(title: "🌊 实时心流近况 (MindFlow)", text: p.mindFlow ?? "暂无")
                        blockCard(title: "🧬 四维自我更迭人设块 (Living Persona)", text: p.livingPersonaBlock ?? "暂无")
                        blockCard(title: "🌌 海马体按需检索记忆注入块 (Hippocampus Recall)", text: p.sharedMemoryBlock ?? "暂无")
                        blockCard(title: "🔒 核心铁律底盘摘要", text: p.activeRolePrompt ?? "")
                    } else {
                        Text("无法读取上下文预览，请确认电脑端 DSH 已连接。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("🕵️ 潜意识上下文透视镜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                preview = await store.fetchContextPreview()
                isLoading = false
            }
        }
    }

    private func blockCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.blue)
            Text(text.isEmpty ? "（空）" : text)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)
        }
    }
}

struct AddSharedMemorySheet: View {
    @EnvironmentObject var store: HajimiStore
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var category: String = "preference"
    @State private var pinned: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Picker("分类", selection: $category) {
                    Text("❤️ 喜好偏好").tag("preference")
                    Text("🤝 重要约定").tag("promise")
                    Text("🛠️ 项目工程").tag("project")
                    Text("🌙 生活习惯").tag("habit")
                    Text("✨ 共同经历").tag("episodic")
                }
                TextField("输入希望所有会话都记住的重要内容...", text: $content, axis: .vertical)
                    .lineLimit(3...6)
                Toggle("设为永恒核心记忆（100% 不随遗忘曲线淡化）", isOn: $pinned)
            }
            .navigationTitle("点亮新记忆星辰")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let txt = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !txt.isEmpty else { return }
                        Task {
                            await store.saveMemory(content: txt, category: category, pinned: pinned)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct EditLivingTraitsSheet: View {
    let initialVibe: String
    let initialTraits: [String]
    let initialRules: [String]
    @EnvironmentObject var store: HajimiStore
    @Environment(\.dismiss) private var dismiss
    @State private var vibe: String = ""
    @State private var traitsText: String = ""
    @State private var rulesText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("当前相处氛围基调") {
                    TextField("一句话描述当前相处状态", text: $vibe, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("自我进化交互准则（每行一条，最多 5 条）") {
                    TextEditor(text: $rulesText)
                        .frame(minHeight: 110)
                }
                Section("生活小习惯与默契（每行一条，最多 6 条）") {
                    TextEditor(text: $traitsText)
                        .frame(minHeight: 130)
                }
            }
            .navigationTitle("编辑四维演化设定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let traitLines = traitsText
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        let ruleLines = rulesText
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        Task {
                            await store.updateLivingTraits(
                                currentVibe: vibe,
                                traits: Array(traitLines.prefix(6)),
                                selfOptimizeRules: Array(ruleLines.prefix(5))
                            )
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                vibe = initialVibe
                traitsText = initialTraits.joined(separator: "\n")
                rulesText = initialRules.joined(separator: "\n")
            }
        }
    }
}
