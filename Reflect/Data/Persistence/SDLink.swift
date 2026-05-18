import Foundation
@preconcurrency import SwiftData

/// A weighted edge between two `SDNode`s, scoped to one `JournalEntry`.
@Model
final class SDLink: Identifiable {
    var id: UUID
    var source: String
    var target: String
    var value: Int
    var relationship: String?

    var session: JournalEntry?

    init(source: String, target: String, value: Int = 1, relationship: String? = nil) {
        self.id = UUID()
        self.source = source
        self.target = target
        self.value = value
        self.relationship = relationship
    }
}
