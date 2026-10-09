import SwiftUI

@main
struct DailyLogApp: App {
    @StateObject private var store = EntryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CalendarView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    // 回到前台时立刻校准"今天"，实现白天跨天自动换新页
                    if phase == .active {
                        store.refreshToday()
                    }
                }
        }
    }
}
