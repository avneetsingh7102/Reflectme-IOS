import CoreGraphics
import Foundation

/// View-model-friendly snapshot of an `SDNode` with a concrete on-canvas
/// position and a deterministic animation delay.
struct PositionedNode: Identifiable, Equatable {
    let id: String
    let label: String
    let category: NodeCategory
    let emotion: Emotion
    let weight: Int
    var position: CGPoint
    let animationDelay: Double

    var prominence: Double {
        min(1.0, max(0.2, Double(weight) / 5.0))
    }
}
