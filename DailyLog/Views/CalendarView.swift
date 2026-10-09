import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: EntryStore

    @State private var monthAnchor: Date = Date()

    private let cal = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    todayCard
                    monthCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("每日记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { monthAnchor = Date() }
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .accessibilityLabel("回到本月")
                }
            }
        }
    }

    // MARK: - 今日卡片

    private var todayCard: some View {
        let entry = store.entry(for: Date())
        return NavigationLink {
            DayDetailView(date: Date())
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("今天 · \(DayText.short(Date()))")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }

                if entry.isEmpty {
                    Text("今天遇到什么新鲜事？点一下写下来")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    if !entry.imageFiles.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(entry.imageFiles.prefix(4), id: \.self) { name in
                                if let img = store.image(named: name) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 月历

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(DayText.monthTitle(monthAnchor))
                    .font(.headline)
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 2)

            HStack(spacing: 6) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let isToday = cal.isDateInToday(date)
        let thumb = store.firstImage(date)
        let has = store.hasContent(date)

        NavigationLink {
            DayDetailView(date: date)
        } label: {
            ZStack {
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                }
                VStack(spacing: 3) {
                    Text("\(cal.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday ? .bold : .medium))
                        .foregroundStyle(thumb != nil ? Color.white : Color.primary)
                    if has && thumb == nil {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(thumb == nil ? Color(.tertiarySystemFill) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 计算

    private var days: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstDay = interval.start
        let weekday = cal.component(.weekday, from: firstDay)   // 1 = 周日
        let leading = max(0, weekday - 1)
        let dayCount = cal.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30

        var result: [Date?] = Array(repeating: nil, count: leading)
        for i in 0..<dayCount {
            if let d = cal.date(byAdding: .day, value: i, to: firstDay) {
                result.append(d)
            }
        }
        return result
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            withAnimation(.easeInOut(duration: 0.2)) { monthAnchor = d }
        }
    }
}
