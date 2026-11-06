import SwiftUI

struct MessagesTabView: View {
    @EnvironmentObject var store: HajimiStore
    @State private var selectedSessionId: String?
    @State private var showOtherSessions: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                qqHeader
                if !store.isConnected && !store.pairKey.isEmpty {
                    hotspotReconnectBanner
                }
                if store.pairKey.isEmpty {
                    QuickPairCardView()
                } else {
                    sessionListContent
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationDestination(item: $selectedSessionId) { sid in
                ChatRoomView(sessionId: sid)
                    .id(sid)
            }
            .onChange(of: store.pendingOpenSessionId) { _, targetSid in
                guard let targetSid = targetSid, !targetSid.isEmpty else { return }
                store.unreadBySession[targetSid] = 0
                selectedSessionId = targetSid
                store.pendingOpenSessionId = nil
            }
        }
    }

    private var hotspotReconnectBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "personalhotspot")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("网络切换或开启手机热点未连上？")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.primary)
                Text("当前目标：\(store.serverUrl.isEmpty ? "未设置" : store.serverUrl)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task { await store.autoScanLanServer() }
            } label: {
                HStack(spacing: 5) {
                    if store.isScanningLan {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(.white)
                    }
                    Text(store.isScanningLan ? "寻址中" : "秒连热点/Wi-Fi")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.orange)
                .clipShape(Capsule())
            }
            .disabled(store.isScanningLan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.orange.opacity(0.12))
        .overlay(Divider(), alignment: .bottom)
    }

    private var qqHeader: some View {
        HStack(spacing: 12) {
            CachedAvatarImage(
                urlString: store.hajimiAvatarFullUrl,
                pairKey: store.pairKey,
                size: 40
            ) {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .overlay(Text("🐾"))
            }
            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(store.profile.hajimiName) · 消息")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    if store.isConnected {
                        Text("Lv.\(store.telemetry.bond.level) \(store.telemetry.bond.title)")
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.22))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.isConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(
                        store.isConnected
                            ? "\(store.telemetry.circadian.emoji) \(store.telemetry.circadian.label) · \(store.telemetry.pad.moodEmoji)\(store.telemetry.pad.moodLabel)"
                            : "等待连接电脑 DSH"
                    )
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                }
            }

            Spacer()

            Menu {
                Button {
                    Task {
                        if let sid = await store.createNewSession(kind: "hajimi") {
                            selectedSessionId = sid
                        }
                    }
                } label: {
                    Label("新建「\(store.profile.hajimiName)」私聊", systemImage: "heart.text.square")
                }

                Button {
                    Task {
                        if let sid = await store.createNewSession(kind: "work") {
                            selectedSessionId = sid
                        }
                    }
                } label: {
                    Label("新建工程安排干活会话", systemImage: "hammer")
                }

                if let topSess = store.enabledSessions.first {
                    Button {
                        Task {
                            await store.forkSession(sessionId: topSess.id)
                        }
                    } label: {
                        Label("从「\(topSess.shortName)」新开分支", systemImage: "arrow.triangle.branch")
                    }
                }

                Divider()

                Button {
                    Task { await store.autoScanLanServer() }
                } label: {
                    Label("自动寻址热点 / Wi-Fi 电脑", systemImage: "personalhotspot")
                }

                Button {
                    Task { await store.refreshAll() }
                } label: {
                    Label("立即刷新同步", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.60, blue: 1.0),
                    Color(red: 0.23, green: 0.51, blue: 0.96),
                    Color(red: 0.48, green: 0.23, blue: 0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var sessionListContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !store.evolution.mindFlowActivity.isEmpty {
                    HStack(alignment: .center, spacing: 8) {
                        Text("🌊")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.profile.hajimiName)的此刻心流 · 🐟饱腹\(store.telemetry.vitals.satiety)%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.purple)
                            Text(store.evolution.mindFlowActivity)
                                .font(.system(size: 12.5))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Button {
                            Task { await store.interactWithCatgirl(action: "headpat") }
                        } label: {
                            Text("🐾 摸头")
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.pink.opacity(0.16))
                                .foregroundColor(.pink)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                }

                Text("📱 已开启直连的会话 (\(store.enabledSessions.count))")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, store.evolution.mindFlowActivity.isEmpty ? 12 : 2)

                if store.enabledSessions.isEmpty {
                    VStack(spacing: 10) {
                        Text("暂无已开启会话")
                            .font(.headline)
                        Text("点击右上角「＋」新建私聊，或在电脑 DSH 右上角打开「iOS直连 ON」")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.enabledSessions) { sess in
                            Button {
                                store.unreadBySession[sess.id] = 0
                                selectedSessionId = sess.id
                            } label: {
                                sessionRow(sess)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task {
                                        await store.forkSession(sessionId: sess.id)
                                    }
                                } label: {
                                    Label("从该会话新开分支", systemImage: "arrow.triangle.branch")
                                }

                                if sess.id != "session-hajimi-ios-main" {
                                    Button(role: .destructive) {
                                        Task {
                                            await store.toggleSessionEnabled(sessionId: sess.id, enabled: false)
                                        }
                                    } label: {
                                        Label("在手机列表中隐藏此会话", systemImage: "eye.slash")
                                    }
                                }
                            }

                            if sess.id != store.enabledSessions.last?.id {
                                Divider().padding(.leading, 76)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 12)
                }

                if !store.otherSessions.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showOtherSessions.toggle()
                        }
                    } label: {
                        HStack {
                            Text("💻 电脑端其他未开启会话 (\(store.otherSessions.count))")
                            Spacer()
                            Image(systemName: showOtherSessions ? "chevron.up" : "chevron.down")
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }

                    if showOtherSessions {
                        VStack(spacing: 0) {
                            ForEach(store.otherSessions) { other in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(other.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .lineLimit(1)
                                        Text(other.id)
                                            .font(.system(size: 11.5))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button("开启直连") {
                                        Task {
                                            await store.toggleSessionEnabled(sessionId: other.id, enabled: true)
                                        }
                                    }
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                if other.id != store.otherSessions.last?.id {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(14)
                        .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            if !store.isConnected {
                await store.autoScanLanServer(silent: true)
            }
            await store.refreshAll()
        }
    }

    private func sessionRow(_ sess: SessionCard) -> some View {
        let isRunning = sess.status == "running" || store.liveBySession[sess.id] != nil
        let unread = store.unreadBySession[sess.id] ?? 0
        let displayTitle = sess.roleId == "work" ? sess.title : (sess.id == "session-hajimi-ios-main" ? store.profile.hajimiName : sess.title)

        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if sess.roleId == "work" {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .overlay(Text("🛠️").font(.system(size: 22)))
                } else {
                    CachedAvatarImage(
                        urlString: store.hajimiAvatarFullUrl,
                        pairKey: store.pairKey,
                        size: 50
                    ) {
                        Circle().fill(Color.purple.opacity(0.15)).overlay(Text("💕"))
                    }
                }
                Circle()
                    .fill(isRunning ? Color.blue : Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(sess.roleBadge)
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())

                    Spacer()

                    if let ts = sess.updatedAtMs {
                        Text(formatTime(ts))
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text(isRunning ? "⚡ 正在处理 / 执行任务..." : (sess.lastPreview.isEmpty ? "点击开始实时聊天或安排干活" : sess.lastPreview))
                        .font(.system(size: 13.5))
                        .foregroundColor(isRunning ? .blue : .secondary)
                        .lineLimit(1)

                    Spacer()

                    if unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func formatTime(_ ms: Double) -> String {
        let d = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(d) ? "HH:mm" : "MM/dd HH:mm"
        return f.string(from: d)
    }
}

struct QuickPairCardView: View {
    @EnvironmentObject var store: HajimiStore
    @State private var urlInput: String = ""
    @State private var pinInput: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "personalhotspot")
                .font(.system(size: 46))
                .foregroundStyle(.blue)
            Text("连接电脑端 DSH")
                .font(.title3.bold())
            Text("支持同一 Wi-Fi 或直接开启 iPhone 个人热点给电脑连接，点「自动扫描」即可 0.2 秒寻址绑定。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                HStack {
                    TextField("http://172.20.10.x:19390", text: $urlInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, design: .monospaced))
                    Button(store.isScanningLan ? "扫描中..." : "自动扫描") {
                        Task {
                            await store.autoScanLanServer()
                            urlInput = store.serverUrl
                        }
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .disabled(store.isScanningLan)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                TextField("输入 6 位配对码", text: $pinInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 28)

            Button {
                Task {
                    _ = await store.pairWithPin(url: urlInput, code: pinInput)
                }
            } label: {
                Text("立即连接")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .onAppear {
            urlInput = store.serverUrl
        }
    }
}
