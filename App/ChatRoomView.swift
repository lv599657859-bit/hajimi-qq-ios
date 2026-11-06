import SwiftUI
import UIKit
import PhotosUI

struct PreviewImageItem: Identifiable {
    let id = UUID()
    let url: String
    let localData: Data?
}

struct ChatRoomView: View {
    let sessionId: String
    @EnvironmentObject var store: HajimiStore
    @State private var draftText: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var pendingImageData: [Data] = []
    @State private var showModelSheet: Bool = false
    @State private var showPortraitSheet: Bool = false
    @State private var showQuickTasks: Bool = false
    @State private var pokeAnimatingId: String? = nil
    @State private var quotingMessage: ChatMessageItem? = nil
    @State private var viewingImageItem: PreviewImageItem? = nil

    private var session: SessionCard {
        store.enabledSessions.first(where: { $0.id == sessionId })
            ?? SessionCard(id: sessionId, title: store.profile.hajimiName, shortName: store.profile.hajimiName)
    }

    private var messages: [ChatMessageItem] {
        store.messagesBySession[sessionId] ?? []
    }

    private var liveStatus: LiveStreamingStatus? {
        store.liveBySession[sessionId]
    }

    private var isBusy: Bool {
        session.status == "running" || liveStatus != nil
    }

    private var peerDisplayName: String {
        if session.roleId == "work" { return session.title }
        let base = store.profile.hajimiName
        switch session.roleId {
        case "mom": return "\(base) · 妈妈"
        case "daughter": return "\(base) · 女儿"
        case "pet": return "\(base) · 小猫"
        default: return "\(base) · 女友"
        }
    }

    private var myDisplayName: String {
        let custom = store.profile.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? session.userNick : custom
    }

    private let roleOptions: [(id: String, label: String)] = [
        ("girlfriend", "💕女友"),
        ("mom", "🤱妈妈"),
        ("daughter", "🍼女儿"),
        ("pet", "🐾宠物"),
        ("work", "💻干活")
    ]

