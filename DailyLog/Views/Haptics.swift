import UIKit

/// 全局触觉反馈。
/// 复用 generator 实例，震动更跟手（每次都新建会有明显延迟）。
enum Haptics {

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    /// 轻点一下——普通按钮
    static func tap() {
        light.impactOccurred()
    }

    /// 中等力度——切换月份、点开卡片
    static func bump() {
        medium.impactOccurred()
    }

    /// 干脆的一下——长按激活
    static func snap() {
        rigid.impactOccurred()
    }

    /// 选择项变化——心情、天气、标签
    static func pick() {
        selection.selectionChanged()
    }

    /// 操作成功——保存、复制、记录完成
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// 警告 / 删除
    static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// 出错
    static func error() {
        notification.notificationOccurred(.error)
    }
}
