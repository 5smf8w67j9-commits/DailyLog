import Foundation

/// 心情 / 天气的固定选项与中文名
enum MoodCatalog {

    static let moods = ["😄", "🙂", "😐", "😔", "😤", "😭"]
    static let weathers = ["☀️", "⛅️", "☁️", "🌧️", "❄️", "🌫️"]

    static let moodNames: [String: String] = [
        "😄": "超开心",
        "🙂": "还不错",
        "😐": "一般般",
        "😔": "有点低落",
        "😤": "有点气",
        "😭": "很难受"
    ]

    static let weatherNames: [String: String] = [
        "☀️": "晴",
        "⛅️": "多云",
        "☁️": "阴",
        "🌧️": "雨",
        "❄️": "雪",
        "🌫️": "雾霾"
    ]

    static func moodName(_ emoji: String) -> String {
        moodNames[emoji] ?? emoji
    }

    static func weatherName(_ emoji: String) -> String {
        weatherNames[emoji] ?? emoji
    }
}