    var body: some View {
        VStack(spacing: 0) {
            quickControlStrip
            messagesArea
            if isBusy {
                workingStatusBar
            }
            composerBar
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showPortraitSheet = true
                } label: {
                    HStack(spacing: 8) {
                        if session.roleId != "work" {
                            CachedAvatarImage(
                                urlString: store.hajimiAvatarFullUrl,
                                pairKey: store.pairKey,
                                size: 30
                            ) {
                                Circle().fill(Color.purple.opacity(0.2)).overlay(Text("💕"))
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(session.roleId == "work" ? session.title : store.profile.hajimiName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(isBusy ? (liveStatus?.toolStatus.isEmpty == false ? "⚡ \(liveStatus!.toolStatus)" : "💭 正在输入...") : "🟢 在线 · \(session.roleBadge)")
                                .font(.system(size: 10.5))
                                .foregroundColor(isBusy ? .blue : .secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPortraitSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Text(session.portrait.emoji)
                        Text(session.portrait.tag)
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showModelSheet) {
            ModelSwitcherSheet(session: session)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPortraitSheet) {
            PortraitMoodSheet(session: session, onPreviewImage: { urlStr in
                showPortraitSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    viewingImageItem = PreviewImageItem(url: urlStr, localData: nil)
                }
            })
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $viewingImageItem) { item in
            FullScreenImageViewer(
                imageUrl: item.url,
                localData: item.localData,
                pairKey: store.pairKey,
                onClose: { viewingImageItem = nil }
            )
        }
        .onAppear {
            store.activeViewingSessionId = sessionId
            store.unreadBySession[sessionId] = 0
            Task { await store.loadHistory(sessionId: sessionId) }
        }
        .onDisappear {
            if store.activeViewingSessionId == sessionId {
                store.activeViewingSessionId = nil
            }
        }
        .onChange(of: selectedPhotos) { _, items in
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        pendingImageData.append(data)
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }

    private var quickControlStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Button {
                    showModelSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text(session.modelLabel)
                            .font(.system(size: 11.5, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                }

                Divider().frame(height: 14)

                ForEach(roleOptions, id: \.id) { role in
                    let isSelected = session.roleId == role.id
                    Button {
                        Task { await store.switchPersona(sessionId: sessionId, roleId: role.id) }
                    } label: {
                        Text(role.label)
                            .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                isSelected
                                    ? LinearGradient(colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.22)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color(uiColor: .secondarySystemGroupedBackground)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .overlay(
                                Capsule().stroke(isSelected ? Color.pink.opacity(0.55) : Color.secondary.opacity(0.18), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(Color(uiColor: .systemBackground).opacity(0.94))
        .overlay(Divider(), alignment: .bottom)
    }

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if messages.isEmpty && liveStatus == nil {
                        Text("双击头像可「戳一戳」，长按气泡可贴表情 / 引用回复 / 存入记忆 ✨")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 8)
                    }

                    ForEach(messages) { msg in
                        messageRowView(msg)
                            .id(msg.id)
                    }

                    if let live = liveStatus, !live.text.isEmpty {
                        messageRowView(ChatMessageItem(id: "live-streaming", kind: "assistant", text: live.text))
                            .id("live-streaming")
                    }

                    Color.clear.frame(height: 2).id("bottom-anchor")
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            }
            .onChange(of: liveStatus?.text) { _, _ in
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func messageRowView(_ msg: ChatMessageItem) -> some View {
        let reactions = store.reactionsByMsgId[msg.id] ?? []
        if msg.kind == "system" {
            Text(msg.text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.14))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
        } else if msg.kind == "user" {
            HStack(alignment: .top, spacing: 9) {
                Spacer(minLength: 42)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(myDisplayName)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)

                    VStack(alignment: .trailing, spacing: 6) {
                        ForEach(msg.images) { im in
                            attachmentBubbleImage(im)
                        }
                        if !msg.text.isEmpty {
                            Text(msg.text)
                                .font(.system(size: 15.5))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.60, blue: 1.0), Color(red: 0.11, green: 0.55, blue: 0.97)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 4))
                    .contextMenu {
                        bubbleContextMenuItems(msg)
                    }

                    if !reactions.isEmpty {
                        reactionBar(msgId: msg.id, reactions: reactions)
                    }
                }

                ownerAvatarView
            }
        } else {
            HStack(alignment: .top, spacing: 9) {
                peerAvatarView(animId: msg.id)

                VStack(alignment: .leading, spacing: 4) {
                    Text(peerDisplayName)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(msg.images) { im in
                            attachmentBubbleImage(im)
                        }
                        Text(msg.text)
                            .font(.system(size: 15.5))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                    .contextMenu {
                        bubbleContextMenuItems(msg)
                    }

                    if !reactions.isEmpty {
                        reactionBar(msgId: msg.id, reactions: reactions)
                    }
                }
                Spacer(minLength: 42)
            }
        }
    }

    @ViewBuilder
    private func bubbleContextMenuItems(_ msg: ChatMessageItem) -> some View {
        if msg.id != "live-streaming" {
            Button("❤️ 偏爱") { store.toggleReaction(msgId: msg.id, emoji: "❤️") }
            Button("😂 笑死") { store.toggleReaction(msgId: msg.id, emoji: "😂") }
            Button("🥺 抱抱") { store.toggleReaction(msgId: msg.id, emoji: "🥺") }
            Button("💢 记仇") { store.toggleReaction(msgId: msg.id, emoji: "💢") }

            Divider()

            Button {
                HapticsHelper.lightTap()
                quotingMessage = msg
            } label: {
                Label("引用回复", systemImage: "arrowshape.turn.up.left")
            }

            if !msg.text.isEmpty {
                Button {
                    Task {
                        await store.saveMemory(content: msg.text, category: "memory", pinned: false)
                    }
                } label: {
                    Label("存入跨会话共享记忆", systemImage: "brain.head.profile")
                }

                Button {
                    UIPasteboard.general.string = msg.text
                    store.showToast("已复制文字")
                } label: {
                    Label("复制文字", systemImage: "doc.on.doc")
                }
            }

            if msg.kind == "assistant" {
                Button {
                    sendQuick("刚才那句换个更自然直白的说法重说一次")
                } label: {
                    Label("让她换个说法重说", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
    }

    private func reactionBar(msgId: String, reactions: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(reactions, id: \.self) { emoji in
                Button {
                    store.toggleReaction(msgId: msgId, emoji: emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 13))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.pink.opacity(0.14))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func peerAvatarView(animId: String) -> some View {
        let isBouncing = pokeAnimatingId == animId
        return Group {
            if session.roleId == "work" {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .overlay(Text("🛠️"))
            } else {
                CachedAvatarImage(
                    urlString: store.hajimiAvatarFullUrl,
                    pairKey: store.pairKey,
                    size: 40
                ) {
                    Circle().fill(Color.purple.opacity(0.2)).overlay(Text("💕"))
                }
            }
        }
        .scaleEffect(isBouncing ? 1.2 : 1.0)
        .rotationEffect(.degrees(isBouncing ? -10 : 0))
        .animation(.spring(response: 0.26, dampingFraction: 0.42), value: isBouncing)
        .onTapGesture(count: 2) {
            pokeAnimatingId = animId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                pokeAnimatingId = nil
            }
            Task { await store.triggerPoke(session: session) }
        }
    }

    private var ownerAvatarView: some View {
        Group {
            if store.profile.hasCustomOwnerAvatar {
                CachedAvatarImage(
                    urlString: store.ownerAvatarFullUrl,
                    pairKey: store.pairKey,
                    size: 40
                ) {
                    defaultOwnerBadge
                }
            } else {
                defaultOwnerBadge
            }
        }
    }

    private var defaultOwnerBadge: some View {
        Circle()
            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(myDisplayName.prefix(1)))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    @ViewBuilder
    private func attachmentBubbleImage(_ im: ChatImageAttachment) -> some View {
        let remoteUrl = store.attachmentUrl(sessionId: sessionId, attachmentId: im.id)
        if let localData = im.localPreviewData, let uiImg = UIImage(data: localData) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 210, maxHeight: 240)
                .cornerRadius(10)
                .onTapGesture {
                    viewingImageItem = PreviewImageItem(url: remoteUrl, localData: localData)
                }
        } else if let url = URL(string: remoteUrl) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 210, maxHeight: 240)
                        .cornerRadius(10)
                        .onTapGesture {
                            viewingImageItem = PreviewImageItem(url: remoteUrl, localData: nil)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 140, height: 100)
                        .overlay(ProgressView())
                }
            }
        }
    }

    private var workingStatusBar: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text(liveStatus?.toolStatus.isEmpty == false ? liveStatus!.toolStatus : "正在处理消息 / 调用工具...")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.blue)
                .lineLimit(1)
            Spacer()
            Button("⏹ 停止") {
                Task { await store.cancelTurn(sessionId: sessionId) }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.red)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.blue.opacity(0.09))
    }

