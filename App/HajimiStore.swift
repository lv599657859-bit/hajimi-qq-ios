import Foundation
import SwiftUI
import Darwin

struct LiveStreamingStatus: Equatable {
    var text: String = ""
    var toolStatus: String = ""
}

@MainActor
final class HajimiStore: ObservableObject {
    @Published var serverUrl: String
    @Published var pairKey: String
    @Published var isConnected: Bool = false
    @Published var isScanningLan: Bool = false
    @Published var profile: UserAndPeerProfile = UserAndPeerProfile()
    @Published var enabledSessions: [SessionCard] = []
    @Published var otherSessions: [OtherSessionItem] = []
    @Published var messagesBySession: [String: [ChatMessageItem]] = [:]
    @Published var liveBySession: [String: LiveStreamingStatus] = [:]
    @Published var unreadBySession: [String: Int] = [:]
    @Published var providers: [ProviderCatalogEntry] = []
    @Published var memories: [SharedMemoryEntry] = []
    @Published var evolution: PersonaEvolutionState = PersonaEvolutionState()
    @Published var reactionsByMsgId: [String: [String]] = [:]
    @Published var toastMessage: String = ""

    var activeViewingSessionId: String? = nil
    var bootstrapFallbackUrls: [String] = []
    private var sseTask: Task<Void, Never>? = nil
    private var toastTask: Task<Void, Never>? = nil

    private let serverKey = "hjm_server_url_v2"
    private let authKey = "hjm_pair_key_v2"
    private let reactionsKey = "hjm_msg_reactions_v1"

    init() {
        var initialUrl = UserDefaults.standard.string(forKey: serverKey) ?? ""
        var initialKey = UserDefaults.standard.string(forKey: authKey) ?? ""
        var fallbacks: [String] = []

        if let bootUrl = Bundle.main.url(forResource: "LocalBootstrap", withExtension: "json"),
           let data = try? Data(contentsOf: bootUrl),
           let boot = try? JSONDecoder().decode(LocalBootstrapConfig.self, from: data) {
            if let s = boot.serverUrl, !s.isEmpty {
                if initialUrl.isEmpty { initialUrl = s }
                fallbacks.append(Self.normalizeBaseUrl(s))
            }
            if let list = boot.fallbackUrls {
                for item in list {
                    let norm = Self.normalizeBaseUrl(item)
                    if !norm.isEmpty && !fallbacks.contains(norm) {
                        fallbacks.append(norm)
                    }
                }
            }
            if initialKey.isEmpty, let k = boot.pairKey, !k.isEmpty {
                initialKey = k
            }
        }

        if let rawReact = UserDefaults.standard.data(forKey: reactionsKey),
           let dec = try? JSONDecoder().decode([String: [String]].self, from: rawReact) {
            self.reactionsByMsgId = dec
        }

        self.bootstrapFallbackUrls = fallbacks
        self.serverUrl = Self.normalizeBaseUrl(initialUrl)
        self.pairKey = initialKey
    }

