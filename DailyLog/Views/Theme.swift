import SwiftUI

/// 统一的视觉风格
enum Theme {

    /// 卡片圆角
    static let cardRadius: CGFloat = 20

    /// 页面背景：系统底色 + 顶部一层主题色晕染
    struct Background: View {
        var body: some View {
            ZStack {
                Color(.systemGroupedBackground)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.16),
                             Color.accentColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .ignoresSafeArea()
        }
    }

    /// 柔和卡片
    struct Card: ViewModifier {
        var padding: CGFloat = 16
        var radius: CGFloat = Theme.cardRadius

        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                )
        }
    }
}

extension View {
    func softCard(padding: CGFloat = 16, radius: CGFloat = Theme.cardRadius) -> some View {
        modifier(Theme.Card(padding: padding, radius: radius))
    }

    /// 轻点时的回弹 + 触觉反馈
    func pressable(haptic: Bool = true) -> some View {
        buttonStyle(PressableButtonStyle(haptic: haptic))
    }

    /// 顶部浮出的小提示
    func toast(_ text: Binding<String?>) -> some View {
        modifier(ToastModifier(text: text))
    }
}

struct PressableButtonStyle: ButtonStyle {
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed && haptic {
                    Haptics.tap()
                }
            }
    }
}

/// 一闪而过的小提示条
struct ToastModifier: ViewModifier {
    @Binding var text: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let text {
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.black.opacity(0.78))
                        .clipShape(Capsule())
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: text)
    }
}

/// 统一的提示条触发方式
@MainActor
enum Toast {
    static func show(_ message: String, into binding: Binding<String?>) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            binding.wrappedValue = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            if binding.wrappedValue == message {
                withAnimation(.easeOut(duration: 0.25)) {
                    binding.wrappedValue = nil
                }
            }
        }
    }
}

/// 小胶囊标签
struct TagChip: View {
    let text: String
    var selected: Bool = false
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? tint.opacity(0.20) : Color(.tertiarySystemFill))
            .foregroundStyle(selected ? tint : Color.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(selected ? tint.opacity(0.55) : Color.clear, lineWidth: 1)
            )
    }
}

/// 页面出现的错落淡入
struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)
                    .delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    func staggered(_ index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

/// 自动换行的标签布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let width = maxWidth == .infinity ? max(0, x - spacing) : maxWidth
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
