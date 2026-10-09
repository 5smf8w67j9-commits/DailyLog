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

    // MARK: - 写入

    func setText(_ text: String, for date: Date) {
        let key = DayKey.key(for: date)
        var e = entries[key] ?? Entry(dateKey: key)
        guard e.text != text else { return }
        e.text = text
        e.updatedAt = Date()
        commit(e, key: key)
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
        let key = DayKey.key(for: date)
        var e = entries[key] ?? Entry(dateKey: key)
        e.imageFiles.append(name)
        e.updatedAt = Date()
        commit(e, key: key)
        return true
    }

    func removeImage(named name: String, for date: Date) {
        let key = DayKey.key(for: date)
        guard var e = entries[key] else { return }
        e.imageFiles.removeAll { $0 == name }
        e.updatedAt = Date()
        try? fm.removeItem(at: imagesDir.appendingPathComponent(name))
        commit(e, key: key)
    }

    // MARK: - 内部

    private func commit(_ entry: Entry, key: String) {
        if entry.isEmpty {
            entries[key] = nil
        } else {
            entries[key] = entry
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
