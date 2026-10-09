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

    @State private var addingTag = false
    @State private var newTag = ""
    @State private var showCamera = false

    /// 全屏看图
    @State private var viewerStart: String?
    @State private var showViewer = false

    /// 语音转文字
    @StateObject private var speech = SpeechRecognizer()

    /// 当前正在编辑的输入位（用于键盘弹起时把对应区域滚进可见范围）
    private enum Field: Hashable { case tag, editor }
    @FocusState private var focus: Field?

    private static let editorID = "detail.editor"
    private static let tagsID = "detail.tags"

    private static let moods = ["😄", "🙂", "😐", "😔", "😤", "😭"]
    private static let weathers = ["☀️", "⛅️", "☁️", "🌧️", "❄️", "🌫️"]

    init(date: Date) {
        _date = State(initialValue: date)
        _followsToday = State(initialValue: Calendar.current.isDateInToday(date))
    }

    private var entry: Entry { store.entry(for: date) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header.staggered(0)
                    moodWeatherSection.staggered(1)
                    tagsSection.staggered(2)
                    imagesSection.staggered(3)
                    editor.staggered(4)
                }
                .padding(16)
                // 键盘遮挡时留出一点余量，保证最后一块内容能完整滚上来
                .padding(.bottom, focus == nil ? 0 : 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.Background())
            .navigationTitle(DayText.short(date))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: focus) { field in
                guard let field else { return }
                scrollToField(field, proxy: proxy)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focus = nil }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                store.addImage(image, for: date)
            }
        }
        .fullScreenCover(isPresented: $showViewer) {
            PhotoViewerSheet(store: store, date: date, start: viewerStart)
        }
        .onDisappear {
            speech.stop()
            store.flush()
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    date = Date()
                }
                text = store.entry(for: date).text
            }
        }
    }

    // MARK: - 键盘避让

    /// 键盘弹起时，等布局稳定后把正在编辑的区域滚到底部可见处
    private func scrollToField(_ field: Field, proxy: ScrollViewProxy) {
        let target = (field == .editor) ? Self.editorID : Self.tagsID
        // 键盘动画大约 0.25s，稍微等一会儿再滚，避免滚到一半被顶回去
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.28)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        let holiday = ChineseHolidays.info(for: date)
        return VStack(alignment: .leading, spacing: 10) {
            Text(DayText.full(date))
                .font(.title2).fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.numericText())

            HStack(spacing: 8) {
                if let holiday {
                    HStack(spacing: 5) {
                        Image(systemName: holiday.isOff ? "flag.fill" : "briefcase.fill")
                            .font(.system(size: 11))
                        Text(holiday.isOff ? "\(holiday.name) · 放假" : "\(holiday.name) · 上班")
                            .font(.caption).fontWeight(.semibold)
                    }
                    .foregroundStyle(holiday.isOff ? Color.red : Color.orange)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background((holiday.isOff ? Color.red : Color.orange).opacity(0.12))
                    .clipShape(Capsule())
                }

                Spacer()

                HStack(spacing: 10) {
                    Label("\(entry.imageFiles.count)", systemImage: "photo.on.rectangle")
                    Label("\(entry.text.count)", systemImage: "text.alignleft")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 心情 / 天气

    private var moodWeatherSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            emojiRow(title: "心情",
                     items: Self.moods,
                     selected: entry.mood) { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    store.setMood(value, for: date)
                }
            }
            emojiRow(title: "天气",
                     items: Self.weathers,
                     selected: entry.weather) { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    store.setWeather(value, for: date)
                }
            }
        }
        .softCard(padding: 14, radius: 16)
    }

    @ViewBuilder
    private func emojiRow(title: String,
                          items: [String],
                          selected: String?,
                          onPick: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
            HStack(spacing: 7) {
                ForEach(items, id: \.self) { item in
                    let isOn = (selected == item)
                    Button {
                        onPick(isOn ? nil : item)
                    } label: {
                        Text(item)
                            .font(.system(size: 22))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(isOn ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(isOn ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .scaleEffect(isOn ? 1.06 : 1)
                    }
                    .pressable()
                }
            }
        }
    }

    // MARK: - 标签

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("标签")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        addingTag.toggle()
                        if !addingTag { newTag = "" }
                    }
                    if addingTag {
                        // 输入框是刚插进来的，等一帧再聚焦，否则聚焦不上
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focus = .tag }
                    } else {
                        focus = nil
                    }
                } label: {
                    Image(systemName: addingTag ? "xmark.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            if !entry.tags.isEmpty {
                FlowLayout(spacing: 7) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.setTags(entry.tags.filter { $0 != tag }, for: date)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.18))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                        }
                        .pressable()
                    }
                }
                .transition(.opacity)
            }

            if addingTag {
                HStack(spacing: 8) {
                    TextField("新标签，例如：旅行", text: $newTag)
                        .focused($focus, equals: .tag)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { commitTag() }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("添加") { commitTag() }
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(Color.accentColor)
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            let suggestions = store.allTags()
                .filter { !entry.tags.contains($0) }
                .prefix(10)
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(suggestions), id: \.self) { tag in
                            Button {
                                addTag(tag)
                            } label: {
                                TagChip(text: "+ #\(tag)")
                            }
                            .pressable()
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .softCard(padding: 14, radius: 16)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: entry.tags)
        .id(Self.tagsID)
    }

    private func commitTag() {
        let value = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        addTag(value)
        newTag = ""
    }

    private func addTag(_ tag: String) {
        guard !entry.tags.contains(tag) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.setTags(entry.tags + [tag], for: date)
            addingTag = false
            newTag = ""
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
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewerStart = name
                                    showViewer = true
                                }
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            store.removeImage(named: name, for: date)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 19))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(Color.white, Color.black.opacity(0.45))
                                            .padding(6)
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(Circle().fill(Color.black.opacity(0.32)))
                                        .padding(6)
                                }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItems,
                             maxSelectionCount: 9,
                             matching: .images,
                             photoLibrary: .shared()) {
                    HStack(spacing: 6) {
                        if importing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        Text(importing ? "正在导入…" : "相册")
                    }
                    .font(.subheadline).fontWeight(.medium)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 18)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }
                .disabled(importing)

                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("拍照")
                    }
                    .font(.subheadline).fontWeight(.medium)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 18)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }
                .pressable()

                Spacer()
            }
        }
        .softCard(padding: 14, radius: 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: entry.imageFiles)
    }

    // MARK: - 文字区

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("今天的新鲜事")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                voiceButton
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("写点什么…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($focus, equals: .editor)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(focus == .editor ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: focus)

            if speech.isRecording {
                recordingBar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let error = speech.errorText {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .softCard(padding: 14, radius: 16)
        .id(Self.editorID)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: speech.isRecording)
    }

    private var voiceButton: some View {
        Button {
            let base = text
            Task {
                await speech.toggle(baseText: base) { newValue in
                    text = newValue
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(speech.isRecording ? "停止" : "语音输入")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(speech.isRecording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.12))
            .foregroundStyle(speech.isRecording ? Color.red : Color.accentColor)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(speech.isRecording ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .pressable()
    }

    private var recordingBar: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)

            Text("正在听…说完点「停止」")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 2.5) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Color.accentColor.opacity(speech.level > CGFloat(index) / 5 ? 0.9 : 0.18))
                        .frame(width: 3, height: CGFloat(7 + index * 3))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
