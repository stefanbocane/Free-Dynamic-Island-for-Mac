import SwiftUI
import AppKit

struct NotesPanel: View {
    @EnvironmentObject var notes: NotesService
    @State private var draft: String = ""
    @State private var isAdding: Bool = false
    @State private var editingID: UUID?
    @State private var editingText: String = ""
    @FocusState private var focus: FocusTarget?

    enum FocusTarget: Hashable {
        case draft
        case edit(UUID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(notes.notes.prefix(4)) { note in
                        row(for: note)
                    }
                    if notes.notes.isEmpty && !isAdding {
                        Text("No notes yet")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if isAdding {
                inputField
            }
        }
    }

    private var header: some View {
        HStack {
            Text("NOTES")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Button {
                startAdding()
            } label: {
                Image(systemName: isAdding ? "xmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
    }

    private func row(for note: StickyNote) -> some View {
        let isEditing = editingID == note.id
        return Group {
            if isEditing {
                TextField("", text: $editingText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .focused($focus, equals: .edit(note.id))
                    .onSubmit { commitEdit(note) }
                    .onExitCommand { cancelEdit() }
            } else {
                noteCard(for: note)
            }
        }
    }

    private func noteCard(for note: StickyNote) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Left color bar + text: clickable area for editing.
            Button { beginEdit(note) } label: {
                HStack(alignment: .top, spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow.opacity(0.75))
                        .frame(width: 3)
                    Text(note.text)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Delete: its own button, separate hit target.
            Button { notes.remove(id: note.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var inputField: some View {
        HStack(spacing: 6) {
            TextField("New note…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .focused($focus, equals: .draft)
                .onSubmit { commitDraft() }
                .onExitCommand { cancelDraft() }

            Button(action: commitDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func startAdding() {
        if isAdding {
            cancelDraft()
        } else {
            isAdding = true
            draft = ""
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
                focus = .draft
            }
        }
    }

    private func commitDraft() {
        notes.add(draft)
        draft = ""
        isAdding = false
        focus = nil
    }

    private func cancelDraft() {
        draft = ""
        isAdding = false
        focus = nil
    }

    private func beginEdit(_ note: StickyNote) {
        editingID = note.id
        editingText = note.text
        DispatchQueue.main.async {
            focus = .edit(note.id)
        }
    }

    private func commitEdit(_ note: StickyNote) {
        notes.update(id: note.id, text: editingText)
        editingID = nil
        editingText = ""
        focus = nil
    }

    private func cancelEdit() {
        editingID = nil
        editingText = ""
        focus = nil
    }
}
