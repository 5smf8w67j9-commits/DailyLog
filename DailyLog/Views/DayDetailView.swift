import SwiftUI
import PhotosUI

struct DayDetailView: View {
    @EnvironmentObject private var store: EntryStore

    @State private var date: Date
    /// 若进入时看的就是"今天"，跨天时自动跟随到新的一天
    @State private var followsToday: Bool
    @State private var text: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var didLoad = false
    @State private var importing = false

    @FocusState private var focused: Bool

    init(date: Date) {
        _date = State(initialValue: date)
        _followsToday = State(initialValue: Calendar.current.isDateInToday(date))
    }

    private var entry: Entry { store.entry(for: date) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                imagesSection
                editor
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(DayText.short(date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focused = false }
            }
        }
        .onAppear {
            if !didLoad {
                text = store.entry(for: date).text
                didLoad = true
            }
        }
        .onChange(of: text) { newValue in
            guard didLoad else { return }
            store.setText(newValue, for: date)
        }
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .onChange(of: store.todayKey) { _ in
            // 白天跨天：若当前停在"今天"的页面，自动切到新的一天，可以重新记录
            if followsToday {
                date = Date()
                text = store.entry(for: date).text
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DayText.full(date))
                .font(.title2).fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Label("\(entry.imageFiles.count) 张图片", systemImage: "photo.on.rectangle")
                Label("\(entry.text.count) 字", systemImage: "text.alignleft")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 图片区

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("图片")
                .font(.subheadline).fontWeight(.semibold)

            let names = entry.imageFiles
            if !names.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        if let img = store.image(named: name) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 112)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        store.removeImage(named: name, for: date)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 19))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(Color.white, Color.black.opacity(0.45))
                                            .padding(6)
                                    }
                                }
                        }
                    }
                }
            }

            PhotosPicker(selection: $pickerItems,
                         maxSelectionCount: 9,
                         matching: .images,
                         photoLibrary: .shared()) {
                HStack(spacing: 6) {
                    if importing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(importing ? "正在导入…" : "添加图片")
                }
                .font(.subheadline).fontWeight(.medium)
                .padding(.vertical, 11)
                .padding(.horizontal, 18)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
            }
            .disabled(importing)
        }
    }

    // MARK: - 文字区

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天的新鲜事")
                .font(.subheadline).fontWeight(.semibold)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("写点什么…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - 导入图片

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        importing = true
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                store.addImage(data, for: date)
            }
        }
        pickerItems = []
        importing = false
    }
}
