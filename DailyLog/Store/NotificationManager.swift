import Foundation
import UserNotifications
import SwiftUI

/// 每日提醒（本地通知，不需要服务器）
@MainActor
final class NotificationManager: ObservableObject {

    @Published var enabled: Bool
    @Published var hour: Int
    @Published var minute: Int
    @Published private(set) var authorized: Bool = false
    @Published private(set) var lastError: String?

    private let kEnabled = "reminder.enabled"
    private let kHour = "reminder.hour"
    private let kMinute = "reminder.minute"
    private let requestID = "dailylog.daily.reminder"

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

    /// 保存设置并重新排程
    func apply() async {
        lastError = nil
        let d = UserDefaults.standard
        d.set(enabled, forKey: kEnabled)
        d.set(hour, forKey: kHour)
        d.set(minute, forKey: kMinute)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        guard enabled else { return }

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

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "今天还没记呢"
        content.body = "今天遇到什么新鲜事？花一分钟写下来吧"
        content.sound = .default

        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            lastError = "排程失败，请稍后重试"
        }
    }

    /// 打开提醒总开关时调用
    func enable() async {
        enabled = true
        await apply()
    }

    func disable() async {
        enabled = false
        await apply()
    }
}