    private var composerBar: some View {
        VStack(spacing: 8) {
            if let q = quotingMessage {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 3, height: 28)
                        .clipShape(Capsule())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("引用 \(q.kind == "user" ? myDisplayName : store.profile.hajimiName)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                        Text(q.text.isEmpty ? "[图片]" : q.text)
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        quotingMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.horizontal, 10)
            }

            if !pendingImageData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(pendingImageData.enumerated()), id: \.offset) { idx, data in
                            if let img = UIImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        pendingImageData.remove(at: idx)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .red)
                                    }
                                    .offset(x: 5, y: -5)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 4, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(Circle())
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showQuickTasks.toggle()
                    }
                } label: {
                    Image(systemName: "bolt.circle")
                        .font(.system(size: 19))
                        .foregroundColor(showQuickTasks ? .blue : .primary)
                        .frame(width: 36, height: 36)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(Circle())
                }

                TextField("发消息或安排干活...", text: $draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(18)

                Button {
                    var txt = draftText
                    if let q = quotingMessage {
                        let snippet = String((q.text.isEmpty ? "[图片]" : q.text).prefix(60)).replacingOccurrences(of: "\n", with: " ")
                        txt = "「引用：\(snippet)」\n\(txt)"
                    }
                    let imgs = pendingImageData
                    draftText = ""
                    quotingMessage = nil
                    pendingImageData.removeAll()
                    showQuickTasks = false
                    Task {
                        await store.sendMessage(sessionId: sessionId, text: txt, jpegImages: imgs)
                    }
                } label: {
                    Text("发送")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 15)
                        .frame(height: 36)
                        .background(Color(red: 0.0, green: 0.60, blue: 1.0))
                        .clipShape(Capsule())
                }
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImageData.isEmpty)
            }
            .padding(.horizontal, 10)

            if showQuickTasks {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    quickActionBtn("👉 戳一戳她") {
                        showQuickTasks = false
                        Task { await store.triggerPoke(session: session) }
                    }
                    quickActionBtn("📂 查工作区改动") {
                        sendQuick("帮我看一下当前工作区 git status 和最近修改了哪些文件，简短汇报结论")
                    }
                    quickActionBtn("🔍 汇报任务进度") {
                        sendQuick("帮我检查当前进行中的任务进度，有问题直接直白告诉我")
                    }
                    quickActionBtn("🧠 记住刚才说的") {
                        sendQuick("把我们刚才聊到的重要偏好和约定记进你的共享记忆里")
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(Divider(), alignment: .top)
    }

    private func quickActionBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)
        }
    }

    private func sendQuick(_ prompt: String) {
        showQuickTasks = false
        Task {
            await store.sendMessage(sessionId: sessionId, text: prompt, jpegImages: [])
        }
    }
}

