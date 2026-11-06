import Foundation
import SwiftUI
import UIKit
import Network
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
    @Published var telemetry: SoulTelemetry = SoulTelemetry()
    @Published var diaryEntries: [CatgirlDiaryEntry] = []
    @Published var reactionsByMsgId: [String: [String]] = [:]
    @Published var toastMessage: String = ""
    @Published var pendingOpenSessionId: String? = nil
    @Published var isForkingSession: Bool = false
    @Published var backgroundKeepAliveEnabled: Bool = true
    @Published var backgroundNotifyEnabled: Bool = true

    var activeViewingSessionId: String? = nil
    var bootstrapFallbackUrls: [String] = []
    private var didFinishBootstrap: Bool = false
    private var sseTask: Task<Void, Never>? = nil
    private var watchdogTask: Task<Void, Never>? = nil
    private var toastTask: Task<Void, Never>? = nil
    private var liveClearTasks: [String: Task<Void, Never>] = [:]
    private var sseGeneration: UInt64 = 0
    private var isSseStreamingActive: Bool = false
    private var lastSseFrameAt: Date = .distantPast
    private var isAppInForeground: Bool = true
    private var isPausedForBackground: Bool = false
    private var lastForegroundWakeAt: Date = .distantPast
    private var pathMonitor: NWPathMonitor? = nil
    private var lastPathSignature: String = ""

    private lazy var sseUrlSession: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 38
        cfg.timeoutIntervalForResource = 86400 * 30
        cfg.waitsForConnectivity = false
        cfg.allowsCellularAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    private lazy var apiUrlSession: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 120
        cfg.waitsForConnectivity = false
        cfg.allowsCellularAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    private let serverKey = "hjm_server_url_v2"
    private let authKey = "hjm_pair_key_v2"
    private let reactionsKey = "hjm_msg_reactions_v1"
    private let bgKeepAliveKey = "hjm_bg_keepalive_v1"
    private let bgNotifyKey = "hjm_bg_notify_v1"

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

        if UserDefaults.standard.object(forKey: bgKeepAliveKey) != nil {
            self.backgroundKeepAliveEnabled = UserDefaults.standard.bool(forKey: bgKeepAliveKey)
        } else {
            self.backgroundKeepAliveEnabled = true
        }
        if UserDefaults.standard.object(forKey: bgNotifyKey) != nil {
            self.backgroundNotifyEnabled = UserDefaults.standard.bool(forKey: bgNotifyKey)
        } else {
            self.backgroundNotifyEnabled = true
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
        serverUrl.isEmpty ? "" : "\(serverUrl)/assets/hajimi-avatar.png?v=\(profile.avatarRev)"
    }

    var ownerAvatarFullUrl: String {
        serverUrl.isEmpty ? "" : "\(serverUrl)/assets/owner-avatar.png?v=\(profile.avatarRev)"
    }

    var portraitFullUrl: String {
        serverUrl.isEmpty ? "" : "\(serverUrl)/assets/hajimi-full.jpg?v=\(profile.avatarRev)"
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
        defer { didFinishBootstrap = true }
        startNetworkMonitorIfNeeded()
        startConnectionWatchdogIfNeeded()
        if backgroundNotifyEnabled {
            BackgroundKeepAliveManager.shared.requestNotificationPermissionIfNeeded()
        }
        if serverUrl.isEmpty {
            await autoScanLanServer(silent: true)
        }
        guard !serverUrl.isEmpty, !pairKey.isEmpty else { return }
        await refreshAll()
        if !isConnected {
            await autoScanLanServer(silent: true)
        }
        startSseLoop(force: true)
    }

    func setBackgroundKeepAlive(_ enabled: Bool) {
        backgroundKeepAliveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: bgKeepAliveKey)
        BackgroundKeepAliveManager.shared.updateKeepAlivePreference(enabled)
        showToast(enabled ? "🌙 已开启后台静音保活（锁屏/切后台不断连）" : "已切换为仅前台连接（切后台约 30 秒休眠）")
    }

    func setBackgroundNotify(_ enabled: Bool) {
        backgroundNotifyEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: bgNotifyKey)
        if enabled {
            BackgroundKeepAliveManager.shared.requestNotificationPermissionIfNeeded()
        }
        showToast(enabled ? "🔔 已开启后台回复横幅通知" : "已关闭后台回复通知")
    }

    func handleAppDidEnterBackground() {
        isAppInForeground = false
        guard !pairKey.isEmpty else { return }
        BackgroundKeepAliveManager.shared.enterBackground(keepAlive: backgroundKeepAliveEnabled) { [weak self] in
            guard let self = self else { return }
            self.isPausedForBackground = true
            self.sseGeneration &+= 1
            self.isSseStreamingActive = false
            self.sseTask?.cancel()
            self.sseTask = nil
        }
    }

    func handleAppWillEnterForeground() async {
        isAppInForeground = true
        let wasPaused = isPausedForBackground
        isPausedForBackground = false
        BackgroundKeepAliveManager.shared.enterForeground()
        guard didFinishBootstrap, !serverUrl.isEmpty, !pairKey.isEmpty else { return }
        let now = Date()
        if !wasPaused && now.timeIntervalSince(lastForegroundWakeAt) < 1.2 {
            return
        }
        lastForegroundWakeAt = now
        startSseLoop(force: wasPaused)
        await refreshAll()
        if !isConnected {
            await autoScanLanServer(silent: true)
        }
        if let activeSid = activeViewingSessionId {
            await loadHistory(sessionId: activeSid)
        }
    }

    func handleAppDidBecomeActive() async {
        await handleAppWillEnterForeground()
    }

    private func startNetworkMonitorIfNeeded() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let sig = "\(path.status)-\(path.availableInterfaces.map(\.name).joined(separator: ","))"
            let satisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self, self.didFinishBootstrap, !self.pairKey.isEmpty else { return }
                let changed = (sig != self.lastPathSignature)
                self.lastPathSignature = sig
                if satisfied && changed && !self.isPausedForBackground {
                    self.startSseLoop(force: true)
                    await self.loadOverview()
                    if !self.isConnected {
                        await self.autoScanLanServer(silent: true)
                    }
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.zizhe.hajimiqq.netmonitor"))
    }

    private func startConnectionWatchdogIfNeeded() {
        guard watchdogTask == nil else { return }
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000_000)
                guard let self = self else { return }
                guard self.didFinishBootstrap, !self.pairKey.isEmpty, !self.serverUrl.isEmpty else { continue }
                if self.isPausedForBackground { continue }
                if !self.isAppInForeground && !self.backgroundKeepAliveEnabled { continue }
                let stale = Date().timeIntervalSince(self.lastSseFrameAt) > 30
                if !self.isConnected || !self.isSseStreamingActive || stale {
                    self.startSseLoop(force: true)
                    await self.loadOverview()
                }
            }
        }
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
                startSseLoop(force: true)
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
        if !serverUrl.isEmpty {
            fastCandidates.append(serverUrl)
        }
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
            startSseLoop(force: changed)
        }
    }

    private static func probeCandidateList(_ urls: [String], timeout: TimeInterval) async -> String? {
        let batchSize = 48
        var idx = 0
        while idx < urls.count {
            let end = min(idx + batchSize, urls.count)
            let chunk = Array(urls[idx..<end])
            let hit = await withTaskGroup(of: String?.self) { group -> String? in
                for candidate in chunk {
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
                    if let found = res {
                        group.cancelAll()
                        return found
                    }
                }
                return nil
            }
            if let hit = hit {
                return hit
            }
            idx = end
        }
        return nil
    }

    private static func localIPv4Prefixes() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let first = ifaddr {
            defer { freeifaddrs(ifaddr) }
            var ptr: UnsafeMutablePointer<ifaddrs>? = first
            while let cur = ptr {
                defer { ptr = cur.pointee.ifa_next }
                guard let namePtr = cur.pointee.ifa_name,
                      let addrPtr = cur.pointee.ifa_addr else {
                    continue
                }
                let name = String(cString: namePtr)
                if !name.hasPrefix("pdp_ip") && !name.hasPrefix("utun") && !name.hasPrefix("ipsec") {
                    let addr = addrPtr.pointee
                    if addr.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(addrPtr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
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
            }
        }
        if !result.contains("172.20.10") {
            result.insert("172.20.10", at: 0)
        }
        return result
    }

    private func authedRequest(path: String, method: String = "GET", jsonBody: [String: Any]? = nil, timeout: TimeInterval = 20) throws -> URLRequest {
        guard !serverUrl.isEmpty, let url = URL(string: "\(serverUrl)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout
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

    private func authedData(path: String, method: String = "GET", jsonBody: [String: Any]? = nil, timeout: TimeInterval = 20) async throws -> Data {
        let req = try authedRequest(path: path, method: method, jsonBody: jsonBody, timeout: timeout)
        let (data, resp) = try await apiUrlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 401 {
            self.isConnected = false
            throw URLError(.userAuthenticationRequired)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        if !self.isConnected {
            self.isConnected = true
        }
        return data
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadOverview() }
            group.addTask { await self.loadModels() }
            group.addTask { await self.loadMemories() }
            group.addTask { await self.loadEvolution() }
            group.addTask { await self.loadSoulState() }
        }
    }

    func loadOverview() async {
        do {
            let req = try authedRequest(path: "/api/ios/overview", timeout: 10)
            let (data, resp) = try await apiUrlSession.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(OverviewResponse.self, from: data)
                self.isConnected = true
                if let prof = decoded.profile { self.profile = prof }
                if let tel = decoded.telemetry { self.telemetry = tel }
                if let en = decoded.enabledSessions { self.enabledSessions = en }
                if let ot = decoded.otherSessions { self.otherSessions = ot }
            } else if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                self.isConnected = false
            }
        } catch {
            if !self.isSseStreamingActive {
                self.isConnected = false
            }
        }
    }

    func loadSoulState() async {
        do {
            let req = try authedRequest(path: "/api/ios/soul/state")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(SoulStateResponse.self, from: data)
                if let tel = decoded.telemetry { self.telemetry = tel }
                if let entries = decoded.diaryEntries { self.diaryEntries = entries }
                if let ev = decoded.evolution { self.evolution = ev }
            }
        } catch {}
    }

    func loadHistory(sessionId: String) async {
        do {
            let encoded = sessionId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sessionId
            let req = try authedRequest(path: "/api/ios/history?sessionId=\(encoded)")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(HistoryResponse.self, from: data)
                if let prof = decoded.profile { self.profile = prof }
                if let msgs = decoded.messages { self.messagesBySession[sessionId] = Self.sanitizeChatMessages(msgs) }
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
            _ = try await authedData(
                path: "/api/ios/send",
                method: "POST",
                jsonBody: [
                    "sessionId": sessionId,
                    "text": trimmed,
                    "images": encodedImages
                ]
            )
        } catch {
            liveBySession.removeValue(forKey: sessionId)
            showToast("发送失败，请检查热点 / Wi-Fi 连接")
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
            let (data, _) = try await apiUrlSession.data(for: req)
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

    static func extractEventSeq(from msgId: String) -> Int? {
        guard msgId.hasPrefix("ev-") else { return nil }
        return Int(msgId.dropFirst(3))
    }

    @discardableResult
    func forkSession(sessionId: String, atSeq: Int? = nil, navigate: Bool = true) async -> String? {
        guard !isForkingSession else { return nil }
        isForkingSession = true
        defer { isForkingSession = false }
        HapticsHelper.lightTap()

        var body: [String: Any] = ["sessionId": sessionId]
        if let seq = atSeq, seq >= 0 {
            body["atSeq"] = seq
        }

        do {
            let data = try await authedData(path: "/api/ios/fork-session", method: "POST", jsonBody: body, timeout: 25)
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newSid = obj["sessionId"] as? String, !newSid.isEmpty else {
                showToast("新开分支失败")
                return nil
            }
            let title = (obj["title"] as? String) ?? "新分支"
            if let cardObj = obj["session"],
               let cardData = try? JSONSerialization.data(withJSONObject: cardObj),
               let card = try? JSONDecoder().decode(SessionCard.self, from: cardData) {
                var list = self.enabledSessions.filter { $0.id != newSid }
                list.insert(card, at: 0)
                self.enabledSessions = list
            } else {
                await loadOverview()
            }
            await loadHistory(sessionId: newSid)
            if navigate {
                self.pendingOpenSessionId = newSid
            }
            showToast(atSeq != nil ? "🔀 已从该消息处新开分支：\(title)" : "🔀 已新开分支：\(title)")
            return newSid
        } catch {
            showToast("新开分支失败，请确认电脑端 DSH 已连接")
            return nil
        }
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

    func reinforceMemory(id: String) async {
        HapticsHelper.lightTap()
        do {
            let data = try await authedData(path: "/api/ios/memories/reinforce", method: "POST", jsonBody: ["id": id])
            if let dec = try? JSONDecoder().decode(MemoriesResponse.self, from: data), let m = dec.memories {
                self.memories = m
            } else {
                await loadMemories()
            }
            showToast("⚡ 已强化唤醒这颗记忆星辰！")
        } catch {
            showToast("强化记忆未生效（请确认电脑端已升级至 v3.0）")
        }
    }

    func togglePinMemory(id: String) async {
        HapticsHelper.lightTap()
        do {
            let data = try await authedData(path: "/api/ios/memories/toggle-pin", method: "POST", jsonBody: ["id": id])
            if let dec = try? JSONDecoder().decode(MemoriesResponse.self, from: data), let m = dec.memories {
                self.memories = m
            } else {
                await loadMemories()
            }
            showToast("📌 已切换记忆星辰置顶状态")
        } catch {
            showToast("置顶切换未生效（请确认电脑端已升级至 v3.0）")
        }
    }

    // MARK: - SoulOS v3.0 Catgirl Care & Autonomous Heartbeat
    func interactWithCatgirl(action: String) async {
        HapticsHelper.care(action: action)
        do {
            let data = try await authedData(path: "/api/ios/soul/interact", method: "POST", jsonBody: ["action": action])
            if let dec = try? JSONDecoder().decode(SoulInteractResponse.self, from: data), dec.ok == true {
                if let tel = dec.telemetry { self.telemetry = tel }
                if let ev = dec.evolution { self.evolution = ev }
                if let toast = dec.reactionToast, !toast.isEmpty {
                    showToast(toast)
                }
            } else {
                await loadSoulState()
            }
        } catch {
            showToast("互动未送达，请确认电脑端已连接并升级至 v3.0")
        }
    }

    func updateHeartbeatConfig(proactiveEnabled: Bool? = nil, minIdleMinutes: Int? = nil, autoExpandThoughts: Bool? = nil) async {
        // Optimistic update to prevent iOS 17 Toggle/Picker bounce
        var body: [String: Any] = [:]
        if let p = proactiveEnabled {
            self.telemetry.heartbeat.proactiveEnabled = p
            body["proactiveEnabled"] = p
        }
        if let m = minIdleMinutes {
            self.telemetry.heartbeat.minIdleMinutes = m
            body["minIdleMinutes"] = m
        }
        if let a = autoExpandThoughts {
            self.telemetry.heartbeat.autoExpandThoughts = a
            body["autoExpandThoughts"] = a
        }
        do {
            let data = try await authedData(path: "/api/ios/soul/heartbeat-config", method: "POST", jsonBody: body)
            if let dec = try? JSONDecoder().decode(SoulInteractResponse.self, from: data), let tel = dec.telemetry {
                self.telemetry = tel
            } else {
                await loadSoulState()
            }
        } catch {}
    }

    func triggerProactiveGreetingNow(sessionId: String? = nil) async {
        HapticsHelper.lightTap()
        var body: [String: Any] = [:]
        if let sid = sessionId, !sid.isEmpty { body["sessionId"] = sid }
        do {
            _ = try await authedData(path: "/api/ios/soul/proactive-now", method: "POST", jsonBody: body)
            showToast("💌 \(profile.hajimiName)正在组织语言准备主动找你...")
        } catch {
            showToast("触发主动私聊失败，请确认电脑端已升级至 v3.0")
        }
    }

    // MARK: - Persona Evolution
    func updateEvolutionConfig(enabled: Bool, cycleEveryTurns: Int, cycleEveryHours: Int) async {
        self.evolution.enabled = enabled
        self.evolution.cycleEveryTurns = cycleEveryTurns
        self.evolution.cycleEveryHours = cycleEveryHours
        do {
            let data = try await authedData(path: "/api/ios/evolution/config", method: "POST", jsonBody: [
                "enabled": enabled,
                "cycleEveryTurns": cycleEveryTurns,
                "cycleEveryHours": cycleEveryHours
            ])
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
                await loadSoulState()
                showToast("✨ 人设已完成一次演化并写入秘密日记！")
            }
        } catch {
            showToast("人设微调失败")
        }
    }

    func updateLivingTraits(currentVibe: String, traits: [String], selfOptimizeRules: [String]? = nil) async {
        var body: [String: Any] = [
            "currentVibe": currentVibe,
            "livingTraits": traits
        ]
        if let rules = selfOptimizeRules {
            body["selfOptimizeRules"] = rules
        }
        do {
            let req = try authedRequest(path: "/api/ios/evolution/update-traits", method: "POST", jsonBody: body)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let dec = try? JSONDecoder().decode(EvolutionResponse.self, from: data), let ev = dec.evolution {
                self.evolution = ev
                showToast("已更新设定与自我进化准则")
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

    // MARK: - Real-Time SSE Loop (Generation-Guarded + Anti-Jitter + Background Keep-Alive)
    func startSseLoop(force: Bool = false) {
        guard !serverUrl.isEmpty, !pairKey.isEmpty, !isPausedForBackground else { return }
        if !force,
           isSseStreamingActive,
           sseTask != nil,
           Date().timeIntervalSince(lastSseFrameAt) < 26 {
            return
        }

        sseGeneration &+= 1
        let myGen = sseGeneration
        isSseStreamingActive = false
        sseTask?.cancel()

        let base = serverUrl
        let key = pairKey
        let session = sseUrlSession

        sseTask = Task { [weak self] in
            var consecutiveFailures = 0
            while !Task.isCancelled {
                guard let self = self else { return }
                if self.sseGeneration != myGen || self.isPausedForBackground { break }

                let encodedK = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                guard let url = URL(string: "\(base)/api/ios/stream?k=\(encodedK)") else { break }
                var req = URLRequest(url: url)
                req.timeoutInterval = 38
                req.cachePolicy = .reloadIgnoringLocalCacheData
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                do {
                    let (bytes, resp) = try await session.bytes(for: req)
                    if Task.isCancelled || self.sseGeneration != myGen { break }
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        let recoveredFromFailure = (consecutiveFailures > 0 || !self.isConnected)
                        consecutiveFailures = 0
                        self.isSseStreamingActive = true
                        self.lastSseFrameAt = Date()
                        self.isConnected = true
                        if recoveredFromFailure {
                            Task { [weak self] in
                                await self?.loadOverview()
                                if let sid = self?.activeViewingSessionId {
                                    await self?.loadHistory(sessionId: sid)
                                }
                            }
                        }
                        var currentEvent = "message"
                        for try await line in bytes.lines {
                            if Task.isCancelled || self.sseGeneration != myGen || self.isPausedForBackground { break }
                            self.lastSseFrameAt = Date()
                            if !self.isConnected { self.isConnected = true }
                            if line.hasPrefix("event:") {
                                currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            } else if line.hasPrefix("data:") {
                                if currentEvent != "heartbeat" {
                                    let jsonStr = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                    await self.handleSseFrame(event: currentEvent, jsonString: jsonStr)
                                }
                                currentEvent = "message"
                            }
                        }
                        self.isSseStreamingActive = false
                    } else if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                        self.isSseStreamingActive = false
                        self.isConnected = false
                        break
                    } else {
                        self.isSseStreamingActive = false
                        consecutiveFailures += 1
                    }
                } catch {
                    if Task.isCancelled || self.sseGeneration != myGen || self.isPausedForBackground {
                        break
                    }
                    self.isSseStreamingActive = false
                    consecutiveFailures += 1
                    // First transient reset: retry in 350ms WITHOUT flashing disconnected banner
                    if consecutiveFailures == 1 {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        continue
                    }
                    // Confirm reachability before flipping disconnected & scanning LAN
                    let stillAlive = await Self.probeCandidateList([base], timeout: 0.9) != nil
                    if stillAlive {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        continue
                    }
                    self.isConnected = false
                    if consecutiveFailures >= 2 {
                        consecutiveFailures = 0
                        await self.autoScanLanServer(silent: true)
                        if self.serverUrl != base { break }
                    }
                }
                if Task.isCancelled || self.sseGeneration != myGen || self.isPausedForBackground { break }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private static func sanitizeAssistantText(_ raw: String, isStreaming: Bool) -> String {
        var s = raw
        if s.isEmpty { return "" }

        // 1. Strip raw Gemini 4 `<|thought|>...<|thought|>` or unflagged `thought\n...` leaked blocks
        s = s.replacingOccurrences(of: #"<\|thought\|>[\s\S]*?<\|thought\|>"#, with: "", options: [.regularExpression])
        if s.range(of: #"^\s*(?:<\|thought\|>\s*)?thought\r?\n"#, options: [.regularExpression]) != nil {
            if let r = s.range(of: "<|thought|>") {
                s = String(s[r.upperBound...])
            } else {
                return ""
            }
        }

        // 2. Strip upstream redaction/empty markers & <think>/<thought> blocks
        s = s.replacingOccurrences(of: #"^\s*\[-REDACTED-\]\s*"#, with: "", options: [.regularExpression])
        s = s.replacingOccurrences(of: #"\[\[empty upstream[^\]]*\]\]"#, with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"<think\b[^>]*>[\s\S]*?<\/think>"#, with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"<thought\b[^>]*>[\s\S]*?<\/thought>"#, with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"<think\b[^>]*>[\s\S]*$"#, with: "", options: [.regularExpression, .caseInsensitive])

        // 3. Strip closed & unclosed SoulOS tags
        s = s.replacingOccurrences(of: #"<hajimi_thought[^>]*>[\s\S]*?<\/hajimi_thought>"#, with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"<hajimi_memory[^>]*>[\s\S]*?<\/hajimi_memory>"#, with: "", options: [.regularExpression, .caseInsensitive])
        if isStreaming {
            s = s.replacingOccurrences(of: #"<\/?(?:hajimi_[a-zA-Z0-9_]*|think\b|thought\b)[\s\S]*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            s = s.replacingOccurrences(of: #"<\|thought\|>[\s\S]*$"#, with: "", options: [.regularExpression])
            s = s.replacingOccurrences(of: #"<\/?(?:h(?:a(?:j(?:i(?:m(?:i)?)?)?)?)?|t(?:h(?:i(?:n(?:k)?)?)?)?)?$"#, with: "", options: [.regularExpression, .caseInsensitive])
        } else {
            s = s.replacingOccurrences(of: #"<hajimi_(?:thought|memory)\b[\s\S]*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            s = s.replacingOccurrences(of: #"<\/?hajimi_(?:thought|memory)[^>]*>"#, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizeLiveStreamingText(_ raw: String) -> String {
        sanitizeAssistantText(raw, isStreaming: true)
    }

    private static func sanitizeChatMessages(_ items: [ChatMessageItem]) -> [ChatMessageItem] {
        var out: [ChatMessageItem] = []
        out.reserveCapacity(items.count)
        for var item in items {
            if item.kind == "user" {
                let t = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.hasPrefix("Time sampled while preparing turn ") ||
                   t.hasPrefix("Current runtime context. This snapshot supersedes") ||
                   (t.hasPrefix("Background subagent ") && t.contains(" finished and will do no further work")) {
                    continue
                }
                out.append(item)
            } else if item.kind == "assistant" {
                let cleaned = sanitizeAssistantText(item.text, isStreaming: false)
                if !cleaned.isEmpty || !item.images.isEmpty {
                    item.text = cleaned
                    out.append(item)
                }
            } else {
                out.append(item)
            }
        }
        return out
    }

    private func handleSseFrame(event: String, jsonString: String) async {
        guard let data = jsonString.data(using: .utf8) else { return }
        if event == "live" {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = obj["sessionId"] as? String {
                let done = (obj["done"] as? Bool) ?? false
                if done {
                    if let cur = liveBySession[sid], !cur.text.isEmpty {
                        // Zero-flicker handoff: hold text briefly until `sync` atomically swaps in final message
                        liveBySession[sid] = LiveStreamingStatus(text: cur.text, toolStatus: "")
                        liveClearTasks[sid]?.cancel()
                        liveClearTasks[sid] = Task { [weak self] in
                            try? await Task.sleep(nanoseconds: 550_000_000)
                            guard !Task.isCancelled else { return }
                            self?.liveBySession.removeValue(forKey: sid)
                            self?.liveClearTasks.removeValue(forKey: sid)
                        }
                    } else {
                        liveClearTasks[sid]?.cancel()
                        liveClearTasks.removeValue(forKey: sid)
                        liveBySession.removeValue(forKey: sid)
                    }
                } else {
                    liveClearTasks[sid]?.cancel()
                    liveClearTasks.removeValue(forKey: sid)
                    let rawTxt = (obj["text"] as? String) ?? ""
                    let txt = Self.sanitizeLiveStreamingText(rawTxt)
                    let tool = (obj["toolStatus"] as? String) ?? ""
                    liveBySession[sid] = LiveStreamingStatus(text: txt, toolStatus: tool)
                }
            }
        } else if event == "sync" {
            if let ov = try? JSONDecoder().decode(OverviewResponse.self, from: data) {
                if let prof = ov.profile { self.profile = prof }
                if let tel = ov.telemetry { self.telemetry = tel }
                if let en = ov.enabledSessions { self.enabledSessions = en }
                if let ot = ov.otherSessions { self.otherSessions = ot }
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = obj["sessionId"] as? String,
               let msgsArr = obj["messages"],
               let msgsData = try? JSONSerialization.data(withJSONObject: msgsArr),
               let decodedMsgs = try? JSONDecoder().decode([ChatMessageItem].self, from: msgsData) {
                let cleanedMsgs = Self.sanitizeChatMessages(decodedMsgs)
                liveClearTasks[sid]?.cancel()
                liveClearTasks.removeValue(forKey: sid)
                messagesBySession[sid] = cleanedMsgs
                liveBySession.removeValue(forKey: sid)
                let isNewReply = (obj["newAssistantReply"] as? Bool) == true
                if activeViewingSessionId != sid, isNewReply {
                    unreadBySession[sid, default: 0] += 1
                }
                if !isAppInForeground, backgroundNotifyEnabled, isNewReply,
                   let lastAssistant = cleanedMsgs.last(where: { $0.kind == "assistant" && !$0.text.isEmpty }) {
                    let cardTitle = enabledSessions.first(where: { $0.id == sid })?.chatTitle ?? profile.hajimiName
                    BackgroundKeepAliveManager.shared.postBackgroundReplyNotification(
                        title: cardTitle,
                        body: lastAssistant.text,
                        sessionId: sid
                    )
                }
            }
        } else if event == "soul" {
            await loadMemories()
            await loadEvolution()
            await loadSoulState()
            await loadOverview()
        }
    }
}
