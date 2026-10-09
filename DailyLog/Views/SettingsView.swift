import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: EntryStore
    @ObservedObject var checker: UpdateChecker
    @StateObject private var notif = NotificationManager()
    @Environment(\.dismiss) private var dismiss

    // 外观
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    // 备份 / 恢复
    @State private var backupBusy = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showImporter = false
    @State private var resultMessage = ""
    @State private var showResult = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                reminderSection

                Section("数据") {
                    statRow("已记录", "\(store.recordedDayCount) 天")
                    statRow("累计字数", "\(store.totalWordCount) 字")
                    statRow("图片", "\(store.totalImageCount) 张")
                }

                backupSection
                versionSection

                Section {
                    Text("记录默认只存在这台手机上。换手机前先导出一份备份（可以存到 iCloud 云盘、微信或电脑），在新手机上用「从备份恢复」导入，就会自动合并回来。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await notif.refreshAuthorization() }
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    BackupShareSheet(url: shareURL,
                                     days: store.recordedDayCount,
                                     words: store.totalWordCount,
                                     images: store.totalImageCount)
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json, .data],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .alert("恢复完成", isPresented: $showResult) {
                Button("好", role: .cancel) { }
            } message: {
                Text(resultMessage)
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - 外观

    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            Picker("外观", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("外观")
        } footer: {
            Text("只影响「每日记录」自己，不会改动系统或其他 App 的深色设置。")
        }
    }

    // MARK: - 每日提醒

    @ViewBuilder
    private var reminderSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { notif.enabled },
                set: { on in
                    Task { on ? await notif.enable() : await notif.disable() }
                }
            )) {
                Label("每日提醒", systemImage: "bell.badge")
            }

            if notif.enabled {
                DatePicker("提醒时间",
                           selection: reminderTime,
                           displayedComponents: .hourAndMinute)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } header: {
            Text("提醒")
        } footer: {
            if let error = notif.lastError {
                Text(error).foregroundStyle(.orange)
            } else if notif.enabled {
                Text("每天 \(notif.timeText) 提醒你写今天的记录")
            } else {
                Text("到点提醒你写今天的新鲜事")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: notif.enabled)
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = notif.hour
                c.minute = notif.minute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                notif.hour = c.hour ?? 21
                notif.minute = c.minute ?? 0
                Task { await notif.apply() }
            }
        )
    }

    // MARK: - 备份 / 恢复

    @ViewBuilder
    private var backupSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                HStack {
                    Label("导出备份文件", systemImage: "square.and.arrow.up.on.square")
                    Spacer()
                    if backupBusy {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(backupBusy)

            Button {
                showImporter = true
            } label: {
                Label("从备份恢复", systemImage: "square.and.arrow.down.on.square")
            }
        } header: {
            Text("备份与恢复")
        } footer: {
            Text("备份是一个文件，包含全部文字和图片。导出时可以选「存储到文件」放进 iCloud 云盘，换手机后再导入。同一天的记录会按修改时间取较新的那份，不会覆盖你刚写的内容。")
        }
    }

    private func exportBackup() {
        guard store.recordedDayCount > 0 else {
            errorMessage = "还没有任何记录，先写几天再来备份吧。"
            showError = true
            return
        }
        backupBusy = true
        Task { @MainActor in
            defer { backupBusy = false }
            do {
                let data = try store.makeBackupData()
                let name = "每日记录备份-\(DayKey.key(for: Date())).json"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                shareURL = url
                showShare = true
            } catch {
                errorMessage = "导出失败：\(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = "选择文件失败：\(error.localizedDescription)"
            showError = true

        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                let summary = try store.peekBackup(data)
                let outcome = try store.restoreBackup(data)
                resultMessage = """
                备份里共有 \(summary.days) 天记录、\(summary.words) 字、\(summary.images) 张图。
                本次新增 \(outcome.added) 天，更新 \(outcome.updated) 天，补回 \(outcome.images) 张图片。
                """
                showResult = true
            } catch {
                errorMessage = "恢复失败：\(error.localizedDescription)"
                showError = true
            }
        }
    }

    // MARK: - 版本

    @ViewBuilder
    private var versionSection: some View {
        Section("版本") {
            statRow("当前版本", "\(checker.currentVersion)（构建 \(checker.currentBuild)）")

            Button {
                Task { await checker.check() }
            } label: {
                HStack {
                    Text("检查更新")
                    Spacer()
                    if checker.status == .checking {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(checker.status == .checking)

            switch checker.status {
            case .upToDate:
                Label("已是最新版本", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)

            case .available(let remote):
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(remote.version)（构建 \(remote.build)）",
                          systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline).fontWeight(.semibold)

                    if let notes = remote.notes, !notes.isEmpty {
                        Text(notes).font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("下载后需重新签名安装")
                        .font(.caption).foregroundStyle(.secondary)

                    Link(destination: UpdateChecker.releasesPage) {
                        Text("去下载")
                            .font(.subheadline).fontWeight(.medium)
                            .padding(.vertical, 7).padding(.horizontal, 16)
                            .background(Color.accentColor.opacity(0.14))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 2)

            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.footnote)

            default:
                EmptyView()
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }
}

/// 备份生成后的分享面板
struct BackupShareSheet: View {
    let url: URL
    let days: Int
    let words: Int
    let images: Int

    @Environment(\.dismiss) private var dismiss

    private var sizeText: String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attrs?[.size] as? NSNumber)?.doubleValue ?? 0
        let mb = bytes / 1024 / 1024
        return mb >= 1 ? String(format: "%.1f MB", mb) : String(format: "%.0f KB", mb * 1024)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.green)
                    .padding(.top, 26)

                Text("备份已生成")
                    .font(.headline)

                Text("\(days) 天记录 · \(words) 字 · \(images) 张图 · \(sizeText)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                ShareLink(item: url) {
                    Label("分享 / 存储到文件", systemImage: "square.and.arrow.up")
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                Text("想放进 iCloud 云盘的话，在分享面板里选「存储到文件」→「iCloud 云盘」。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("导出备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(360)])
    }
}
