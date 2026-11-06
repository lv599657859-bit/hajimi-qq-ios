import SwiftUI
import UIKit
import PhotosUI

struct ProfileSettingsTabView: View {
    @EnvironmentObject var store: HajimiStore
    @State private var hajimiNameDraft: String = ""
    @State private var ownerNameDraft: String = ""
    @State private var serverUrlDraft: String = ""
    @State private var pinDraft: String = ""

    @State private var hajimiAvatarItem: PhotosPickerItem?
    @State private var ownerAvatarItem: PhotosPickerItem?
    @State private var portraitPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("💕 对方形象与名字定制（TA 的头像与昵称）") {
                    HStack(spacing: 14) {
                        CachedAvatarImage(
                            urlString: store.hajimiAvatarFullUrl,
                            pairKey: store.pairKey,
                            size: 62
                        ) {
                            Circle().fill(Color.purple.opacity(0.2)).overlay(Text("💕"))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $hajimiAvatarItem, matching: .images) {
                                Text("从手机相册更换 TA 的头像")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            if store.profile.hasCustomHajimiAvatar {
                                Button("恢复默认原画头像", role: .destructive) {
                                    Task { await store.updateProfile(["resetHajimiAvatar": true]) }
                                }
                                .font(.system(size: 12.5))
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
                        Label("更换聊天窗全身立绘卡图片", systemImage: "person.crop.rectangle")
                            .font(.system(size: 14))
                    }
                    if store.profile.hasCustomPortrait {
                        Button("恢复默认全身立绘", role: .destructive) {
                            Task { await store.updateProfile(["resetPortrait": true]) }
                        }
                        .font(.system(size: 13))
                    }
                }

                Section("🧑 我的形象与名字定制（我的头像与昵称）") {
                    HStack(spacing: 14) {
                        if store.profile.hasCustomOwnerAvatar {
                            CachedAvatarImage(
                                urlString: store.ownerAvatarFullUrl,
                                pairKey: store.pairKey,
                                size: 62
                            ) {
                                Circle().fill(Color.blue.opacity(0.2)).overlay(Text("我"))
                            }
                        } else {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 62, height: 62)
                                .overlay(
                                    Text(String((ownerNameDraft.isEmpty ? "我" : ownerNameDraft).prefix(1)))
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $ownerAvatarItem, matching: .images) {
                                Text("从手机相册更换我的头像")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            if store.profile.hasCustomOwnerAvatar {
                                Button("恢复默认文字头像", role: .destructive) {
                                    Task { await store.updateProfile(["resetOwnerAvatar": true]) }
                                }
                                .font(.system(size: 12.5))
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

                Section("📡 电脑端 DSH 局域网连接") {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(store.isConnected ? "🟢 已连接同步" : "🟠 未连接")
                            .foregroundColor(store.isConnected ? .green : .orange)
                            .font(.system(size: 13.5, weight: .semibold))
                    }

                    TextField("http://192.168.x.x:19390", text: $serverUrlDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, design: .monospaced))

                    Button {
                        Task {
                            await store.autoScanLanServer()
                            serverUrlDraft = store.serverUrl
                        }
                    } label: {
                        Label(store.isScanningLan ? "正在扫描当前 Wi-Fi 网段..." : "自动扫描局域网内的电脑 DSH", systemImage: "dot.radiowaves.left.and.right")
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
                                    store.startSseLoop()
                                    store.showToast("连接地址已保存")
                                }
                            }
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                    }
                }
            }
            .navigationTitle("🎨 装扮与连接")
            .onAppear {
                hajimiNameDraft = store.profile.hajimiName
                ownerNameDraft = store.profile.ownerName
                serverUrlDraft = store.serverUrl
            }
            .onChange(of: store.profile) { _, newProf in
                hajimiNameDraft = newProf.hajimiName
                ownerNameDraft = newProf.ownerName
            }
            .onChange(of: hajimiAvatarItem) { _, item in
                uploadPhotoItem(item, field: "hajimiAvatarBase64", maxDim: 512)
            }
            .onChange(of: ownerAvatarItem) { _, item in
                uploadPhotoItem(item, field: "ownerAvatarBase64", maxDim: 512)
            }
            .onChange(of: portraitPhotoItem) { _, item in
                uploadPhotoItem(item, field: "portraitBase64", maxDim: 1440)
            }
        }
    }

    private func uploadPhotoItem(_ item: PhotosPickerItem?, field: String, maxDim: CGFloat) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let b64 = ImageCompressionHelper.compressToJpegBase64(data, maxDimension: maxDim, quality: 0.88) {
                await store.updateProfile([field: b64])
            }
        }
    }
}
