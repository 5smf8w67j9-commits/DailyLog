import SwiftUI

/// 长按日历 / 今日卡片时浮起来的预览卡
struct DayPeekCard: View {
    let date: Date
    @ObservedObject var store: EntryStore

    var body: some View {
        let entry = store.entry(for: date)
        let holiday = ChineseHolidays.info(for: date)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Text(DayText.short(date))
                    .font(.subheadline).fontWeight(.semibold)

                if let holiday {
                    Text(holiday.isOff ? holiday.name : "\(holiday.name) 上班")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(holiday.isOff ? Color.red : Color.orange)
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)

                if !entry.isEmpty {
                    HStack(spacing: 8) {
                        Label("\(entry.text.count)", systemImage: "text.alignleft")
                        if !entry.imageFiles.isEmpty {
                            Label("\(entry.imageFiles.count)", systemImage: "photo")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
            }

            if entry.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Color.accentColor)
                    Text("这天还是空的，松手后可以补写")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else {
                if entry.mood != nil || entry.weather != nil {
                    HStack(spacing: 6) {
                        if let mood = entry.mood {
                            Text(mood).font(.system(size: 17))
                        }
                        if let weather = entry.weather {
                            Text(weather).font(.system(size: 17))
                        }
                        Spacer(minLength: 0)
                    }
                }

                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let name = entry.imageFiles.first, let image = store.image(named: name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 128)
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
                    HStack(spacing: 6) {
                        ForEach(entry.tags.prefix(4), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
    }
}
