import SwiftUI

struct StarSeaObservatorySection: View {
    @EnvironmentObject var store: HajimiStore
    @Environment(\.scenePhase) private var scenePhase
    @Binding var showAddMemorySheet: Bool
    @State private var selectedMemoryId: String? = nil
    @State private var isCanvasVisible: Bool = false

    private var selectedMemory: SharedMemoryEntry? {
        if let id = selectedMemoryId, let found = store.memories.first(where: { $0.id == id }) {
            return found
        }
        return store.memories.first
    }

    private var averageStrengthPercent: Int {
        guard !store.memories.isEmpty else { return 100 }
        let sum = store.memories.reduce(0.0) { $0 + $1.strength }
        return Int(round((sum / Double(store.memories.count)) * 100))
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🌌 哈基米 · 记忆星海观测台")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("共 \(store.memories.count) 颗记忆星辰 · 平均留存率 \(averageStrengthPercent)%")
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    Button {
                        showAddMemorySheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("点亮新星")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.pink.opacity(0.82))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                starCanvasBox

                HStack(spacing: 8) {
                    legendDot(color: Color(red: 1.0, green: 0.45, blue: 0.72), label: "喜好")
                    legendDot(color: Color(red: 1.0, green: 0.80, blue: 0.30), label: "约定")
                    legendDot(color: Color(red: 0.35, green: 0.82, blue: 1.0), label: "工程")
                    legendDot(color: Color(red: 0.72, green: 0.55, blue: 1.0), label: "习惯")
                    legendDot(color: Color(red: 0.42, green: 0.92, blue: 0.75), label: "经历")
                    Spacer()
                }
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.18),
                        Color(red: 0.10, green: 0.11, blue: 0.28),
                        Color(red: 0.16, green: 0.09, blue: 0.29)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowBackground(Color.clear)

