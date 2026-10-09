import SwiftUI
import UIKit

/// 把一个月导出成一张长图
@MainActor
enum Exporter {

    static func monthImage(month: Date, store: EntryStore) -> UIImage? {
        let items: [(date: Date, entry: Entry)] = store.entries(in: month).compactMap { e in
            guard let d = DayKey.date(from: e.dateKey) else { return nil }
            return (d, e)
        }
        guard !items.isEmpty else { return nil }

        let content = MonthExportView(month: month, items: items, store: store)
            .frame(width: 390)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        // 2 倍足够清晰，同时避免长图过大导致内存吃紧
        renderer.scale = 2
        return renderer.uiImage
    }

    /// 写进临时目录，便于分享
    static func writeTempPNG(_ image: UIImage, name: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// 导出用的月历长图内容（固定浅色，保证分享出去好看）
struct MonthExportView: View {
    let month: Date
    let items: [(date: Date, entry: Entry)]
    let store: EntryStore

    private var recordedDays: Int { items.count }
    private var imageCount: Int { items.reduce(0) { $0 + $1.entry.imageFiles.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    entryBlock(item.date, item.entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            footer
        }
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DayText.monthTitle(month))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))

            HStack(spacing: 12) {
                Label("记录 \(recordedDays) 天", systemImage: "calendar")
                Label("\(imageCount) 张图", systemImage: "photo")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color(red: 0.45, green: 0.46, blue: 0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.55),
                                    Color.white],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func entryBlock(_ date: Date, _ entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧日期
            VStack(spacing: 1) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                Text(weekdayShort(date))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.55, green: 0.56, blue: 0.6))
            }
            .frame(width: 40)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    if let mood = entry.mood { Text(mood).font(.system(size: 14)) }
                    if let weather = entry.weather { Text(weather).font(.system(size: 14)) }
                    if let holiday = ChineseHolidays.info(for: date), holiday.isOff {
                        Text(holiday.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    Spacer(minLength: 0)
                }

                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color(red: 0.2, green: 0.21, blue: 0.24))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let name = entry.imageFiles.first, let img = store.image(named: name) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            if entry.imageFiles.count > 1 {
                                Text("+\(entry.imageFiles.count - 1)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Capsule())
                                    .padding(6)
                            }
                        }
                }

                if !entry.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.15))
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.975, green: 0.972, blue: 0.965))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "book.closed")
                .font(.system(size: 10))
            Text("由「每日记录」生成")
                .font(.system(size: 11))
            Spacer()
            Text(Date(), style: .date)
                .font(.system(size: 11))
        }
        .foregroundStyle(Color(red: 0.6, green: 0.61, blue: 0.65))
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func weekdayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

/// 导出预览 + 分享
struct ExportPreviewSheet: View {
    let image: UIImage?
    let month: Date

    @Environment(\.dismiss) private var dismiss
    @State private var tempURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34))
                            .foregroundStyle(.tertiary)
                        Text("这个月还没有记录")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 80)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("导出 \(DayText.monthTitle(month))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let tempURL {
                        ShareLink(item: tempURL) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task {
                guard let image, tempURL == nil else { return }
                tempURL = Exporter.writeTempPNG(image, name: "DailyLog-\(DayKey.key(for: month)).png")
            }
        }
    }
}
