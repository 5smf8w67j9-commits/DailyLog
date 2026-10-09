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
        return true
    }

    func removeImage(named name: String, for date: Date) {
        try? fm.removeItem(at: imagesDir.appendingPathComponent(name))
        mutate(date) { $0.imageFiles.removeAll { $0 == name } }
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
