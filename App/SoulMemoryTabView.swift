import SwiftUI

struct SoulMemoryTabView: View {
    @EnvironmentObject var store: HajimiStore
    @State private var showAddMemorySheet: Bool = false
    @State private var showEditTraitsSheet: Bool = false
    @State private var showContextInspector: Bool = false
    @State private var isEvolving: Bool = false

    var body: some View {
        NavigationStack {
            List {
                personaEvolutionSection
                sharedMemorySection
                if !store.evolution.history.isEmpty {
                    evolutionHistorySection
                }
            }
            .navigationTitle("🧠 记忆与人设演化")
            .refreshable {
                await store.loadMemories()
                await store.loadEvolution()
            }
            .sheet(isPresented: $showAddMemorySheet) {
                AddSharedMemorySheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showEditTraitsSheet) {
                EditLivingTraitsSheet(
                    initialVibe: store.evolution.currentVibe,
                    initialTraits: store.evolution.livingTraits
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showContextInspector) {
                ContextInspectorSheet()
                    .presentationDetents([.large])
            }
        }
    }

    private var personaEvolutionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🧬 当前自我微调状态 (v\(store.evolution.version))")
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
                Text("距下次自动微调进度")
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
                    Text(isEvolving ? "正在复盘记忆并轻微调整设定..." : "✨ 立即让她复盘并轻微微调一次人设")
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
            Text("特定周期轻微自我演化（锁死核心直白铁律，仅微调默契与小习惯）")
        }
    }

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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(categoryLabel(mem.category))
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())

                            if mem.source == "hajimi" {
                                Text("自动记住")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                            Spacer()
                            if mem.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }
                        }

                        Text(mem.content)
                            .font(.system(size: 14.5))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
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
            Text("🧠 跨会话共享记忆库 (\(store.memories.count) 条 · 所有会话通用)")
        }
    }

    private var evolutionHistorySection: some View {
        Section("🕰️ 人设微调历史记录（可一键回滚）") {
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
                            ProgressView("正在读取电脑端 DSH 实时上下文...")
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if let p = preview {
                        blockCard(title: "🌊 实时心流近况 (MindFlow)", text: p.mindFlow ?? "暂无")
                        blockCard(title: "🧬 动态演化人设层 (Living Persona)", text: p.livingPersonaBlock ?? "暂无")
                        blockCard(title: "🧠 跨会话共享记忆注入块 (Shared Memory)", text: p.sharedMemoryBlock ?? "暂无")
                        blockCard(title: "🔒 核心铁律底盘摘要", text: p.activeRolePrompt ?? "")
                    } else {
                        Text("无法读取上下文预览，请确认电脑端 DSH 已升级并保持连接。")
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
                }
                TextField("输入希望所有会话都记住的重要内容...", text: $content, axis: .vertical)
                    .lineLimit(3...6)
                Toggle("置顶核心记忆", isOn: $pinned)
            }
            .navigationTitle("新增跨会话共享记忆")
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
    @EnvironmentObject var store: HajimiStore
    @Environment(\.dismiss) private var dismiss
    @State private var vibe: String = ""
    @State private var traitsText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("当前相处氛围基调") {
                    TextField("一句话描述当前相处状态", text: $vibe, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("细节微调条目（每行一条，最多 6 条）") {
                    TextEditor(text: $traitsText)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("编辑自我演化设定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let lines = traitsText
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        Task {
                            await store.updateLivingTraits(currentVibe: vibe, traits: Array(lines.prefix(6)))
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                vibe = initialVibe
                traitsText = initialTraits.joined(separator: "\n")
            }
        }
    }
}
