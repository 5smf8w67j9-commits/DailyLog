import Foundation
import UserNotifications
import SwiftUI

/// 每日提醒（本地通知，不需要服务器）。
/// 不重复排一条，而是预排未来 14 天：
/// - 如果那天正好有"往年今日"的记录，就推「那年今日」；
/// - 否则推普通的写日记提醒。
/// 这样同一天只会收到一条通知，不会吵。
@MainActor
final class NotificationManager: ObservableObject {

    @Published var enabled: Bool
    @Published var hour: Int
    @Published var minute: Int
    @Published private(set) var authorized: Bool = false
    @Published private(set) var lastError: String?

    /// 预排的天数（iOS 单个 App 待发通知上限是 64 条，留足余量）
    static let scheduleDays = 14

    private let kEnabled = "reminder.enabled"
    private let kHour = "reminder.hour"
    private let kMinute = "reminder.minute"
    private let idPrefix = "dailylog.daily."
    /// 旧版本用过的一次性 id，清理掉避免残留
    private let legacyID = "dailylog.daily.reminder"

    init() {
        let d = UserDefaults.standard
        enabled = d.bool(forKey: kEnabled)
        hour = (d.object(forKey: kHour) as? Int) ?? 21
        minute = (d.object(forKey: kMinute) as? Int) ?? 0
        Task { await refreshAuthorization() }
    }

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = (settings.authorizationStatus == .authorized)
    }

    /// 保存设置并重新排程未来 14 天
    func apply(using store: EntryStore? = nil) async {
        lastError = nil
        let d = UserDefaults.standard
        d.set(enabled, forKey: kEnabled)
        d.set(hour, forKey: kHour)
        d.set(minute, forKey: kMinute)

        clearScheduled()
        guard enabled else { return }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorized = granted
            guard granted else {
                enabled = false
                d.set(false, forKey: kEnabled)
                lastError = "系统通知权限未开启，请到「设置 → 通知 → 每日记录」里打开"
                return
            }
        } catch {
            lastError = "无法请求通知权限"
            return
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        for offset in 0..<Self.scheduleDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let parts = cal.dateComponents([.year, .month, .day], from: day)

            var fire = DateComponents()
            fire.year = parts.year
            fire.month = parts.month
            fire.day = parts.day
            fire.hour = hour
            fire.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: fire, repeats: false)
            let request = UNNotificationRequest(identifier: idPrefix + "\(offset)",
                                                content: makeContent(for: day, store: store),
                                                trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                lastError = "排程失败，请稍后重试"
                return
            }
        }
    }

    /// 打开提醒总开关时调用
    func enable(using store: EntryStore? = nil) async {
        enabled = true
        await apply(using: store)
    }

    func disable() async {
        enabled = false
        await apply()
    }

    // MARK: - 内部

    private func makeContent(for day: Date, store: EntryStore?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default

        if let preview = store?.onThisDayPreview(for: day) {
            content.title = "那年今日 · \(preview.years) 年前的今天"
            content.body = preview.text
        } else {
            content.title = "今天还没记呢"
            content.body = "今天遇到什么新鲜事？花一分钟写下来吧"
        }
        return content
    }

    private func clearScheduled() {
        let ids = (0..<Self.scheduleDays).map { idPrefix + "\($0)" } + [legacyID]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