            if let sel = selectedMemory {
                selectedStarInspector(sel)
            }
        } header: {
            Text("艾宾浩斯遗忘曲线 × 海马体联想唤醒（点击星辰查看/强化）")
        }
    }

    private var starCanvasBox: some View {
        GeometryReader { geo in
            let size = geo.size
            let shouldPause = store.memories.isEmpty || !isCanvasVisible || scenePhase != .active
            TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: shouldPause)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    Canvas { context, canvasSize in
                        drawOrbitalRings(context: &context, size: canvasSize)
                        drawBackgroundDust(context: &context, size: canvasSize, time: t)

                        let mems = Array(store.memories.prefix(48))
                        var coords: [(mem: SharedMemoryEntry, pt: CGPoint)] = []
                        for (idx, m) in mems.enumerated() {
                            let pt = starPosition(for: m, index: idx, total: max(1, mems.count), size: canvasSize, time: t)
                            coords.append((m, pt))
                        }

                        // Constellation links for same-category memories
                        for i in 0..<coords.count {
                            for j in (i + 1)..<coords.count {
                                if coords[i].mem.category == coords[j].mem.category {
                                    let dx = coords[i].pt.x - coords[j].pt.x
                                    let dy = coords[i].pt.y - coords[j].pt.y
                                    let dist = hypot(dx, dy)
                                    if dist < min(canvasSize.width, canvasSize.height) * 0.36 {
                                        var line = Path()
                                        line.move(to: coords[i].pt)
                                        line.addLine(to: coords[j].pt)
                                        let col = starColor(for: coords[i].mem.category)
                                        context.stroke(line, with: .color(col.opacity(0.16)), lineWidth: 0.8)
                                    }
                                }
                            }
                        }

                        // Draw stars
                        let activeId = selectedMemory?.id
                        for (idx, item) in coords.enumerated() {
                            let m = item.mem
                            let pt = item.pt
                            let col = starColor(for: m.category)
                            let pulse = 0.88 + 0.12 * sin(t * 2.1 + Double(idx) * 0.9)
                            let strengthClamped = max(0.18, min(1.0, m.strength))
                            let baseRadius = CGFloat(3.2 + Double(max(1, min(5, m.importance))) * 0.85) * CGFloat(0.65 + 0.35 * strengthClamped)
                            let isSelected = (m.id == activeId)

                            // Outer glow
                            let glowR = baseRadius * (isSelected ? 3.8 : 2.5) * CGFloat(pulse)
                            let glowRect = CGRect(x: pt.x - glowR, y: pt.y - glowR, width: glowR * 2, height: glowR * 2)
                            context.fill(
                                Path(ellipseIn: glowRect),
                                with: .color(col.opacity((isSelected ? 0.42 : 0.22) * strengthClamped))
                            )

                            if isSelected {
                                let ringR = baseRadius + 6.5
                                let ringRect = CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2)
                                context.stroke(Path(ellipseIn: ringRect), with: .color(.white.opacity(0.88)), lineWidth: 1.4)
                            }

                            // Core star
                            let coreRect = CGRect(x: pt.x - baseRadius, y: pt.y - baseRadius, width: baseRadius * 2, height: baseRadius * 2)
                            context.fill(
                                Path(ellipseIn: coreRect),
                                with: .color(m.pinned ? Color(red: 1.0, green: 0.95, blue: 0.72) : col.opacity(0.55 + 0.45 * strengthClamped))
                            )
                        }
                    }
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { event in
                                handleStarTap(at: event.location, size: size, time: t)
                            }
                    )

                    if store.memories.isEmpty {
                        VStack(spacing: 6) {
                            Text("✨ 星海尚待点亮")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Text("日常聊天中提到的喜好、约定与习惯会自动凝结成记忆星辰")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .frame(height: 250)
        .background(Color.black.opacity(0.24))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onAppear { isCanvasVisible = true }
        .onDisappear { isCanvasVisible = false }
    }

    private func selectedStarInspector(_ mem: SharedMemoryEntry) -> some View {
        let retentionPct = Int(round(max(0, min(1, mem.strength)) * 100))
        let stars = String(repeating: "★", count: max(1, min(5, mem.importance)))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(categoryBadgeText(mem.category))
                    .font(.system(size: 11.5, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(starColor(for: mem.category).opacity(0.16))
                    .foregroundColor(starColor(for: mem.category))
                    .clipShape(Capsule())

                Text("重要度 \(stars)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)

                Spacer()

                Text(mem.pinned ? "📌 永恒恒星 (100%)" : "留存率 \(retentionPct)% · 唤醒 \(mem.recallCount) 次")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(retentionPct >= 70 ? .green : (retentionPct >= 40 ? .orange : .red))
            }

            Text(mem.content)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: max(0.05, min(1.0, mem.strength)))
                .tint(mem.pinned ? .orange : starColor(for: mem.category))

            HStack(spacing: 8) {
                Button {
                    Task { await store.reinforceMemory(id: mem.id) }
                } label: {
                    Label("强化唤醒", systemImage: "bolt.heart.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.12))
                        .foregroundColor(.purple)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await store.togglePinMemory(id: mem.id) }
                } label: {
                    Label(mem.pinned ? "取消置顶" : "设为恒星", systemImage: mem.pinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.14))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive) {
                    Task { await store.deleteMemory(id: mem.id) }
                } label: {
                    Label("遗忘", systemImage: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    private func handleStarTap(at location: CGPoint, size: CGSize, time: TimeInterval) {
        let mems = Array(store.memories.prefix(48))
        guard !mems.isEmpty else { return }
        var bestId: String? = nil
        var bestDist: CGFloat = 34.0
        for (idx, m) in mems.enumerated() {
            let pt = starPosition(for: m, index: idx, total: mems.count, size: size, time: time)
            let d = hypot(pt.x - location.x, pt.y - location.y)
            if d < bestDist {
                bestDist = d
                bestId = m.id
            }
        }
        if let hit = bestId {
            HapticsHelper.lightTap()
            selectedMemoryId = hit
        }
    }

    private func starPosition(for mem: SharedMemoryEntry, index: Int, total: Int, size: CGSize, time: TimeInterval) -> CGPoint {
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let minDim = min(size.width, size.height)

        var hash: UInt64 = 5381
        for b in mem.id.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(b)
        }
        let jitter = Double(hash % 1000) / 1000.0
        let baseAngle = (Double(index) / Double(max(1, total))) * (.pi * 2.0) + jitter * 1.15 + time * 0.025

        let orbitRatio: CGFloat
        if mem.pinned {
            orbitRatio = 0.17 + CGFloat(jitter) * 0.07
        } else if mem.strength >= 0.65 {
            orbitRatio = 0.28 + CGFloat(jitter) * 0.08
        } else {
            orbitRatio = 0.39 + CGFloat(jitter) * 0.07
        }
        let rx = (size.width * 0.46) * (orbitRatio / 0.46)
        let ry = (minDim * 0.45) * (orbitRatio / 0.46)
        return CGPoint(
            x: cx + CGFloat(cos(baseAngle)) * rx,
            y: cy + CGFloat(sin(baseAngle)) * ry
        )
    }

    private func drawOrbitalRings(context: inout GraphicsContext, size: CGSize) {
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let minDim = min(size.width, size.height)
        for ratio in [0.20, 0.33, 0.44] as [CGFloat] {
            let rx = size.width * ratio
            let ry = minDim * ratio
            let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.08)),
                style: StrokeStyle(lineWidth: 0.8, dash: [4, 4])
            )
        }
    }

    private func drawBackgroundDust(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<22 {
            let fx = CGFloat((Double(i * 73 + 19).truncatingRemainder(dividingBy: 97.0)) / 97.0)
            let fy = CGFloat((Double(i * 41 + 53).truncatingRemainder(dividingBy: 89.0)) / 89.0)
            let alpha = 0.12 + 0.14 * sin(time * 1.3 + Double(i))
            let rect = CGRect(x: fx * size.width, y: fy * size.height, width: 1.8, height: 1.8)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(max(0.04, alpha))))
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
        }
    }

    private func starColor(for category: String) -> Color {
        switch category {
        case "preference": return Color(red: 1.0, green: 0.45, blue: 0.72)
        case "promise": return Color(red: 1.0, green: 0.80, blue: 0.30)
        case "project": return Color(red: 0.35, green: 0.82, blue: 1.0)
        case "habit": return Color(red: 0.72, green: 0.55, blue: 1.0)
        case "episodic": return Color(red: 0.42, green: 0.92, blue: 0.75)
        default: return Color(red: 0.62, green: 0.88, blue: 0.78)
        }
    }

    private func categoryBadgeText(_ raw: String) -> String {
        switch raw {
        case "preference": return "❤️ 喜好偏好"
        case "promise": return "🤝 重要约定"
        case "project": return "🛠️ 项目工程"
        case "habit": return "🌙 生活习惯"
        case "episodic": return "✨ 共同经历"
        default: return "📌 记忆星辰"
        }
    }
}

