import SwiftUI

/// Inline 500-char note editor that lives below a Polaroid. The
/// design goal is "writing on the back of an instant photo" —
/// monospaced serif feel, a faint paper-grain feel, soft white
/// background. Saves are debounced so the user can type freely
/// without us hammering disk on every keystroke.
struct JournalNoteEditor: View {
    let entryId: UUID
    @State private var draft: String
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    init(entryId: UUID, initial: String?) {
        self.entryId = entryId
        self._draft = State(initialValue: initial ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HOW WAS YOUR DAY?")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.black.opacity(0.45))
                Spacer()
                Text("\(remaining)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(remaining < 30 ? .orange : .black.opacity(0.35))
            }

            TextEditor(text: $draft)
                .focused($focused)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(.black.opacity(0.82))
                .scrollContentBackground(.hidden)
                .background(Color(red: 0.99, green: 0.98, blue: 0.95))
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("A few lines about today — the sky, the light, what you were thinking about…")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.black.opacity(0.32))
                            .padding(.top, 10)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 92, maxHeight: 220)
                .onChange(of: draft) { _, new in
                    if new.count > JournalEntry.noteCharacterLimit {
                        draft = String(new.prefix(JournalEntry.noteCharacterLimit))
                    }
                    scheduleSave()
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.99, green: 0.98, blue: 0.95))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        )
        .onTapGesture { focused = true }
    }

    private var remaining: Int {
        JournalEntry.noteCharacterLimit - draft.count
    }

    /// 600 ms debounce — long enough to avoid spammy disk writes,
    /// short enough that a user putting the phone down briefly
    /// won't lose their thought.
    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = draft
        let id = entryId
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if Task.isCancelled { return }
            await JournalStore.shared.updateNote(snapshot, on: id)
        }
    }
}
