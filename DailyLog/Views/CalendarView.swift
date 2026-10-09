import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: EntryStore

    @State private var monthAnchor: Date = Date()
    @StateObject private var checker = UpdateChecker()
    @State private var showAbout = false

    private let cal = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    todayCard
                    monthCard
                    onThisDayCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("每日记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAbout = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "info.circle")
                            if checker.hasUpdate {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .accessibilityLabel("关于与检查更新")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { monthAnchor = Date() }
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .accessibilityLabel("回到本月")
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutView(checker: checker)
                    .environmentObject(store)
            }
            .task {
                // 启动后静默检查一次，有新版本会在左上角显示红点
                await checker.check(silent: true)
            }
        }
    }

    // MARK: - 今日卡片

    private var todayCard: some View {
        let today = Date()
        let entry = store.entry(for: today)
        let holiday = ChineseHolidays.info(for: today)

        return NavigationLink {
            DayDetailView(date: today)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("今天 · \(DayText.short(today))")
                        .font(.subheadline).fontWeight(.semibold)
                    if let holiday {
                        Text(holiday.isOff ? "\(holiday.name) 放假" : "\(holiday.name) 上班")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2.5)
                            .background(holiday.isOff ? Color.red : Color.orange)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }

                if entry.isEmpty {
                    Text("今天遇到什么新鲜事？点一下写下来")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        if let mood = entry.mood { Text(mood).font(.system(size: 17)) }
                        if let weather = entry.weather { Text(weather).font(.system(size: 17)) }
                        if !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(entry.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
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
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(DayText.monthTitle(monthAnchor))
                    .font(.headline)
                Spacer()
                Button { shiftMonth(1) } label: {
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

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }

            legend
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: .red, text: "休")
            legendItem(color: .orange, text: "班")
            HStack(spacing: 4) {
                Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                Text("有记录").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(text == "休" ? "放假" : "上班")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let isToday = cal.isDateInToday(date)
        let thumb = store.firstImage(date)
        let dayEntry = store.entry(for: date)
        let holiday = ChineseHolidays.info(for: date)
        let has = store.hasContent(date)

        NavigationLink {
            DayDetailView(date: date)
        } label: {
            ZStack {
                // 背景：有图显示图，节假日染色，其余用系统填充色
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                    LinearGradient(colors: [Color.black.opacity(0.10), Color.black.opacity(0.42)],
                                   startPoint: .top, endPoint: .bottom)
                } else if let holiday {
                    (holiday.isOff ? Color.red : Color.orange).opacity(0.13)
                } else {
                    Color(.tertiarySystemFill)
                }

                VStack(spacing: 1) {
                    Text("\(cal.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday ? .bold : .medium))
                        .foregroundStyle(dayNumberColor(thumb: thumb, holiday: holiday))
                    if let mood = dayEntry.mood {
                        Text(mood).font(.system(size: 12))
                    } else if has && thumb == nil {
                        Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topLeading) {
                if let holiday {
                    Text(holiday.isOff ? "休" : "班")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3.5).padding(.vertical, 1)
                        .background(holiday.isOff ? Color.red : Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                        .padding(3)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func dayNumberColor(thumb: UIImage?, holiday: HolidayInfo?) -> Color {
        if thumb != nil { return .white }
        if let h = holiday {
            return h.isOff ? .red : .orange
        }
        return .primary
    }

    // MARK: - 那年今日

    @ViewBuilder
    private var onThisDayCard: some View {
        let past = store.pastYearsEntries(for: Date())
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Color.accentColor)
                    Text("那年今日")
                        .font(.subheadline).fontWeight(.semibold)
                }

                ForEach(past) { item in
                    NavigationLink {
                        DayDetailView(date: DayKey.date(from: item.entry.dateKey) ?? Date())
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("\(item.year) 年的今天")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                if let mood = item.entry.mood { Text(mood).font(.caption) }
                                if let weather = item.entry.weather { Text(weather).font(.caption) }
                            }
                            if !item.entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(item.entry.text)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            if let name = item.entry.imageFiles.first, let img = store.image(named: name) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 96)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
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
