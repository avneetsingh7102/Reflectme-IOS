import Foundation
@preconcurrency import SwiftData

/// A theme node belonging to one `JournalEntry`. Position is persisted so the
/// neural map remembers user-arranged layouts across launches.
@Model
final class SDNode {
    @Attribute(.unique) var id: String
    var label: String
    var categoryKey: String
    var emotionKey: String
    var weight: Int
    var expandedContent: String?
    var voiceNotes: [String]
    var positionX: Double?
    var positionY: Double?

    var session: JournalEntry?

    init(
        id: String = UUID().uuidString,
        label: String,
        category: NodeCategory = .other("uncategorized"),
        emotion: Emotion = .neutral,
        weight: Int = 1,
        expandedContent: String? = nil,
        voiceNotes: [String] = [],
        position: CGPoint? = nil
    ) {
        self.id = id
        self.label = label
        self.categoryKey = category.storageKey
        self.emotionKey = emotion.rawValue
        self.weight = weight
        self.expandedContent = expandedContent
        self.voiceNotes = voiceNotes
        self.positionX = position.map { Double($0.x) }
        self.positionY = position.map { Double($0.y) }
    }

    var category: NodeCategory { NodeCategory(apiString: categoryKey) }
    var emotion: Emotion { Emotion(apiString: emotionKey) }

    var position: CGPoint? {
        guard let x = positionX, let y = positionY else { return nil }
        return CGPoint(x: x, y: y)
    }
}