struct ModelSwitcherSheet: View {
    let session: SessionCard
    @EnvironmentObject var store: HajimiStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.providers.filter { !$0.models.isEmpty }) { prov in
                    Section(prov.name) {
                        ForEach(prov.models) { mod in
                            let isCurrentModel = session.modelSelection?.provider == prov.id && session.modelSelection?.model == mod.id
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    Task {
                                        await store.switchModel(sessionId: session.id, provider: prov.id, model: mod.id, effort: mod.defaultEffort)
                                        dismiss()
                                    }
                                } label: {
                                    HStack {
                                        Text(mod.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if isCurrentModel {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }

                                if !mod.efforts.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(mod.efforts) { ef in
                                                let curEff = session.modelSelection?.reasoningEffort ?? mod.defaultEffort
                                                let active = isCurrentModel && curEff == ef.id
                                                Button {
                                                    Task {
                                                        await store.switchModel(sessionId: session.id, provider: prov.id, model: mod.id, effort: ef.id)
                                                        dismiss()
                                                    }
                                                } label: {
                                                    Text("思考: \(ef.name)")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(active ? Color.blue : Color(uiColor: .secondarySystemFill))
                                                        .foregroundColor(active ? .white : .primary)
                                                        .clipShape(Capsule())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("⚡ 秒切模型与思考强度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct PortraitMoodSheet: View {
    let session: SessionCard
    var onPreviewImage: ((String) -> Void)? = nil
    @EnvironmentObject var store: HajimiStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if let url = URL(string: store.portraitFullUrl) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 360)
                                .cornerRadius(16)
                                .onTapGesture {
                                    onPreviewImage?(store.portraitFullUrl)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 260)
                                .overlay(ProgressView())
                        }
                    }
                }

                if !store.evolution.mindFlowActivity.isEmpty {
                    HStack(spacing: 6) {
                        Text("🌊 心流：\(store.evolution.mindFlowActivity)")
                            .font(.system(size: 12.5))
                            .foregroundColor(.purple)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(10)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(session.portrait.emoji) \(session.portrait.tag) · \(session.roleBadge)")
                            .font(.headline)
                        Text(session.portrait.desc)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("👉 戳一戳") {
                        dismiss()
                        Task { await store.triggerPoke(session: session) }
                    }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.pink)
                    .clipShape(Capsule())
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(14)

                Spacer()
            }
            .padding()
            .navigationTitle("\(store.profile.hajimiName) · 实时立绘状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
