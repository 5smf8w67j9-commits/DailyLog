import Foundation
import SwiftUI
import UIKit

/// 数据仓库：负责所有每日记录的读写、图片落盘，以及"每天自动换新页"的日期监听。
final class EntryStore: ObservableObject {

    /// dateKey(yyyy-MM-dd) -> Entry
    @Published private(set) var entries: [String: Entry] = [:]

    /// 当前"今天"的 key，跨天时会变化，界面据此自动切到新的一天
    @Published private(set) var todayKey: String = DayKey.key(for: Date())

    private let fm = FileManager.default
    private let imagesDir: URL
    private let storeURL: URL
    private var dayTimer: Timer?
    private var pendingSave: DispatchWorkItem?

    init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imagesDir = docs.appendingPathComponent("Images", isDirectory: true)
        storeURL = docs.appendingPathComponent("entries.json")
        try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
        startDayWatcher()
    }

    deinit {
        dayTimer?.invalidate()
    }

    // MARK: - 每天自动换新页

    private func startDayWatcher() {
        // 每 30 秒校准一次日期；跨天后 todayKey 变化，正在看"今天"的页面会自动切到新的一天
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshToday()
        }
        RunLoop.main.add(timer, forMode: .common)
        dayTimer = timer
    }

    func refreshToday() {
        let key = DayKey.key(for: Date())
        if key != todayKey {
            todayKey = key
        }
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - 读取

    func entry(for date: Date) -> Entry {
        let key = DayKey.key(for: date)
        return entries[key] ?? Entry(dateKey: key)
    }

    func hasContent(_ date: Date) -> Bool {
        guard let e = entries[DayKey.key(for: date)] else { return false }
        return !e.isEmpty
    }

    func imageCount(_ date: Date) -> Int {
        entries[DayKey.key(for: date)]?.imageFiles.count ?? 0
    }

    /// 某天的第一张图，用于日历格子的缩略图
    func firstImage(_ date: Date) -> UIImage? {
        guard let name = entries[DayKey.key(for: date)]?.imageFiles.first else { return nil }
        return image(named: name)
    }

    func image(named name: String) -> UIImage? {
        let url = imagesDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// 那年今日：往年同月同日、且写过内容的记录，按年份倒序
    func pastYearsEntries(for date: Date) -> [PastEntry] {
        let cal = Calendar.current
        let target = cal.dateComponents([.year, .month, .day], from: date)
        guard let tm = target.month, let td = target.day, let ty = target.year else { return [] }

        var result: [PastEntry] = []
        for (key, entry) in entries {
            guard let d = DayKey.date(from: key) else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: d)
            guard let y = c.year, let m = c.month, let day = c.day else { continue }
            if m == tm && day == td && y < ty && !entry.isEmpty {
                result.append(PastEntry(year: y, entry: entry))
            }
        }
        return result.sorted { $0.year > $1.year }
    }

    // MARK: - 统计

    /// 有内容的天数
    var recordedDayCount: Int { entries.count }

    /// 总字数
    var totalWordCount: Int {
        entries.values.reduce(0) { $0 + $1.text.count }
    }

    /// 总图片数
    var totalImageCount: Int {
        entries.values.reduce(0) { $0 + $1.imageFiles.count }
    }

    /// 所有用过的标签，按使用次数从多到少
    func allTags() -> [String] {
        var counter: [String: Int] = [:]
        for e in entries.values {
            for t in e.tags { counter[t, default: 0] += 1 }
        }
        return counter.sorted {
            $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
        }.map(\.key)
    }

    // MARK: - 连续记录 / 热力图

    private func filled(_ date: Date) -> Bool {
        guard let e = entries[DayKey.key(for: date)] else { return false }
        return !e.isEmpty
    }

    /// 今天写了没
    var hasToday: Bool { filled(Date()) }

    /// 当前连续记录天数。今天还没写不算断，从昨天往前数。
    var currentStreak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if !filled(day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while filled(day) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// 历史最长连续记录天数
    var longestStreak: Int {
        let cal = Calendar.current
        let days = entries.values
            .filter { !$0.isEmpty }
            .compactMap { DayKey.date(from: $0.dateKey) }
            .map { cal.startOfDay(for: $0) }
            .sorted()
        guard !days.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for i in 1..<days.count {
            let gap = cal.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            if gap == 1 {
                run += 1
                best = max(best, run)
            } else if gap > 1 {
                run = 1
            }
        }
        return best
    }

    /// 某天的"记录强度"0~4，用于热力图配色
    func level(for date: Date) -> Int {
        guard let e = entries[DayKey.key(for: date)], !e.isEmpty else { return 0 }
        let words = e.text.trimmingCharacters(in: .whitespacesAndNewlines).count
        var score = 0
        if words > 0 { score += 1 }
        if words >= 100 { score += 1 }
        if !e.imageFiles.isEmpty { score += 1 }
        if e.mood != nil || e.weather != nil { score += 1 }
        return min(score, 4)
    }

    /// 热力图：最近 `weeks` 周，每列一周（周日 → 周六），未来日期为 nil
    func heatmap(weeks: Int = 26, endingOn end: Date = Date()) -> [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: end)
        let weekday = cal.component(.weekday, from: today)   // 1 = 周日
        guard let thisWeekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: today),
              let firstWeekStart = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: thisWeekStart)
        else { return [] }

        var cols: [[Date?]] = []
        for w in 0..<weeks {
            var col: [Date?] = []
            for d in 0..<7 {
                if let date = cal.date(byAdding: .day, value: w * 7 + d, to: firstWeekStart), date <= today {
                    col.append(date)
                } else {
                    col.append(nil)
                }
            }
            cols.append(col)
        }
        return cols
    }

    /// 心情出现次数，按次数从多到少
    func moodCounts() -> [(mood: String, count: Int)] {
        var counter: [String: Int] = [:]
        for e in entries.values {
            if let m = e.mood { counter[m, default: 0] += 1 }
        }
        return counter
            .map { (mood: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.mood < $1.mood : $0.count > $1.count }
    }

    /// 某个月里有记录的天数
    func recordedDays(in month: Date) -> Int {
        entries(in: month).count
    }

    /// 给「那年今日」通知用的一句话预览
    func onThisDayPreview(for date: Date) -> (years: Int, text: String)? {
        guard let item = pastYearsEntries(for: date).first else { return nil }
        let years = DayText.year(date) - item.year
        guard years > 0 else { return nil }

        var parts: [String] = []
        if let mood = item.entry.mood { parts.append(mood) }
        let body = item.entry.summary
        if !body.isEmpty { parts.append(String(body.prefix(38))) }
        let text = parts.isEmpty ? "点开看看当时写了什么" : parts.joined(separator: " ")
        return (years, text)
    }

    // MARK: - 搜索

    /// 全文搜索：匹配正文与标签
    func search(_ query: String, tag: String? = nil) -> [Entry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var list = entries.values.filter { !$0.isEmpty }

        if let tag, !tag.isEmpty {
            list = list.filter { $0.tags.contains(tag) }
        }
        if !q.isEmpty {
            list = list.filter { $0.searchBlob.contains(q) }
        }
        return list.sorted { $0.dateKey > $1.dateKey }
    }

    /// 某个自然月内有内容的记录，按日期升序（导出用）
    func entries(in month: Date) -> [Entry] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        return entries.values
            .filter { e in
                guard let d = DayKey.date(from: e.dateKey) else { return false }
                return d >= interval.start && d < interval.end && !e.isEmpty
            }
            .sorted { $0.dateKey < $1.dateKey }
    }

    // MARK: - 写入

    func setText(_ text: String, for date: Date) {
        let key = DayKey.key(for: date)
        guard (entries[key]?.text ?? "") != text else { return }
        mutate(date) { $0.text = text }
    }

    func setMood(_ mood: String?, for date: Date) {
        mutate(date) { $0.mood = mood }
    }

    func setWeather(_ weather: String?, for date: Date) {
        mutate(date) { $0.weather = weather }
    }

    func setTags(_ tags: [String], for date: Date) {
        mutate(date) { $0.tags = tags }
    }

    @discardableResult
    func addImage(_ image: UIImage, for date: Date) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.95) else { return false }
        return addImage(data, for: date)
    }

    @discardableResult
    func addImage(_ data: Data, for date: Date) -> Bool {
        guard let jpeg = Self.downscale(data, maxSide: 1600, quality: 0.82) else { return false }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: imagesDir.appendingPathComponent(name), options: .atomic)
        } catch {
            return false
        }
        mutate(date) { $0.imageFiles.append(name) }
        flush()
        return true
    }

    func removeImage(named name: String, for date: Date) {
        try? fm.removeItem(at: imagesDir.appendingPathComponent(name))
        mutate(date) { $0.imageFiles.removeAll { $0 == name } }
        flush()
    }

    /// 把某张图提到第一位（日历格子的封面）
    func moveImageToFront(_ name: String, for date: Date) {
        mutate(date) { entry in
            guard let index = entry.imageFiles.firstIndex(of: name), index > 0 else { return }
            entry.imageFiles.remove(at: index)
            entry.imageFiles.insert(name, at: 0)
        }
        flush()
    }

    /// 追加一段文字（快速记录用），空则忽略
    func appendText(_ text: String, for date: Date) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate(date) { entry in
            if entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                entry.text = trimmed
            } else {
                entry.text += "\n" + trimmed
            }
        }
        flush()
    }

    /// 清空某天的全部内容（含图片文件）
    func clearDay(_ date: Date) {
        let key = DayKey.key(for: date)
        guard let entry = entries[key] else { return }
        for name in entry.imageFiles {
            try? fm.removeItem(at: imagesDir.appendingPathComponent(name))
        }
        entries[key] = nil
        save()
    }

    // MARK: - 备份 / 恢复
    //
    // 把全部记录 + 图片打包成一个 JSON 文件（图片按 base64 内嵌）。
    // 导出后可以存到 iCloud 云盘、微信、电脑；换手机时导入即可合并回来。
    // 这是当前（免费签名）方案下最实用的"跨设备同步"手段。

    /// 备份文件的结构
    struct BackupFile: Codable {
        var format: String
        var version: Int
        var exportedAt: Date
        var app: String
        /// dateKey -> Entry
        var entries: [String: Entry]
        /// 图片文件名 -> JPEG 原始数据（JSON 中自动编码为 base64）
        var images: [String: Data]
    }

    /// 备份文件里大致有多少东西，用于导入前的确认提示
    struct BackupSummary {
        var days: Int
        var words: Int
        var images: Int
    }

    enum BackupError: LocalizedError {
        case badFormat

        var errorDescription: String? {
            switch self {
            case .badFormat:
                return "这个文件不是「每日记录」导出的备份"
            }
        }
    }

    static let backupFormat = "dailylog-backup"

    /// 打包当前全部数据
    func makeBackupData() throws -> Data {
        var images: [String: Data] = [:]
        for name in Set(entries.values.flatMap { $0.imageFiles }) {
            if let data = try? Data(contentsOf: imagesDir.appendingPathComponent(name)) {
                images[name] = data
            }
        }
        let payload = BackupFile(format: Self.backupFormat,
                                 version: 1,
                                 exportedAt: Date(),
                                 app: "每日记录",
                                 entries: entries,
                                 images: images)
        return try JSONEncoder().encode(payload)
    }

    /// 只读取概要，不改动数据
    func peekBackup(_ data: Data) throws -> BackupSummary {
        let payload = try decodeBackup(data)
        return BackupSummary(days: payload.entries.count,
                             words: payload.entries.values.reduce(0) { $0 + $1.text.count },
                             images: payload.images.count)
    }

    /// 合并恢复：同一天以 updatedAt 较新的为准，不会把本地更新的内容覆盖掉
    @discardableResult
    func restoreBackup(_ data: Data) throws -> (added: Int, updated: Int, images: Int) {
        let payload = try decodeBackup(data)

        var writtenImages = 0
        for (name, imageData) in payload.images {
            let url = imagesDir.appendingPathComponent(name)
            guard !fm.fileExists(atPath: url.path) else { continue }
            if (try? imageData.write(to: url, options: .atomic)) != nil {
                writtenImages += 1
            }
        }

        var added = 0
        var updated = 0
        var merged = entries
        for (key, remote) in payload.entries {
            if let local = merged[key] {
                if remote.updatedAt > local.updatedAt {
                    merged[key] = remote
                    updated += 1
                }
            } else {
                merged[key] = remote
                added += 1
            }
        }

        if added > 0 || updated > 0 {
            entries = merged
            save()
        }
        return (added, updated, writtenImages)
    }

    private func decodeBackup(_ data: Data) throws -> BackupFile {
        let payload = try JSONDecoder().decode(BackupFile.self, from: data)
        guard payload.format == Self.backupFormat else { throw BackupError.badFormat }
        return payload
    }

    // MARK: - 内部

    /// 统一入口：取出当天记录 → 修改 → 回写（空则删除）
    private func mutate(_ date: Date, _ change: (inout Entry) -> Void) {
        let key = DayKey.key(for: date)
        var e = entries[key] ?? Entry(dateKey: key)
        change(&e)
        e.updatedAt = Date()
        if e.isEmpty {
            entries[key] = nil
        } else {
            entries[key] = e
        }
        scheduleSave()
    }

    /// 写盘防抖：语音输入、快速打字时会高频触发，攒 0.5 秒写一次
    private func scheduleSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.pendingSave = nil
            self?.save()
        }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    /// 立刻把待写内容落盘（进后台、离开页面时调用）
    func flush() {
        guard let item = pendingSave else { return }
        item.cancel()
        pendingSave = nil
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("[EntryStore] save failed:", error)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        }
    }

    /// 压缩 + 限制最大边长，避免原图太大
    private static func downscale(_ data: Data, maxSide: CGFloat, quality: CGFloat) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let w = img.size.width
        let h = img.size.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, maxSide / max(w, h))
        if scale >= 1 {
            return img.jpegData(compressionQuality: quality)
        }
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