    static func normalizeBaseUrl(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "http://" + s
        }
        while s.hasSuffix("/") {
            s.removeLast()
        }
        return s
    }

    var hajimiAvatarFullUrl: String {
        "\(serverUrl)/assets/hajimi-avatar.png?v=\(profile.avatarRev)"
    }

    var ownerAvatarFullUrl: String {
        "\(serverUrl)/assets/owner-avatar.png?v=\(profile.avatarRev)"
    }

    var portraitFullUrl: String {
        "\(serverUrl)/assets/hajimi-full.jpg?v=\(profile.avatarRev)"
    }

    func attachmentUrl(sessionId: String, attachmentId: String) -> String {
        var comps = URLComponents(string: "\(serverUrl)/api/ios/attachment")
        var items = [
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "id", value: attachmentId)
        ]
        if !pairKey.isEmpty {
            items.append(URLQueryItem(name: "k", value: pairKey))
        }
        comps?.queryItems = items
        return comps?.url?.absoluteString ?? ""
    }

    func showToast(_ text: String) {
        toastMessage = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                self.toastMessage = ""
            }
        }
    }

    func saveConnection(url: String, key: String? = nil) {
        let norm = Self.normalizeBaseUrl(url)
        self.serverUrl = norm
        UserDefaults.standard.set(norm, forKey: serverKey)
        if let k = key {
            self.pairKey = k
            UserDefaults.standard.set(k, forKey: authKey)
        }
    }

    func bootstrap() async {
        if serverUrl.isEmpty {
            await autoScanLanServer(silent: true)
        }
        guard !serverUrl.isEmpty, !pairKey.isEmpty else { return }
        await refreshAll()
        if !isConnected {
            await autoScanLanServer(silent: true)
        }
        startSseLoop()
    }

    func pairWithPin(url: String, code: String) async -> Bool {
        let base = Self.normalizeBaseUrl(url)
        guard !base.isEmpty, let endpoint = URL(string: "\(base)/api/ios/pair") else {
            showToast("服务地址格式不正确")
            return false
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 8
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["code": code.trimmingCharacters(in: .whitespacesAndNewlines)])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(PairResponse.self, from: data)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200,
               decoded.ok == true, let k = decoded.pairKey, !k.isEmpty {
                saveConnection(url: base, key: k)
                if let prof = decoded.profile {
                    self.profile = prof
                }
                showToast("已连接电脑端 DSH！")
                await refreshAll()
                startSseLoop()
                return true
            } else {
                showToast(decoded.error ?? "配对码错误")
                return false
            }
        } catch {
            showToast("连接失败：请确认手机与电脑在同一 Wi-Fi")
            return false
        }
    }

    /// Hotspot-First + Wi-Fi Subnet Auto-Discovery (0.2s fast probe for iPhone Personal Hotspot 172.20.10.2..14 & PC Hotspot 192.168.137.1)
    func autoScanLanServer(silent: Bool = false) async {
        guard !isScanningLan else { return }
        isScanningLan = true
        defer { isScanningLan = false }

        var fastCandidates: [String] = []
        for fb in bootstrapFallbackUrls where !fastCandidates.contains(fb) {
            fastCandidates.append(fb)
        }
        for host in 2...14 {
            let hp = "http://172.20.10.\(host):19390"
            if !fastCandidates.contains(hp) { fastCandidates.append(hp) }
        }
        if !fastCandidates.contains("http://192.168.137.1:19390") {
            fastCandidates.append("http://192.168.137.1:19390")
        }

        if let fastHit = await Self.probeCandidateList(fastCandidates, timeout: 0.75) {
            await applyDiscoveredServer(fastHit, silent: silent)
            return
        }

        let prefixes = Self.localIPv4Prefixes()
        for prefix in prefixes {
            let urls = (1...254).map { "http://\(prefix).\($0):19390" }
            if let hit = await Self.probeCandidateList(urls, timeout: 0.85) {
                await applyDiscoveredServer(hit, silent: silent)
                return
            }
        }
        if !silent {
            showToast("未扫到电脑 19390 端口，请确认电脑已连同一热点/Wi-Fi")
        }
    }

    private func applyDiscoveredServer(_ hit: String, silent: Bool) async {
        let changed = (hit != serverUrl)
        saveConnection(url: hit)
        if !silent || changed {
            showToast("📡 已自动连上电脑：\(hit)")
        }
        if !pairKey.isEmpty {
            await refreshAll()
            startSseLoop()
        }
    }

    private static func probeCandidateList(_ urls: [String], timeout: TimeInterval) async -> String? {
        await withTaskGroup(of: String?.self) { group -> String? in
            for candidate in urls {
                group.addTask {
                    guard let u = URL(string: "\(candidate)/api/ios/ping") else { return nil }
                    var req = URLRequest(url: u)
                    req.timeoutInterval = timeout
                    if let (data, resp) = try? await URLSession.shared.data(for: req),
                       let http = resp as? HTTPURLResponse, http.statusCode == 200,
                       let str = String(data: data, encoding: .utf8),
                       str.contains("hajimi-ios-link") {
                        return candidate
                    }
                    return nil
                }
            }
            for await res in group {
                if let hit = res {
                    group.cancelAll()
                    return hit
                }
            }
            return nil
        }
    }

    private static func localIPv4Prefixes() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let first = ifaddr {
            defer { freeifaddrs(ifaddr) }
            var ptr: UnsafeMutablePointer<ifaddrs>? = first
            while let cur = ptr {
                let name = String(cString: cur.pointee.ifa_name)
                if !name.hasPrefix("pdp_ip") && !name.hasPrefix("utun") && !name.hasPrefix("ipsec") {
                    let addr = cur.pointee.ifa_addr.pointee
                    if addr.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(cur.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ip = String(cString: hostname)
                            if !ip.hasPrefix("127.") && !ip.hasPrefix("169.254.") {
                                let parts = ip.split(separator: ".")
                                if parts.count == 4 {
                                    let p = "\(parts[0]).\(parts[1]).\(parts[2])"
                                    if !result.contains(p) {
                                        if name.hasPrefix("bridge") || name.hasPrefix("ap") || name == "en0" {
                                            result.insert(p, at: 0)
                                        } else {
                                            result.append(p)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                ptr = cur.pointee.ifa_next
            }
        }
        if !result.contains("172.20.10") {
            result.insert("172.20.10", at: 0)
        }
        return result
    }

    private func authedRequest(path: String, method: String = "GET", jsonBody: [String: Any]? = nil) throws -> URLRequest {
        guard !serverUrl.isEmpty, let url = URL(string: "\(serverUrl)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !pairKey.isEmpty {
            req.setValue(pairKey, forHTTPHeaderField: "x-hajimi-key")
        }
        if let body = jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadOverview() }
            group.addTask { await self.loadModels() }
            group.addTask { await self.loadMemories() }
            group.addTask { await self.loadEvolution() }
        }
    }

    func loadOverview() async {
        do {
            let req = try authedRequest(path: "/api/ios/overview")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(OverviewResponse.self, from: data)
                self.isConnected = true
                if let prof = decoded.profile { self.profile = prof }
                if let en = decoded.enabledSessions { self.enabledSessions = en }
                if let ot = decoded.otherSessions { self.otherSessions = ot }
            } else if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                self.isConnected = false
            }
        } catch {
            self.isConnected = false
        }
    }

    func loadHistory(sessionId: String) async {
        do {
            let encoded = sessionId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sessionId
            let req = try authedRequest(path: "/api/ios/history?sessionId=\(encoded)")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(HistoryResponse.self, from: data)
                if let prof = decoded.profile { self.profile = prof }
                if let msgs = decoded.messages { self.messagesBySession[sessionId] = msgs }
                if let card = decoded.session,
                   let idx = self.enabledSessions.firstIndex(where: { $0.id == sessionId }) {
                    self.enabledSessions[idx] = card
                }
            }
        } catch {}
    }

    func loadModels() async {
        do {
            let req = try authedRequest(path: "/api/ios/models")
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            if let p = decoded.providers { self.providers = p }
        } catch {}
    }

    func loadMemories() async {
        do {
            let req = try authedRequest(path: "/api/ios/memories")
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(MemoriesResponse.self, from: data)
            if let m = decoded.memories { self.memories = m }
        } catch {}
    }

    func loadEvolution() async {
        do {
            let req = try authedRequest(path: "/api/ios/evolution")
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(EvolutionResponse.self, from: data)
            if let ev = decoded.evolution { self.evolution = ev }
        } catch {}
    }

    func sendMessage(sessionId: String, text: String, jpegImages: [Data]) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && jpegImages.isEmpty { return }

        let localAttachments = jpegImages.map { ChatImageAttachment(localPreviewData: $0) }
        var list = messagesBySession[sessionId] ?? []
        list.append(ChatMessageItem(kind: "user", text: trimmed, images: localAttachments))
        messagesBySession[sessionId] = list
        liveBySession[sessionId] = LiveStreamingStatus(text: "", toolStatus: "对方正在输入...")

        let encodedImages: [[String: String]] = jpegImages.compactMap { raw in
            guard let b64 = ImageCompressionHelper.compressToJpegBase64(raw) else { return nil }
            return ["data": b64, "mediaType": "image/jpeg", "name": "photo.jpg"]
        }

        do {
            let req = try authedRequest(
                path: "/api/ios/send",
                method: "POST",
                jsonBody: [
                    "sessionId": sessionId,
                    "text": trimmed,
                    "images": encodedImages
                ]
            )
            _ = try await URLSession.shared.data(for: req)
        } catch {
            liveBySession.removeValue(forKey: sessionId)
            showToast("发送失败，请检查 Wi-Fi 连接")
        }
    }

    func triggerPoke(session: SessionCard) async {
        HapticsHelper.poke()
        var list = messagesBySession[session.id] ?? []
        list.append(ChatMessageItem(kind: "system", text: "👉 你\(session.pokeAction) ✨"))
        messagesBySession[session.id] = list
        do {
            let req = try authedRequest(path: "/api/ios/poke", method: "POST", jsonBody: ["sessionId": session.id])
            _ = try await URLSession.shared.data(for: req)
        } catch {}
    }

    func switchPersona(sessionId: String, roleId: String) async {
        HapticsHelper.lightTap()
        do {
            let req = try authedRequest(path: "/api/ios/select-persona", method: "POST", jsonBody: [
                "sessionId": sessionId,
                "roleId": roleId
            ])
            let (data, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let notice = obj["systemNotice"] as? String {
                var list = messagesBySession[sessionId] ?? []
                list.append(ChatMessageItem(kind: "system", text: "🎭 \(notice)"))
                messagesBySession[sessionId] = list
            }
            await loadOverview()
        } catch {
            showToast("切换身份失败")
        }
    }

    func switchModel(sessionId: String, provider: String, model: String, effort: String?) async {
        HapticsHelper.lightTap()
        var body: [String: Any] = ["sessionId": sessionId, "provider": provider, "model": model]
        if let ef = effort, !ef.isEmpty {
            body["reasoningEffort"] = ef
        }
        do {
            let req = try authedRequest(path: "/api/ios/select-model", method: "POST", jsonBody: body)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let label = obj["label"] as? String {
                showToast("已秒切模型：\(label)")
            }
            await loadOverview()
        } catch {
            showToast("切换模型失败")
        }
    }

    func cancelTurn(sessionId: String) async {
        do {
            let req = try authedRequest(path: "/api/ios/cancel", method: "POST", jsonBody: ["sessionId": sessionId])
            _ = try await URLSession.shared.data(for: req)
            liveBySession.removeValue(forKey: sessionId)
            showToast("已停止当前任务")
        } catch {}
    }

    func createNewSession(kind: String) async -> String? {
        do {
            let req = try authedRequest(path: "/api/ios/create-session", method: "POST", jsonBody: ["kind": kind])
            let (data, _) = try await URLSession.shared.data(for: req)
            await loadOverview()
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = obj["sessionId"] as? String {
                return sid
            }
        } catch {
            showToast("新建会话失败")
        }
        return nil
    }

    func toggleSessionEnabled(sessionId: String, enabled: Bool) async {
        do {
            let req = try authedRequest(path: "/api/ios/toggle-session", method: "POST", jsonBody: [
                "sessionId": sessionId,
                "enabled": enabled
            ])
            _ = try await URLSession.shared.data(for: req)
            await loadOverview()
        } catch {}
    }

    // MARK: - Shared Memory CRUD
    func saveMemory(id: String? = nil, content: String, category: String, pinned: Bool) async {
        var body: [String: Any] = ["content": content, "category": category, "pinned": pinned]
        if let id = id { body["id"] = id }
        do {
            let req = try authedRequest(path: "/api/ios/memories/save", method: "POST", jsonBody: body)
            _ = try await URLSession.shared.data(for: req)
            await loadMemories()
            showToast("共享记忆已保存")
        } catch {
            showToast("保存记忆失败")
        }
    }

    func deleteMemory(id: String) async {
        do {
            let req = try authedRequest(path: "/api/ios/memories/delete", method: "POST", jsonBody: ["id": id])
            _ = try await URLSession.shared.data(for: req)
            await loadMemories()
        } catch {}
    }

    // MARK: - Persona Evolution
    func updateEvolutionConfig(enabled: Bool, cycleEveryTurns: Int, cycleEveryHours: Int) async {
        do {
            let req = try authedRequest(path: "/api/ios/evolution/config", method: "POST", jsonBody: [
                "enabled": enabled,
                "cycleEveryTurns": cycleEveryTurns,
                "cycleEveryHours": cycleEveryHours
            ])
            let (data, _) = try await URLSession.shared.data(for: req)
            if let dec = try? JSONDecoder().decode(EvolutionResponse.self, from: data), let ev = dec.evolution {
                self.evolution = ev
            }
            showToast("演化周期已更新")
        } catch {}
    }

    func triggerEvolveNow() async {
        showToast("正在复盘近期记忆并轻微调整设定...")
        do {
            var req = try authedRequest(path: "/api/ios/evolution/evolve-now", method: "POST", jsonBody: [:])
            req.timeoutInterval = 90
            let (data, _) = try await URLSession.shared.data(for: req)
            if let dec = try? JSONDecoder().decode(EvolutionResponse.self, from: data), let ev = dec.evolution {
                self.evolution = ev
                await loadMemories()
                showToast("✨ 人设已完成一次轻微演化！")
            }
        } catch {
            showToast("人设微调失败")
        }
    }

    func updateLivingTraits(currentVibe: String, traits: [String]) async {
        do {
            let req = try authedRequest(path: "/api/ios/evolution/update-traits", method: "POST", jsonBody: [
                "currentVibe": currentVibe,
                "livingTraits": traits
            ])
            let (data, _) = try await URLSession.shared.data(for: req)
            if let dec = try? JSONDecoder().decode(EvolutionResponse.self, from: data), let ev = dec.evolution {
                self.evolution = ev
                showToast("已更新设定细节")
            }
        } catch {}
    }

    func revertEvolution(historyId: String) async {
        do {
            let req = try authedRequest(path: "/api/ios/evolution/revert", method: "POST", jsonBody: ["historyId": historyId])
            let (data, _) = try await URLSession.shared.data(for: req)
            if let dec = try? JSONDecoder().decode(EvolutionResponse.self, from: data), let ev = dec.evolution {
                self.evolution = ev
                showToast("已回滚到历史人设版本")
            }
        } catch {}
    }

    // MARK: - Profile Customization (Names & Avatars)
    func updateProfile(_ payload: [String: Any]) async {
        do {
            let req = try authedRequest(path: "/api/ios/profile", method: "POST", jsonBody: payload)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let dec = try? JSONDecoder().decode(OverviewResponse.self, from: data), let prof = dec.profile {
                RemoteImageMemoryCache.shared.clear()
                self.profile = prof
            }
            await loadOverview()
            showToast("头像/昵称已同步更新！")
        } catch {
            showToast("保存装扮失败")
        }
    }

    func toggleReaction(msgId: String, emoji: String) {
        HapticsHelper.lightTap()
        var arr = reactionsByMsgId[msgId] ?? []
        if let idx = arr.firstIndex(of: emoji) {
            arr.remove(at: idx)
        } else {
            arr.append(emoji)
        }
        reactionsByMsgId[msgId] = arr
        if let encoded = try? JSONEncoder().encode(reactionsByMsgId) {
            UserDefaults.standard.set(encoded, forKey: reactionsKey)
        }
    }

    func fetchContextPreview(sessionId: String? = nil) async -> ContextPreviewResponse? {
        let q = sessionId != nil ? "?sessionId=\(sessionId!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" : ""
        do {
            let req = try authedRequest(path: "/api/ios/context-preview\(q)")
            let (data, _) = try await URLSession.shared.data(for: req)
            return try JSONDecoder().decode(ContextPreviewResponse.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Real-Time SSE Loop
    func startSseLoop() {
        sseTask?.cancel()
        guard !serverUrl.isEmpty, !pairKey.isEmpty else { return }
        let base = serverUrl
        let key = pairKey

        sseTask = Task { [weak self] in
            var consecutiveFailures = 0
            while !Task.isCancelled {
                guard let self = self else { return }
                let encodedK = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                guard let url = URL(string: "\(base)/api/ios/stream?k=\(encodedK)") else { break }
                var req = URLRequest(url: url)
                req.timeoutInterval = 300
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        consecutiveFailures = 0
                        await MainActor.run { self.isConnected = true }
                        var currentEvent = "message"
                        for try await line in bytes.lines {
                            if Task.isCancelled { break }
                            if line.hasPrefix("event:") {
                                currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            } else if line.hasPrefix("data:") {
                                let jsonStr = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                await self.handleSseFrame(event: currentEvent, jsonString: jsonStr)
                            }
                        }
                    }
                } catch {
                    consecutiveFailures += 1
                    await MainActor.run { self.isConnected = false }
                    if consecutiveFailures >= 2 {
                        consecutiveFailures = 0
                        await self.autoScanLanServer(silent: true)
                        if self.serverUrl != base { break }
                    }
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    private func handleSseFrame(event: String, jsonString: String) async {
        guard let data = jsonString.data(using: .utf8) else { return }
        if event == "live" {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = obj["sessionId"] as? String {
                let done = (obj["done"] as? Bool) ?? false
                if done {
                    liveBySession.removeValue(forKey: sid)
                } else {
                    let txt = (obj["text"] as? String) ?? ""
                    let tool = (obj["toolStatus"] as? String) ?? ""
                    liveBySession[sid] = LiveStreamingStatus(text: txt, toolStatus: tool)
                }
            }
        } else if event == "sync" {
            if let ov = try? JSONDecoder().decode(OverviewResponse.self, from: data) {
                if let prof = ov.profile { self.profile = prof }
                if let en = ov.enabledSessions { self.enabledSessions = en }
                if let ot = ov.otherSessions { self.otherSessions = ot }
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = obj["sessionId"] as? String,
               let msgsArr = obj["messages"],
               let msgsData = try? JSONSerialization.data(withJSONObject: msgsArr),
               let decodedMsgs = try? JSONDecoder().decode([ChatMessageItem].self, from: msgsData) {
                messagesBySession[sid] = decodedMsgs
                liveBySession.removeValue(forKey: sid)
                if activeViewingSessionId != sid, (obj["newAssistantReply"] as? Bool) == true {
                    unreadBySession[sid, default: 0] += 1
                }
            }
        } else if event == "soul" {
            await loadMemories()
            await loadEvolution()
            await loadOverview()
        }
    }
}
