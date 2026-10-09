import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: EntryStore

    @StateObject private var checker = UpdateChecker()
    @State private var monthAnchor: Date = Date()
    @State private var monthDirection: Int = 1

    @State private var showSettings = false
    @State private var showSearch = false

    @State private var exportImage: UIImage?
    @State private var showExport = false
    @State private var exporting = false

    private let cal = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    todayCard.staggered(0)
                    monthCard.staggered(1)
                    onThisDayCard.staggered(2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.Background())
            .navigationTitle("每日记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "gearshape")
                            if checker.hasUpdate {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -4)
                                    .transition(.scale)
                            }
                        }
                    }
                    .accessibilityLabel("设置")
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("搜索")

                    Button { exportMonth() } label: {
                        if exporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(exporting)
                    .accessibilityLabel("导出本月长图")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(checker: checker)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showExport) {
                ExportPreviewSheet(image: exportImage, month: monthAnchor)
            }
            .task {
                await checker.check(silent: true)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: checker.hasUpdate)
        }
    }

    // MARK: - 导出

    private func exportMonth() {
        exporting = true
        let month = monthAnchor
        Task { @MainActor in
            let image = Exporter.monthImage(month: month, store: store)
            exporting = false
            if let image {
                exportImage = image
                showExport = true
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
                        if let mood = entry.mood {
                            Text(mood).font(.system(size: 18))
                                .transition(.scale.combined(with: .opacity))
                        }
                        if let weather = entry.weather {
                            Text(weather).font(.system(size: 18))
                                .transition(.scale.combined(with: .opacity))
                        }
                        if !entry.summary.isEmpty {
                            Text(entry.summary)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    if !entry.tags.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(entry.tags.prefix(4), id: \.self) { tag in
                                TagChip(text: "#\(tag)")
                            }
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
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.22),
                                 Color.accentColor.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.accentColor.opacity(0.16), radius: 12, x: 0, y: 5)
            )
        }
        .pressable()
    }

    // MARK: - 月历

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .pressable()

                Spacer()

                Text(DayText.monthTitle(monthAnchor))
                    .font(.headline)
                    .contentTransition(.numericText())

                Spacer()

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .pressable()
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
            .id(DayText.monthTitle(monthAnchor))
            .transition(.asymmetric(
                insertion: .move(edge: monthDirection > 0 ? .trailing : .leading)
                    .combined(with: .opacity),
                removal: .move(edge: monthDirection > 0 ? .leading : .trailing)
                    .combined(with: .opacity)))

            legend
        }
        .softCard(padding: 14)
        .clipped()
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
        .pressable()
    }

    private func dayNumberColor(thumb: UIImage?, holiday: HolidayInfo?) -> Color {
        if thumb != nil { return .white }
        if let h = holiday { return h.isOff ? .red : .orange }
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
                    Spacer()
                    Text("\(past.count) 年前")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                            if !item.entry.summary.isEmpty {
                                Text(item.entry.summary)
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
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .pressable()
                }
            }
            .softCard(padding: 14)
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
        guard let d = cal.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        monthDirection = delta
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            monthAnchor = d
        }
    }
}
