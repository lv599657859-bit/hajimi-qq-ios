import SwiftUI

@main
struct HajimiQQApp: App {
    @StateObject private var store = HajimiStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootMainTabView()
                .environmentObject(store)
                .task {
                    await store.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await store.handleAppDidBecomeActive()
                        }
                    }
                }
        }
    }
}

struct RootMainTabView: View {
    @EnvironmentObject var store: HajimiStore

    private var totalUnread: Int {
        store.unreadBySession.values.reduce(0, +)
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                MessagesTabView()
                    .tabItem {
                        Label("消息", systemImage: "message.fill")
                    }
                    .badge(totalUnread > 0 ? totalUnread : 0)

                SoulMemoryTabView()
                    .tabItem {
                        Label("生命与星海", systemImage: "sparkles")
                    }

                ProfileSettingsTabView()
                    .tabItem {
                        Label("装扮与连接", systemImage: "paintbrush.pointed.fill")
                    }
            }

            if !store.toastMessage.isEmpty {
                Text(store.toastMessage)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.82))
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(99)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toastMessage)
    }
}
