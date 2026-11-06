import SwiftUI

struct MessagesTabView: View {
    @EnvironmentObject var store: HajimiStore
    @State private var selectedSessionId: String?
    @State private var showOtherSessions: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                qqHeader
                if store.pairKey.isEmpty {
                    QuickPairCardView()
                } else {
                    sessionListContent
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationDestination(item: $selectedSessionId) { sid in
                ChatRoomView(sessionId: sid)
            }
        }
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
                Text("\(store.profile.hajimiName) · 消息")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.isConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(store.isConnected ? "同一 Wi-Fi 在线直连" : "等待连接电脑 DSH")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.92))
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

                Divider()

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
                Text("📱 已开启直连的会话 (\(store.enabledSessions.count))")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

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
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 46))
                .foregroundStyle(.blue)
            Text("连接电脑端 DSH")
                .font(.title3.bold())
            Text("确保 iPhone 与电脑连在同一 Wi-Fi，输入电脑 DSH 右上角「扫码」窗口显示的 6 位配对码即可永久绑定。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                HStack {
                    TextField("http://192.168.x.x:19390", text: $urlInput)
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
