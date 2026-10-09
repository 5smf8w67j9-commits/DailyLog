import SwiftUI

@main
struct DailyLogApp: App {
    @StateObject private var store = EntryStore()
    @StateObject private var lock = AppLock()
    @StateObject private var notif = NotificationManager()

    @Environment(\.scenePhase) private var scenePhase

    /// 外观偏好（跟随系统 / 浅色 / 深色），存在 UserDefaults
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                CalendarView()

                if lock.isLocked {
                    LockScreenView(lock: lock)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environmentObject(store)
            .environmentObject(lock)
            .environmentObject(notif)
            // 在 App 内强制指定配色；nil 时跟随系统
            .preferredColorScheme(appearance.colorScheme)
            .animation(.easeInOut(duration: 0.28), value: appearanceRaw)
            .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
            .task {
                // 冷启动时把未来几天的提醒排一遍
                if notif.enabled {
                    await notif.apply(using: store)
                }
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    // 回到前台时立刻校准"今天"，实现白天跨天自动换新页
                    store.refreshToday()

                    if lock.isLocked {
                        Task { await lock.unlock() }
                    }
                    // 重排提醒，保证「那年今日」用的是最新的记录
                    if notif.enabled {
                        Task { await notif.apply(using: store) }
                    }

                case .background:
                    store.flush()
                    lock.lock()

                default:
                    break
                }
            }
        }
    }
}
