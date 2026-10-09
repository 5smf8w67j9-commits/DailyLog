import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: EntryStore
    @ObservedObject var checker: UpdateChecker
    @StateObject private var notif = NotificationManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                reminderSection

                Section("数据") {
                    statRow("已记录", "\(store.recordedDayCount) 天")
                    statRow("累计字数", "\(store.totalWordCount) 字")
                    statRow("图片", "\(store.totalImageCount) 张")
                }

                versionSection

                Section {
                    Text("所有记录只保存在这台手机上，不上传、不联网同步。卸载 App 会一并删除，重要内容记得导出。")
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