struct CatgirlSecretDiarySection: View {
    @EnvironmentObject var store: HajimiStore
    @Binding var isEvolving: Bool

    var body: some View {
        Section {
            if store.diaryEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("📔")
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.profile.hajimiName)的秘密日记本还是空白的")
                                .font(.system(size: 14.5, weight: .bold))
                            Text("每次完成周期自我演化复盘时，她都会悄悄在这里写下一篇第一人称心情日记。")
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                        }
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
                            Text(isEvolving ? "正在复盘并写下第一篇秘密日记..." : "✍️ 让她现在复盘近期对话并写一篇日记")
                                .font(.system(size: 13.5, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .disabled(isEvolving)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(store.diaryEntries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(entry.moodEmoji)
                                .font(.system(size: 18))
                            Text(entry.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("v\(entry.evoVersion)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.14))
                                .foregroundColor(.pink)
                                .clipShape(Capsule())
                        }

                        Text(entry.content)
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.92))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            if !entry.phaseLabel.isEmpty {
                                Text(entry.phaseLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                            Spacer()
                            Text(formatIsoDate(entry.at))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        } header: {
            Text("📔 猫娘私密日记沉淀（随自我演化自动记录内心轨迹）")
        }
    }

    private func formatIsoDate(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let d = date else { return String(iso.prefix(16)) }
        let out = DateFormatter()
        out.dateFormat = "MM-dd HH:mm"
        return out.string(from: d)
    }
}
