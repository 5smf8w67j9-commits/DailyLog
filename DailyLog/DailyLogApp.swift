import SwiftUI

@main
struct DailyLogApp: App {
    @StateObject private var store = EntryStore()
    @Environment(\.scenePhase) private var scenePhase

    /// 外观偏好（跟随系统 / 浅色 / 深色），存在 UserDefaults
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            CalendarView()
                .environmentObject(store)
                // 在 App 内强制指定配色；nil 时跟随系统
                .preferredColorScheme(appearance.colorScheme)
                .animation(.easeInOut(duration: 0.28), value: appearanceRaw)
                .onChange(of: scenePhase) { phase in
                    // 回到前台时立刻校准"今天"，实现白天跨天自动换新页
                    if phase == .active {
                        store.refreshToday()
                    }
                }
        }
    }
}
