import Foundation
import Combine

struct StickyNote: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

/// Persists a small list of sticky notes in UserDefaults. Keeps at most N most-recent.
@MainActor
final class NotesService: ObservableObject {
    @Published private(set) var notes: [StickyNote] = []

    private let defaults: UserDefaults
    private let key = "islandapp.stickyNotes.v1"
    private let maxNotes = 30

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = notes
        updated.insert(StickyNote(text: trimmed), at: 0)
        if updated.count > maxNotes { updated = Array(updated.prefix(maxNotes)) }
        notes = updated
        persist()
    }

    func update(id: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        if trimmed.isEmpty {
            notes.remove(at: idx)
        } else {
            notes[idx].text = trimmed
        }
        persist()
    }

    func remove(id: UUID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([StickyNote].self, from: data) else { return }
        notes = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: key)
    }
}
