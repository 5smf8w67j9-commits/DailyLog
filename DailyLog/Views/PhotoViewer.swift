import SwiftUI
import Photos
import UIKit

/// 全屏看图：左右翻页 + 双指缩放 + 拖拽 + 保存到相册 / 分享 / 删除
struct PhotoViewerSheet: View {
    @ObservedObject var store: EntryStore
    let date: Date

    @State private var current: String?
    @State private var toast: String?
    @State private var errorText: String?
    @Environment(\.dismiss) private var dismiss

    init(store: EntryStore, date: Date, start: String?) {
        _store = ObservedObject(wrappedValue: store)
        self.date = date
        _current = State(initialValue: start)
    }

    /// 直接读 store，删除后列表会自动跟着变
    private var names: [String] { store.entry(for: date).imageFiles }

    private var index: Int {
        guard let current, let i = names.firstIndex(of: current) else { return 0 }
        return i
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $current) {
                ForEach(names, id: \.self) { name in
                    ZoomableImage(image: store.image(named: name))
                        .tag(Optional(name))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            if let current, names.contains(current) { return }
            current = names.first
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Capsule())
                    .padding(.top, 96)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("好", role: .cancel) { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: - 顶栏 / 底栏

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }

            Spacer()

            if names.count > 1 {
                Text("\(index + 1) / \(names.count)")
                    .font(.footnote).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var bottomBar: some View {
        HStack(spacing: 34) {
            barButton(title: "保存", icon: "square.and.arrow.down") { saveToLibrary() }
            barButton(title: "分享", icon: "square.and.arrow.up") { share() }
            barButton(title: "删除", icon: "trash", tint: .red) { deleteCurrent() }
        }
        .padding(.bottom, 34)
        .padding(.top, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func barButton(title: String,
                           icon: String,
                           tint: Color = .white,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(tint)
            .frame(width: 62)
        }
    }

    // MARK: - 动作

    private func saveToLibrary() {
        guard let name = current, let image = store.image(named: name) else { return }
        PhotoActions.saveToLibrary(image) { result in
            switch result {
            case .success:
                showToast("已保存到相册")
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
    }

    private func share() {
        guard let name = current, let image = store.image(named: name) else { return }
        if !PhotoActions.share(image, filename: "每日记录-\(DayKey.key(for: date))-\(index + 1).jpg") {
            errorText = "导出图片失败"
        }
    }

    private func deleteCurrent() {
        guard let name = current, let i = names.firstIndex(of: name) else { return }

        // 先算好删完要停在哪张
        let next: String? = names.count > 1 ? names[i == names.count - 1 ? i - 1 : i + 1] : nil

        withAnimation(.easeOut(duration: 0.2)) {
            store.removeImage(named: name, for: date)
        }

        if let next {
            current = next
        } else {
            dismiss()
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }
}

/// 可缩放 / 可拖拽的单张图片
struct ZoomableImage: View {
    let image: UIImage?

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let maxScale: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 34))
                        Text("图片找不到了")
                            .font(.footnote)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, 1), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1.01 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                reset()
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height)
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    if scale > 1 {
                        reset()
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
        }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
