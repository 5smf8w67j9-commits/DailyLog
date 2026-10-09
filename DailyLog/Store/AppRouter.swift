import Foundation
import SwiftUI
import UIKit

/// 页面路由。用值来描述"要去哪"，这样长按菜单、桌面快捷方式都能程序化导航。
enum Route: Hashable {
    case day(Date)
    case stats
}

/// 全局导航栈
@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [Route] = []

    func open(_ date: Date) {
        path = [.day(date)]
    }

    func openToday() {
        path = [.day(Date())]
    }

    func openStats() {
        path = [.stats]
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }
}

/// 接收桌面图标长按的快捷操作（Home Screen Quick Actions）。
/// 冷启动时 AppDelegate 会先拿到，暂存起来等界面就绪再消费。
final class ShortcutBus {

    static let shared = ShortcutBus()

    static let todayType = "com.lige.dailylog.today"
    static let statsType = "com.lige.dailylog.stats"

    private var pending: String?
    private var handler: ((String) -> Void)?

    private init() {}

    /// AppDelegate 收到快捷操作时调用
    func send(_ type: String) {
        if let handler = self.handler {
            handler(type)
        } else {
            pending = type
        }
    }

    /// 界面准备好后接管；顺带消费冷启动时残留的那一次
    func attach(_ handler: @escaping (String) -> Void) {
        self.handler = handler
        if let queued = self.pending {
            self.pending = nil
            handler(queued)
        }
    }
}

/// 只为了接桌面图标长按的快捷操作。其余生命周期交给 SwiftUI 自己管。
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            ShortcutBus.shared.send(item.type)
        }
        return true
    }

    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        ShortcutBus.shared.send(shortcutItem.type)
        completionHandler(true)
    }
}
