import CoreGraphics
import Foundation

/// Computes initial on-canvas positions for a set of `SDNode`s.
///
/// A node's persisted `position` always wins so user-arranged layouts survive
/// across launches. Unpositioned nodes are placed on a circle around the
/// canvas centre — simple, deterministic and good enough for 3–8 nodes
/// (the LLM is prompted to produce 3–5).
struct ForceDirectedLayout {
    var verticalOffset: CGFloat = -60
    var radiusFactor: CGFloat = 0.28

    func layout(nodes: [SDNode], canvasSize: CGSize) -> [PositionedNode] {
        guard !nodes.isEmpty else { return [] }
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2 + verticalOffset)
        let radius = max(60, min(canvasSize.width, canvasSize.height) * radiusFactor)

        return nodes.enumerated().map { index, node in
            let position = node.position ?? defaultPosition(
                for: index,
                count: nodes.count,
                center: center,
                radius: radius
            )
            return PositionedNode(
                id: node.id,
                label: node.label,
                category: node.category,
                emotion: node.emotion,
                weight: node.weight,
                position: position,
                animationDelay: Double(index) * 0.07
            )
        }
    }

    private func defaultPosition(for index: Int, count: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        if count == 1 { return center }
        let angle = (CGFloat(index) / CGFloat(count)) * 2 * .pi - .pi / 2
        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}
