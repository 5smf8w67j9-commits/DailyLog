import SwiftUI

/// 长按今日卡片 →「快速记一句」：不用进详情页，写一句就追加到当天
struct QuickNoteSheet: View {
    let date: Date

    @EnvironmentObject private var store: EntryStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var existing: String {
        store.entry(for: date).text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(existing.isEmpty
                     ? "记下 \(DayText.short(date)) 的事"
                     : "会接在原有内容后面")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("一句话也行…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .focused($focused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 9)
                }
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        store.appendText(text, for: date)
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(330)])
    }
}
