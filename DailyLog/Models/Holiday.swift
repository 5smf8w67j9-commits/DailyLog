import Foundation

/// 某一天的节假日信息
struct HolidayInfo: Hashable {
    /// 节日名，例如「春节」「国庆节」
    let name: String
    /// true = 放假（休）；false = 调休上班（班）
    let isOff: Bool
}

/// 中国法定节假日 / 调休数据
///
/// 数据来源（国务院办公厅通知原文）：
/// - 2025 年：国办发明电〔2024〕12 号
/// - 2026 年：国办发明电〔2025〕7 号
///
/// 注意：每年的调休安排由国务院单独发布，通常在前一年 11 月左右。
/// 新一年的安排公布后，在这里补一段即可。
enum ChineseHolidays {

    static func key(_ y: Int, _ m: Int, _ d: Int) -> String {
        String(format: "%04d-%02d-%02d", y, m, d)
    }

    static let table: [String: HolidayInfo] = {
        var t: [String: HolidayInfo] = [:]

        /// 放假区间（含首尾）
        func off(_ y: Int, _ m: Int, _ from: Int, _ to: Int, _ name: String) {
            for d in from...to {
                t[key(y, m, d)] = HolidayInfo(name: name, isOff: true)
            }
        }
        /// 调休上班日
        func work(_ y: Int, _ m: Int, _ days: [Int], _ name: String) {
            for d in days {
                t[key(y, m, d)] = HolidayInfo(name: name, isOff: false)
            }
        }

        // MARK: 2025 年

        off(2025, 1, 1, 1, "元旦")
        off(2025, 1, 28, 31, "春节")
        off(2025, 2, 1, 4, "春节")
        off(2025, 4, 4, 6, "清明节")
        off(2025, 5, 1, 5, "劳动节")
        off(2025, 5, 31, 31, "端午节")
        off(2025, 6, 1, 2, "端午节")
        off(2025, 10, 1, 8, "国庆节·中秋节")
        work(2025, 1, [26], "春节调休")
        work(2025, 2, [8], "春节调休")
        work(2025, 4, [27], "劳动节调休")
        work(2025, 9, [28], "国庆调休")
        work(2025, 10, [11], "国庆调休")

        // MARK: 2026 年

        off(2026, 1, 1, 3, "元旦")
        off(2026, 2, 15, 23, "春节")
        off(2026, 4, 4, 6, "清明节")
        off(2026, 5, 1, 5, "劳动节")
        off(2026, 6, 19, 21, "端午节")
        off(2026, 9, 25, 27, "中秋节")
        off(2026, 10, 1, 7, "国庆节")
        work(2026, 1, [4], "元旦调休")
        work(2026, 2, [14, 28], "春节调休")
        work(2026, 5, [9], "劳动节调休")
        work(2026, 9, [20], "国庆调休")
        work(2026, 10, [10], "国庆调休")

        return t
    }()

    /// 已收录数据的年份
    static let coveredYears: Set<Int> = [2025, 2026]

    static func info(for date: Date) -> HolidayInfo? {
        table[DayKey.key(for: date)]
    }

    /// 该年份是否已有数据（没有则日历上不会显示休/班标记）
    static func hasData(for year: Int) -> Bool {
        coveredYears.contains(year)
    }
}
