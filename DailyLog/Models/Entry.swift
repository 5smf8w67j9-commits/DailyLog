import Foundation

/// 一天的一条记录
struct Entry: Identifiable, Codable, Hashable {
    var id: UUID
    /// 所属日期，格式 yyyy-MM-dd
    var dateKey: String
    /// 文字内容
    var text: String
    /// 图片文件名（存于 Documents/Images/ 下）
    var imageFiles: [String]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         dateKey: String,
         text: String = "",
         imageFiles: [String] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.dateKey = dateKey
        self.text = text
        self.imageFiles = imageFiles
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 完全空白（文字与图片都为空）
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageFiles.isEmpty
    }
}

/// 日期与日期字符串的互转（固定时区安全的 yyyy-MM-dd）
enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }
}

/// 中文展示用的格式化
enum DayText {
    static func full(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日 EEEE"
        return f.string(from: date)
    }

    static func short(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日"
        return f.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: date)
    }
}
