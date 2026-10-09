import Foundation
import LocalAuthentication
import SwiftUI

/// 应用锁：Face ID / Touch ID，失败可回退到设备密码。
/// 只读 UserDefaults 里的开关；不引入任何网络或第三方依赖。
@MainActor
final class AppLock: ObservableObject {

    static let enabledKey = "lock.enabled"

    /// 是否显示锁屏
    @Published private(set) var isLocked = false
    /// 认证过程中的提示文案
    @Published var errorText: String?

    private var authenticating = false

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// 这台设备支持的验证方式名称，用于文案
    var methodName: String {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { return "设备密码" }
        switch ctx.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "设备密码"
        }
    }

    /// 这台设备能不能用（没设密码就开不了）
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    init() {
        if UserDefaults.standard.bool(forKey: Self.enabledKey) {
            isLocked = true
        }
    }

    /// 进入后台时上锁
    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    /// 用户主动关掉开关时调用，避免被锁在外面
    func forceUnlock() {
        isLocked = false
        errorText = nil
    }

    func unlock() async {
        guard isLocked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }

        let ctx = LAContext()
        ctx.localizedFallbackTitle = "使用密码"
        ctx.localizedCancelTitle = "取消"

        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // 设备没设密码 / 没录 Face ID，不能把用户锁在外面
            errorText = "这台设备还没设置密码或 Face ID，应用锁已自动关闭"
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            isLocked = false
            return
        }

        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: "解锁「每日记录」")
            if ok {
                withAnimation(.easeOut(duration: 0.25)) {
                    isLocked = false
                }
                errorText = nil
            }
        } catch {
            let code = (error as NSError).code
            // 用户主动取消不算错误，安静地留在锁屏页
            if code != LAError.userCancel.rawValue && code != LAError.appCancel.rawValue {
                errorText = "验证没通过，再试一次"
            }
        }
    }
}

/// 锁屏遮罩：不透明，避免 App 切换器里露出内容
struct LockScreenView: View {
    @ObservedObject var lock: AppLock

    @State private var glow = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 108, height: 108)
                        .scaleEffect(glow ? 1.06 : 0.96)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 6) {
                    Text("每日记录")
                        .font(.title3).fontWeight(.bold)
                    Text("已锁定，需要 \(lock.methodName) 才能查看")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("解锁", systemImage: "faceid")
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 28)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                .pressable()

                if let errorText = lock.errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
            Task { await lock.unlock() }
        }
    }
}
