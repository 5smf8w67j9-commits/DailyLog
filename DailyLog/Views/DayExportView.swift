import SwiftUI
import UIKit

/// 把某一天导出成一张竖版长图（固定浅色，分享出去好看）
struct DayExportView: View {
    let date: Date
    let entry: Entry
    let store: EntryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 14) {
                if let mood = entry.mood {
                    infoRow(title: "心情", value: "\(mood) \(MoodCatalog.moodName(mood))")
                }
                if let weather = entry.weather {
                    infoRow(title: "天气", value: "\(weather) \(MoodCatalog.weatherName(weather))")
                }

                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.2, green: 0.21, blue: 0.24))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !entry.imageFiles.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(entry.imageFiles, id: \.self) { name in
                            if let image = store.image(named: name) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }

                if !entry.tags.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.15))
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Color(red: 0.99, green: 0.94, blue: 0.87))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            footer
        }
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(DayText.full(date))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))

            HStack(spacing: 12) {
                if let holiday = ChineseHolidays.info(for: date) {
                    Label(holiday.isOff ? "\(holiday.name) 放假" : "\(holiday.name) 上班",
                          systemImage: holiday.isOff ? "flag.fill" : "briefcase.fill")
                        .foregroundStyle(holiday.isOff
                                         ? Color(red: 0.8, green: 0.2, blue: 0.2)
                                         : Color(red: 0.85, green: 0.5, blue: 0.1))
                }
                Label("\(entry.text.count) 字", systemImage: "text.alignleft")
                Label("\(entry.imageFiles.count) 张图", systemImage: "photo")
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

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.56, blue: 0.6))
                .frame(width: 34, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.2, green: 0.21, blue: 0.24))
            Spacer(minLength: 0)
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
}

/// 单天导出后的预览 + 分享
struct DayExportSheet: View {
    let image: UIImage
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var tempURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("导出 \(DayText.short(date))")
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
                guard tempURL == nil else { return }
                tempURL = Exporter.writeTempPNG(image, name: "每日记录-\(DayKey.key(for: date)).png")
            }
        }
    }
}
