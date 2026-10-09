import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: EntryStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var selectedTag: String?
    @FocusState private var focused: Bool

    private var results: [Entry] {
        store.search(query, tag: selectedTag)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchField
                        .staggered(0)

                    let tags = store.allTags()
                    if !tags.isEmpty {
                        tagRow(tags)
                            .staggered(1)
                    }

                    resultsSection
                        .staggered(2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.Background())
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜文字或标签…", text: $query)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { query = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: query.isEmpty)
    }

    // MARK: - 标签筛选

    private func tagRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedTag = nil }
                } label: {
                    TagChip(text: "全部", selected: selectedTag == nil)
                }
                .pressable()

                ForEach(tags, id: \.self) { tag in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTag = (selectedTag == tag) ? nil : tag
                        }
                    } label: {
                        TagChip(text: "#\(tag)", selected: selectedTag == tag)
                    }
                    .pressable()
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    // MARK: - 结果

    @ViewBuilder
    private var resultsSection: some View {
        let list = results

        if list.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text(query.isEmpty ? "还没有任何记录" : "没有找到相关内容")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            HStack {
                Text("\(list.count) 条记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            LazyVStack(spacing: 10) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                    if let date = DayKey.date(from: entry.dateKey) {
                        NavigationLink {
                            DayDetailView(date: date)
                        } label: {
                            resultRow(entry)
                        }
                        .pressable()
                        .staggered(min(index, 8))
                    }
                }
            }
        }
    }

    private func resultRow(_ entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 3) {
                if let date = DayKey.date(from: entry.dateKey) {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text(shortMonth(date))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    if let mood = entry.mood { Text(mood).font(.system(size: 13)) }
                    if let weather = entry.weather { Text(weather).font(.system(size: 13)) }
                    Spacer(minLength: 0)
                }
                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if !entry.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            if let name = entry.imageFiles.first, let img = store.image(named: name) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(padding: 12, radius: 16)
    }

    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"
        return f.string(from: date)
    }
}
