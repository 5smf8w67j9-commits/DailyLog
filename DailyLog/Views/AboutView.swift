import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var store: EntryStore
    @ObservedObject var checker: UpdateChecker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("版本") {
                    HStack {
                        Text("当前版本")
                        Spacer()
                        Text("\(checker.currentVersion)（构建 \(checker.currentBuild)）")
                            .foregroundStyle(.secondary)
                    }
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
                }

                statusSection

                Section("记录") {
                    HStack {
                        Text("已记录")
                        Spacer()
                        Text("\(store.entries.count) 天").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("数据全部保存在本机，不上传、不联网同步。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch checker.status {
        case .upToDate:
            Section {
                Label("已是最新版本", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }

        case .available(let remote):
            Section("发现新版本") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(remote.version)（构建 \(remote.build)）",
                          systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline).fontWeight(.semibold)

                    if let notes = remote.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("下载后需重新签名安装")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(destination: UpdateChecker.releasesPage) {
                        Text("去下载")
                            .font(.subheadline).fontWeight(.medium)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 16)
                            .background(Color.accentColor.opacity(0.14))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 2)
            }

        case .failed(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }

        default:
            EmptyView()
        }
    }
}
