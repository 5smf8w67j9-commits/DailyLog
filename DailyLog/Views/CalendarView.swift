import SwiftUI
import UIKit

struct CalendarView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var router: AppRouter

    @StateObject private var checker = UpdateChecker()
    @State private var monthAnchor: Date = Date()
    @State private var monthDirection: Int = 1

    @State private var showSettings = false
    @State private var showSearch = false

    @State private var exportImage: UIImage?
    @State private var showExport = false
    @State private var exporting = false

    /// 没有内容可分享时的提示
    @State private var showEmptyAlert = false
    @State private var emptyAlertText = ""

    // MARK: 长按相关

    /// 快速记一句
    @State private var quickNote: DayTarget?
    /// 单天导出
    @State private var dayExport: DayExportTarget?
    /// 待确认清空的那天
    @State private var pendingClear: DayTarget?
    @State private var showClearAlert = false
    /// 月份箭头长按连续翻月
    @State private var holdTask: Task<Void, Never>?
    @State private var holdCancelled = false
    /// 轻提示
    @State private var toastText: String?

    private let cal = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(spacing: 18) {
                    todayCard.staggered(0)
                    monthCard.staggered(1)
                    statsBar.staggered(2)
                    onThisDayCard.staggered(3)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.Background())
            .toast($toastText)
            .navigationTitle("每日记录")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .day(let date):
                    DayDetailView(date: date)
                case .stats:
                    StatsView()
                }
            }
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
            .sheet(item: $quickNote) { target in
                QuickNoteSheet(date: target.date)
                    .environmentObject(store)
            }
            .sheet(item: $dayExport) { target in
                DayExportSheet(image: target.image, date: target.date)
            }
            .alert("还没有内容可以分享", isPresented: $showEmptyAlert) {
                Button("好", role: .cancel) { }
            } message: {
                Text(emptyAlertText)
            }
            .alert("清空这天的记录？", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) { pendingClear = nil }
                Button("清空", role: .destructive) { confirmClear() }
            } message: {
                Text("文字、图片、心情、标签都会删掉，无法恢复。")
            }
            .task {
                await checker.check(silent: true)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: checker.hasUpdate)
        }
    }

    // MARK: - 数据包装

    private struct DayTarget: Identifiable {
        var id: String { DayKey.key(for: date) }
        let date: Date
    }

    private struct DayExportTarget: Identifiable {
        var id: String { DayKey.key(for: date) }
        let date: Date
        let image: UIImage
    }

    // MARK: - 导出

    private func exportMonth() {
        guard !exporting else { return }

        // 先看看这个月到底有没有东西可导出，没有就明确提示，而不是"闪一下"没反应
        guard !store.entries(in: monthAnchor).isEmpty else {
            emptyAlertText = store.recordedDayCount == 0
                ? "你还没有写过任何记录。先写下今天的新鲜事，再来生成月历长图吧。"
                : "\(DayText.monthTitle(monthAnchor)) 还没有记录，先去写点什么吧。"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showEmptyAlert = true
            }
            return
        }

        exporting = true
        Haptics.bump()
        let month = monthAnchor
        Task { @MainActor in
            let image = Exporter.monthImage(month: month, store: store)
            exporting = false
            if let image {
                exportImage = image
                showExport = true
            } else {
                emptyAlertText = "长图生成失败了，换个时间再试试。"
                showEmptyAlert = true
            }
        }
    }

    private func exportDay(_ date: Date) {
        guard !store.entry(for: date).isEmpty else {
            Toast.show("这天还没有记录", into: $toastText)
            return
        }
        Haptics.bump()
        Task { @MainActor in
            if let image = Exporter.dayImage(date: date, store: store) {
                dayExport = DayExportTarget(date: date, image: image)
            } else {
                Toast.show("长图生成失败了", into: $toastText)
            }
        }
    }

    // MARK: - 复制 / 清空

    private func copyDay(_ date: Date) {
        let entry = store.entry(for: date)
        guard !entry.isEmpty else {
            Toast.show("这天还没有记录", into: $toastText)
            return
        }

        var lines: [String] = [DayText.full(date)]
        if let mood = entry.mood {
            lines.append("心情：\(mood) \(MoodCatalog.moodName(mood))")
        }
        if let weather = entry.weather {
            lines.append("天气：\(weather) \(MoodCatalog.weatherName(weather))")
        }
        if !entry.summary.isEmpty {
            lines.append("")
            lines.append(entry.summary)
        }
        if !entry.tags.isEmpty {
            lines.append("")
            lines.append(entry.tags.map { "#\($0)" }.joined(separator: " "))
        }

        UIPasteboard.general.string = lines.joined(separator: "\n")
        Haptics.success()
        Toast.show("已复制 \(DayText.short(date)) 的内容", into: $toastText)
    }

    private func confirmClear() {
        guard let target = pendingClear else { return }
        store.clearDay(target.date)
        Haptics.warning()
        Toast.show("已清空 \(DayText.short(target.date))", into: $toastText)
        pendingClear = nil
    }

    // MARK: - 今日卡片

    private var todayCard: some View {
        let today = Date()
        let entry = store.entry(for: today)
        let holiday = ChineseHolidays.info(for: today)

        return NavigationLink(value: Route.day(today)) {
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
        .contextMenu {
            todayMenu(today, entry: entry)
        } preview: {
            DayPeekCard(date: today, store: store)
        }
    }

    @ViewBuilder
    private func todayMenu(_ today: Date, entry: Entry) -> some View {
        let moodTitle = entry.mood.map { "心情：\($0)" } ?? "设置心情"

        Button {
            quickNote = DayTarget(date: today)
        } label: {
            Label("快速记一句", systemImage: "square.and.pencil")
        }

        Button {
            router.push(.day(today))
        } label: {
            Label(entry.isEmpty ? "写今天的新鲜事" : "继续写", systemImage: "pencil.line")
        }

        Menu {
            ForEach(MoodCatalog.moods, id: \.self) { mood in
                Button {
                    store.setMood(mood, for: today)
                    Haptics.pick()
                } label: {
                    Text("\(mood)  \(MoodCatalog.moodName(mood))")
                }
            }
            if entry.mood != nil {
                Divider()
                Button(role: .destructive) {
                    store.setMood(nil, for: today)
                    Haptics.pick()
                } label: {
                    Label("清除心情", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label(moodTitle, systemImage: "face.smiling")
        }

        Divider()

        Button {
            copyDay(today)
        } label: {
            Label("复制今天的内容", systemImage: "doc.on.doc")
        }
        .disabled(entry.isEmpty)

        Button {
            exportDay(today)
        } label: {
            Label("导出今天为图片", systemImage: "photo.on.rectangle")
        }
        .disabled(entry.isEmpty)

        Divider()

        Button(role: .destructive) {
            pendingClear = DayTarget(date: today)
            showClearAlert = true
        } label: {
            Label("清空今天", systemImage: "trash")
        }
        .disabled(entry.isEmpty)
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
                .simultaneousGesture(holdGesture(-1))

                Spacer()

                Text(DayText.monthTitle(monthAnchor))
                    .font(.headline)
                    .contentTransition(.numericText())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.35) {
                        goToThisMonth()
                    }

                Spacer()

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .pressable()
                .simultaneousGesture(holdGesture(1))
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

        NavigationLink(value: Route.day(date)) {
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
        .contextMenu {
            if has {
                Button {
                    router.push(.day(date))
                } label: {
                    Label("打开这天", systemImage: "arrow.up.forward.square")
                }
                Button {
                    copyDay(date)
                } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                }
                Button {
                    exportDay(date)
                } label: {
                    Label("导出这天为图片", systemImage: "photo.on.rectangle")
                }
                Divider()
                Button(role: .destructive) {
                    pendingClear = DayTarget(date: date)
                    showClearAlert = true
                } label: {
                    Label("清空这天", systemImage: "trash")
                }
            } else {
                Button {
                    router.push(.day(date))
                } label: {
                    Label("补写这天", systemImage: "square.and.pencil")
                }
            }
        } preview: {
            DayPeekCard(date: date, store: store)
        }
    }

    private func dayNumberColor(thumb: UIImage?, holiday: HolidayInfo?) -> Color {
        if thumb != nil { return .white }
        if let h = holiday { return h.isOff ? .red : .orange }
        return .primary
    }

    // MARK: - 统计条

    private var statsBar: some View {
        NavigationLink(value: Route.stats) {
            HStack(spacing: 0) {
                statItem(value: "\(store.currentStreak)", unit: "天", title: "连续记录",
                         icon: "flame.fill", tint: .orange)
                statDivider
                statItem(value: "\(store.recordedDayCount)", unit: "天", title: "累计记录",
                         icon: "calendar", tint: .accentColor)
                statDivider
                statItem(value: "\(store.totalImageCount)", unit: "张", title: "照片",
                         icon: "photo.fill", tint: .green)
            }
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .softCard(padding: 0, radius: 18)
        }
        .pressable()
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.45))
            .frame(width: 0.5, height: 34)
    }

    private func statItem(value: String,
                          unit: String,
                          title: String,
                          icon: String,
                          tint: Color) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                    let itemDate = DayKey.date(from: item.entry.dateKey) ?? Date()

                    NavigationLink(value: Route.day(itemDate)) {
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
                    .contextMenu {
                        Button {
                            router.push(.day(itemDate))
                        } label: {
                            Label("打开这天", systemImage: "arrow.up.forward.square")
                        }
                        Button {
                            copyDay(itemDate)
                        } label: {
                            Label("复制内容", systemImage: "doc.on.doc")
                        }
                        Button {
                            exportDay(itemDate)
                        } label: {
                            Label("导出这天为图片", systemImage: "photo.on.rectangle")
                        }
                    } preview: {
                        DayPeekCard(date: itemDate, store: store)
                    }
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

    /// 长按月标题 → 一键回到本月
    private func goToThisMonth() {
        let today = Date()
        guard !cal.isDate(monthAnchor, equalTo: today, toGranularity: .month) else {
            Toast.show("已经在当月了", into: $toastText)
            return
        }
        Haptics.snap()
        let target = cal.dateInterval(of: .month, for: today)?.start ?? today
        monthDirection = target > monthAnchor ? 1 : -1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            monthAnchor = today
        }
        Toast.show("回到本月", into: $toastText)
    }

    // MARK: - 月份箭头长按连续翻月

    private func holdGesture(_ delta: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let moved = abs(value.translation.width) > 14 || abs(value.translation.height) > 14
                if moved {
                    cancelHold()
                    holdCancelled = true
                } else if !holdCancelled && holdTask == nil {
                    beginHold(delta)
                }
            }
            .onEnded { _ in
                cancelHold()
                holdCancelled = false
            }
    }

    private func beginHold(_ delta: Int) {
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            // 按满 0.32 秒才算长按
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            Haptics.snap()
            while !Task.isCancelled {
                shiftMonth(delta)
                try? await Task.sleep(nanoseconds: 110_000_000)
            }
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
    }
}
