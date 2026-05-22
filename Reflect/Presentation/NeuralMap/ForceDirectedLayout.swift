import CoreGraphics
import Foundation

/// Lays out theme nodes on the visible map canvas.
///
/// Persistence wins: any node with a stored `position` is honoured. Unplaced
/// nodes are spread across the canvas — for ≤4 nodes a smaller circle keeps
/// them visually anchored to the centre; for 5+ they spiral outward so they
/// don't all stack on one ring.
struct ForceDirectedLayout {
    /// Headroom we leave clear at the top (header / filter strip) before
    /// computing the centre of the layout region.
    var topInset: CGFloat = 0
    /// Headroom we leave clear at the bottom (record-ring FAB + label).
    var bottomInset: CGFloat = 140
    /// Side padding so node edges aren't clipped by the canvas.
    var sidePadding: CGFloat = 28

    func layout(nodes: [SDNode], canvasSize: CGSize) -> [PositionedNode] {
        guard !nodes.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return [] }

        let usableHeight = max(120, canvasSize.height - topInset - bottomInset)
        let usableWidth  = max(120, canvasSize.width - sidePadding * 2)
        let center = CGPoint(
            x: canvasSize.width / 2,
            y: topInset + usableHeight / 2
        )
        let maxRadius = min(usableWidth, usableHeight) / 2 - 12

        return nodes.enumerated().map { index, node in
            let position = node.position
                ?? defaultPosition(for: index, count: nodes.count,
                                   center: center, maxRadius: maxRadius)
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

    private func defaultPosition(for index: Int, count: Int,
                                 center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        if count == 1 { return center }

        // For 2–4 nodes: tight ring centred on the canvas.
        // For 5+: a spiral that spreads them out across the usable area.
        let isTightRing = count <= 4
        let normalisedIndex = Double(index) / Double(count)
        let radius: CGFloat = {
            if isTightRing { return maxRadius * 0.55 }
            // Spiral: smaller for early items, growing slowly.
            let t = CGFloat(index) / CGFloat(max(1, count - 1))
            return maxRadius * (0.35 + 0.55 * t)
        }()
        // Start at -90° so the first node sits straight above centre.
        let angle = normalisedIndex * 2.0 * .pi - .pi / 2
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }
}
