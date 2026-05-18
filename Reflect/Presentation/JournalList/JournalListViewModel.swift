import Foundation
import Observation

/// Filtering, searching, grouping + deletion logic for the journal directory.
///
/// The list itself is a SwiftData `@Query` in the view (so it stays reactive
/// across app launches); the ViewModel just owns the active filter / search
/// text and the delete-by-offset call into the repository.
@MainActor
@Observable
final class JournalListViewModel {
    enum Filter: Equatable {
        case all
        case emotion(Emotion)
        case thisWeek
        case thisMonth

        var title: String {
            switch self {
            case .all:            return "All"
            case .emotion(let e): return e.label
            case .thisWeek:       return "This Week"
            case .thisMonth:      return "This Month"
            }
        }
    }

    /// A month-bucket of entries used for sectioned rendering.
    struct MonthGroup: Identifiable {
        let id: Date          // first day of the month
        let title: String     // "May 2026"
        let entries: [JournalEntry]
    }

    var filter: Filter = .all
    var searchText: String = ""

    private let repository: any JournalRepository
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    init(repository: any JournalRepository) {
        self.repository = repository
    }

    /// Applies filter + search to a flat list of entries.
    func visible(_ entries: [JournalEntry]) -> [JournalEntry] {
        applySearch(to: applyFilter(to: entries))
    }

    /// Groups already-filtered entries into month sections, newest first.
    /// Within each month the entries keep their incoming order (which is
    /// `@Query`'s reverse-date order).
    func grouped(_ entries: [JournalEntry]) -> [MonthGroup] {
        let calendar = Calendar.current
        var buckets: [(key: Date, value: [JournalEntry])] = []

        for entry in entries {
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            guard let monthStart = calendar.date(from: comps) else { continue }
            if let idx = buckets.firstIndex(where: { $0.key == monthStart }) {
                buckets[idx].value.append(entry)
            } else {
                buckets.append((monthStart, [entry]))
            }
        }

        return buckets.map { bucket in
            MonthGroup(
                id: bucket.key,
                title: monthFormatter.string(from: bucket.key),
                entries: bucket.value
            )
        }
    }

    func delete(at offsets: IndexSet, in entries: [JournalEntry]) {
        for index in offsets {
            guard entries.indices.contains(index) else { continue }
            try? repository.delete(entries[index])
        }
    }

    func delete(_ entry: JournalEntry) {
        try? repository.delete(entry)
    }

    // MARK: - Private

    private func applyFilter(to entries: [JournalEntry]) -> [JournalEntry] {
        switch filter {
        case .all:
            return entries
        case .emotion(let emotion):
            return entries.filter { entry in
                entry.mapNodes.contains { $0.emotion == emotion }
            }
        case .thisWeek:
            let since = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return entries.filter { $0.date >= since }
        case .thisMonth:
            let since = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return entries.filter { $0.date >= since }
        }
    }

    private func applySearch(to entries: [JournalEntry]) -> [JournalEntry] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return entries }
        return entries.filter { entry in
            entry.aiGeneratedTitle.lowercased().contains(needle)
                || entry.oneLineSummary.lowercased().contains(needle)
                || entry.rawTranscript.lowercased().contains(needle)
                || entry.mapNodes.contains { $0.label.lowercased().contains(needle) }
        }
    }
}
