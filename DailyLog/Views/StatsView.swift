import SwiftUI

/// 记录统计：连续天数、热力图、心情分布、标签
struct StatsView: View {
    @EnvironmentObject private var store: EntryStore

    private let weeks = 26

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                streakCard.staggered(0)
                heatmapCard.staggered(1)
                moodCard.staggered(2)
                tagCard.staggered(3)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Theme.Background())
        .navigationTitle("记录统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 连续记录

    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                bigStat(value: "\(store.currentStreak)", unit: "天", title: "当前连续", tint: .orange)
                Divider().frame(height: 44)
                bigStat(value: "\(store.longestStreak)", unit: "天", title: "最长连续", tint: .pink)
                Divider().frame(height: 44)
                bigStat(value: "\(store.recordedDayCount)", unit: "天", title: "累计记录", tint: .accentColor)
            }

            HStack(spacing: 8) {
                Image(systemName: store.hasToday ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(store.hasToday ? Color.green : Color.secondary)
                Text(store.hasToday ? "今天已经记过了，保持住" : "今天还没写，别忘了")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .softCard(padding: 16)
    }

    private func bigStat(value: String, unit: String, title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 热力图

    private var heatmapCard: some View {
        let cols = store.heatmap(weeks: weeks)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("记录热力图")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("最近 \(weeks) 周")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(cols.enumerated()), id: \.offset) { ci, col in
                            VStack(spacing: 3) {
                                ForEach(Array(col.enumerated()), id: \.offset) { _, day in
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(color(for: day))
                                        .frame(width: 12, height: 12)
                                }
                            }
                            .id(ci)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    guard !cols.isEmpty else { return }
                    proxy.scrollTo(cols.count - 1, anchor: .trailing)
                }
            }

            HStack(spacing: 5) {
                Text("少")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(level: level))
                        .frame(width: 11, height: 11)
                }
                Text("多")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .softCard(padding: 14)
    }

    private func color(for day: Date?) -> Color {
        guard let day else { return .clear }
        return color(level: store.level(for: day))
    }

    private func color(level: Int) -> Color {
        switch level {
        case 0:  return Color(.tertiarySystemFill)
        case 1:  return Color.accentColor.opacity(0.28)
        case 2:  return Color.accentColor.opacity(0.50)
        case 3:  return Color.accentColor.opacity(0.74)
        default: return Color.accentColor
        }
    }

    // MARK: - 心情分布

    @ViewBuilder
    private var moodCard: some View {
        let counts = store.moodCounts()

        if !counts.isEmpty {
            let peak = max(1, counts.first?.count ?? 1)

            VStack(alignment: .leading, spacing: 12) {
                Text("心情分布")
                    .font(.subheadline).fontWeight(.semibold)

                ForEach(Array(counts.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Text(item.mood)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.tertiarySystemFill))
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.62))
                                    .frame(width: max(8, geo.size.width * CGFloat(item.count) / CGFloat(peak)))
                            }
                        }
                        .frame(height: 12)

                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .softCard(padding: 14)
        }
    }

    // MARK: - 标签

    @ViewBuilder
    private var tagCard: some View {
        let tags = store.allTags()

        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("标签")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text("\(tags.count) 个")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                FlowLayout(spacing: 7) {
                    ForEach(Array(tags.prefix(30).enumerated()), id: \.element) { index, tag in
                        TagChip(text: "#\(tag)", selected: index < 5)
                    }
                }
            }
            .softCard(padding: 14)
        }
    }
}
