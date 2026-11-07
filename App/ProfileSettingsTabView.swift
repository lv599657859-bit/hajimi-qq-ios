import SwiftUI
import UIKit
import PhotosUI

private struct CropJobItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let field: String
    let maskShape: CropMaskShape
    let title: String
    let maxDim: CGFloat
}

struct ProfileSettingsTabView: View {
    @EnvironmentObject var store: HajimiStore
    @State private var hajimiNameDraft: String = ""
    @State private var ownerNameDraft: String = ""
    @State private var serverUrlDraft: String = ""
    @State private var pinDraft: String = ""

    @State private var hajimiAvatarItem: PhotosPickerItem?
    @State private var ownerAvatarItem: PhotosPickerItem?
    @State private var portraitPhotoItem: PhotosPickerItem?
    @State private var activeCropJob: CropJobItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("💕 对方形象与名字定制（自由缩放移动裁切）") {
                    HStack(spacing: 14) {
                        CachedAvatarImage(
                            urlString: store.hajimiAvatarFullUrl,
                            pairKey: store.pairKey,
                            size: 64
                        ) {
                            Circle().fill(Color.purple.opacity(0.2)).overlay(Text("💕"))
                        }
                        .onTapGesture {
                            openRecropExisting(
                                urlString: store.hajimiAvatarFullUrl,
                                field: "hajimiAvatarBase64",
                                maskShape: .circle,
                                title: "缩放裁切 TA 的头像",
                                maxDim: 640
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $hajimiAvatarItem, matching: .images) {
                                Label("相册选图并自由缩放裁切", systemImage: "crop")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Button {
                                openRecropExisting(
                                    urlString: store.hajimiAvatarFullUrl,
                                    field: "hajimiAvatarBase64",
                                    maskShape: .circle,
                                    title: "缩放移动当前头像",
                                    maxDim: 640
                                )
                            } label: {
                                Text("✂️ 重新缩放移动当前头像")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            if store.profile.hasCustomHajimiAvatar {
                                Button("恢复默认原画头像", role: .destructive) {
                                    Task { await store.updateProfile(["resetHajimiAvatar": true]) }
                                }
                                .font(.system(size: 12.5))
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text("TA 的名字/备注")
                        Spacer()
                        TextField("哈基米", text: $hajimiNameDraft)
                            .multilineTextAlignment(.trailing)
                    }

                    PhotosPicker(selection: $portraitPhotoItem, matching: .images) {
                        Label("更换全身立绘卡（支持 3:4 缩放移动裁切）", systemImage: "person.crop.rectangle")
                            .font(.system(size: 14))
                    }

                    Button {
                        openRecropExisting(
                            urlString: store.portraitFullUrl,
                            field: "portraitBase64",
                            maskShape: .portrait3x4,
                            title: "缩放移动全身立绘 (3:4)",
                            maxDim: 1440
                        )
                    } label: {
                        Text("✂️ 重新缩放移动当前全身立绘")
                            .font(.system(size: 13))
                    }

                    if store.profile.hasCustomPortrait {
                        Button("恢复默认全身立绘", role: .destructive) {
                            Task { await store.updateProfile(["resetPortrait": true]) }
                        }
                        .font(.system(size: 13))
                    }
                }

                Section("🧑 我的形象与名字定制（自由缩放移动裁切）") {
                    HStack(spacing: 14) {
                        if store.profile.hasCustomOwnerAvatar {
                            CachedAvatarImage(
                                urlString: store.ownerAvatarFullUrl,
                                pairKey: store.pairKey,
                                size: 64
                            ) {
                                Circle().fill(Color.blue.opacity(0.2)).overlay(Text("我"))
                            }
                            .onTapGesture {
                                openRecropExisting(
                                    urlString: store.ownerAvatarFullUrl,
                                    field: "ownerAvatarBase64",
                                    maskShape: .circle,
                                    title: "缩放裁切我的头像",
                                    maxDim: 640
                                )
                            }
                        } else {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Text(String((ownerNameDraft.isEmpty ? "我" : ownerNameDraft).prefix(1)))
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $ownerAvatarItem, matching: .images) {
                                Label("相册选图并自由缩放裁切", systemImage: "crop")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            if store.profile.hasCustomOwnerAvatar {
                                Button {
                                    openRecropExisting(
                                        urlString: store.ownerAvatarFullUrl,
                                        field: "ownerAvatarBase64",
                                        maskShape: .circle,
                                        title: "缩放移动我的头像",
                                        maxDim: 640
                                    )
                                } label: {
                                    Text("✂️ 重新缩放移动我的头像")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)

                                Button("恢复默认文字头像", role: .destructive) {
                                    Task { await store.updateProfile(["resetOwnerAvatar": true]) }
                                }
                                .font(.system(size: 12.5))
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text("我的自定义名字")
                        Spacer()
                        TextField("留空则随人设自动叫老公/乖宝/老爸", text: $ownerNameDraft)
                            .multilineTextAlignment(.trailing)
                    }

                    Button {
                        Task {
                            await store.updateProfile([
                                "hajimiName": hajimiNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "哈基米" : hajimiNameDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                                "ownerName": ownerNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            ])
                        }
                    } label: {
                        Text("保存双方名字设置")
                            .font(.system(size: 14.5, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section("🔊 AI娘二创与百炼语音合成（支持服务端热更新）") {
                    if !store.ttsVoices.isEmpty {
                        Picker(
                            "默认语音音色",
                            selection: Binding(
                                get: { store.ttsConfig.selectedVoiceId },
                                set: { newVid in
                                    Task { await store.selectTtsVoice(voiceId: newVid) }
                                }
                            )
                        ) {
                            ForEach(store.ttsVoices) { v in
                                Text("\(v.name) · \(v.badge)").tag(v.id)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        if let curVoice = store.ttsVoices.first(where: { $0.id == store.ttsConfig.selectedVoiceId }) ?? store.ttsVoices.first {
                            Button {
                                Task {
                                    await store.previewTtsVoice(voice: curVoice)
                                }
                            } label: {
                                Label(
                                    store.ttsLoadingMessageId == "preview-\(curVoice.id)"
                                        ? "正在合成试听语音..."
                                        : "🔊 试听当前选中音色（\(curVoice.name)）",
                                    systemImage: "play.circle.fill"
                                )
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.pink)
                            }
                        }
                    }

                    Button {
                        Task {
                            await store.loadTtsVoices(showSuccessToast: true)
                        }
                    } label: {
                        Label("🔄 从电脑端热更新最新音色列表", systemImage: "arrow.clockwise")
                            .font(.system(size: 13.5, weight: .medium))
                    }
                }

                Section("📡 电脑端 DSH 热点 / Wi-Fi 连接") {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(store.isConnected ? "🟢 已连接同步" : "🟠 未连接（可点下方秒扫热点）")
                            .foregroundColor(store.isConnected ? .green : .orange)
                            .font(.system(size: 13.5, weight: .semibold))
                    }

                    Toggle(
                        isOn: Binding(
                            get: { store.backgroundKeepAliveEnabled },
                            set: { store.setBackgroundKeepAlive($0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🌙 切后台不断连（静音长驻保活）")
                                .font(.system(size: 14, weight: .semibold))
                            Text("切去微信/B站或锁屏时保持 DSH 实时连接，不打断音乐与视频")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(
                        isOn: Binding(
                            get: { store.backgroundNotifyEnabled },
                            set: { store.setBackgroundNotify($0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🔔 后台收到回复弹锁屏横幅")
                                .font(.system(size: 14, weight: .semibold))
                            Text("哈基米在后台回复或完成干活任务时立即弹出系统通知")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                    }

                    TextField("http://172.20.10.x:19390 或 Wi-Fi 地址", text: $serverUrlDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, design: .monospaced))

                    Button {
                        Task {
                            await store.autoScanLanServer()
                            serverUrlDraft = store.serverUrl
                        }
                    } label: {
                        Label(
                            store.isScanningLan ? "正在秒扫手机热点与 Wi-Fi 网段..." : "自动寻址手机个人热点 / Wi-Fi 电脑",
                            systemImage: "personalhotspot"
                        )
                    }
                    .disabled(store.isScanningLan)

                    HStack {
                        TextField("重新输入 6 位配对码（可选）", text: $pinDraft)
                            .keyboardType(.numberPad)
                        Button("更新连接") {
                            Task {
                                if !pinDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                                    _ = await store.pairWithPin(url: serverUrlDraft, code: pinDraft)
                                    pinDraft = ""
                                } else {
                                    store.saveConnection(url: serverUrlDraft)
                                    await store.refreshAll()
                                    store.startSseLoop(force: true)
                                    store.showToast("连接地址已保存")
                                }
                            }
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                    }
                }
            }
            .navigationTitle("🎨 装扮与连接")
            .fullScreenCover(item: $activeCropJob) { job in
                ImageCropperSheet(
                    rawImage: job.image,
                    maskShape: job.maskShape,
                    title: job.title,
                    outputMaxDimension: job.maxDim,
                    onConfirm: { croppedJpeg in
                        let b64 = croppedJpeg.base64EncodedString()
                        let field = job.field
                        let hName = hajimiNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        let oName = ownerNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        activeCropJob = nil
                        Task {
                            var payload: [String: Any] = [field: b64]
                            if !hName.isEmpty { payload["hajimiName"] = hName }
                            payload["ownerName"] = oName
                            await store.updateProfile(payload)
                        }
                    },
                    onCancel: {
                        activeCropJob = nil
                    }
                )
            }
            .onAppear {
                hajimiNameDraft = store.profile.hajimiName
                ownerNameDraft = store.profile.ownerName
                serverUrlDraft = store.serverUrl
            }
            .onChange(of: store.serverUrl) { _, newUrl in
                serverUrlDraft = newUrl
            }
            .onChange(of: store.profile) { _, newProf in
                hajimiNameDraft = newProf.hajimiName
                ownerNameDraft = newProf.ownerName
            }
            .onChange(of: hajimiAvatarItem) { _, item in
                prepareCropFromPicker(
                    item,
                    resetPicker: { hajimiAvatarItem = nil },
                    field: "hajimiAvatarBase64",
                    maskShape: .circle,
                    title: "缩放移动 TA 的头像",
                    maxDim: 640
                )
            }
            .onChange(of: ownerAvatarItem) { _, item in
                prepareCropFromPicker(
                    item,
                    resetPicker: { ownerAvatarItem = nil },
                    field: "ownerAvatarBase64",
                    maskShape: .circle,
                    title: "缩放移动我的头像",
                    maxDim: 640
                )
            }
            .onChange(of: portraitPhotoItem) { _, item in
                prepareCropFromPicker(
                    item,
                    resetPicker: { portraitPhotoItem = nil },
                    field: "portraitBase64",
                    maskShape: .portrait3x4,
                    title: "缩放裁切全身立绘 (3:4)",
                    maxDim: 1440
                )
            }
        }
    }

    private func prepareCropFromPicker(
        _ item: PhotosPickerItem?,
        resetPicker: @escaping () -> Void,
        field: String,
        maskShape: CropMaskShape,
        title: String,
        maxDim: CGFloat
    ) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImg = UIImage(data: data) {
                await MainActor.run {
                    resetPicker()
                    activeCropJob = CropJobItem(
                        image: uiImg,
                        field: field,
                        maskShape: maskShape,
                        title: title,
                        maxDim: maxDim
                    )
                }
            } else {
                await MainActor.run { resetPicker() }
            }
        }
    }

    private func openRecropExisting(
        urlString: String,
        field: String,
        maskShape: CropMaskShape,
        title: String,
        maxDim: CGFloat
    ) {
        if let cached = RemoteImageMemoryCache.shared.get(urlString) {
            activeCropJob = CropJobItem(image: cached, field: field, maskShape: maskShape, title: title, maxDim: maxDim)
            return
        }
        guard let url = URL(string: urlString) else {
            store.showToast("请先连接电脑端 DSH 或从相册选图")
            return
        }
        Task {
            var req = URLRequest(url: url)
            if !store.pairKey.isEmpty {
                req.setValue(store.pairKey, forHTTPHeaderField: "x-hajimi-key")
            }
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let uiImg = UIImage(data: data) {
                RemoteImageMemoryCache.shared.set(urlString, image: uiImg)
                activeCropJob = CropJobItem(image: uiImg, field: field, maskShape: maskShape, title: title, maxDim: maxDim)
            } else {
                store.showToast("尚未加载到原图，请直接从相册选图")
            }
        }
    }
}
