import Foundation
import SwiftUI

/// 远端版本清单（由 GitHub Actions 每次构建自动生成）
struct RemoteVersion: Codable, Equatable {
    let version: String
    let build: Int
    let notes: String?
    let ipa: String?
    let date: String?
}

/// 应用内「检查更新」
///
/// 原理：每次推送代码，GitHub Actions 会重新构建 ipa 并发布到 Releases（固定 tag = latest），
/// 同时生成一份 version.json。App 只需拉取这份清单，比对构建号即可知道有没有新版本。
@MainActor
final class UpdateChecker: ObservableObject {

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(RemoteVersion)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    /// 版本清单地址（Releases 固定 tag）
    static let feedURL = URL(string:
        "https://github.com/5smf8w67j9-commits/DailyLog/releases/download/latest/version.json")!

    /// 下载页（用浏览器打开，无需登录 GitHub）
    static let releasesPage = URL(string:
        "https://github.com/5smf8w67j9-commits/DailyLog/releases/latest")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var currentBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
    }

    var hasUpdate: Bool {
        if case .available = status { return true }
        return false
    }

    /// silent = true 时用于启动后的静默检查，不打扰用户
    func check(silent: Bool = false) async {
        if !silent { status = .checking }
        do {
            var request = URLRequest(url: Self.feedURL)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let remote = try JSONDecoder().decode(RemoteVersion.self, from: data)

            if remote.build > currentBuild {
                status = .available(remote)
            } else {
                status = .upToDate
            }
        } catch {
            if !silent {
                status = .failed("检查失败，请检查网络后重试")
            }
        }
    }
}
