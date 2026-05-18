import Foundation
import Observation
import SwiftUI

/// Drives the `NeuralMapView`: loads or generates the theme graph for one
/// entry, lays it out, persists user drags, and exposes a `retry()` for
/// failed processing.
@MainActor
@Observable
final class NeuralMapViewModel {
    enum State: Equatable {
        case idle
        case processing
        case ready
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var nodes: [PositionedNode] = []
    private(set) var edges: [SDLink] = []
    var showUpdateToast: Bool = false

    private let entry: JournalEntry
    private let repository: any JournalRepository
    private let entryProcessor: any EntryProcessor
    private let deepDiveService: any DeepDiveService
    private let layout = ForceDirectedLayout()
    private var canvasSize: CGSize = .zero

    init(
        entry: JournalEntry,
        repository: any JournalRepository,
        entryProcessor: any EntryProcessor,
        deepDiveService: any DeepDiveService
    ) {
        self.entry = entry
        self.repository = repository
        self.entryProcessor = entryProcessor
        self.deepDiveService = deepDiveService
    }

    var categories: [NodeCategory] {
        var seen = Set<String>()
        return nodes.compactMap { node in
            let key = node.category.storageKey
            guard seen.insert(key).inserted else { return nil }
            return node.category
        }
    }

    func start(canvasSize: CGSize) async {
        updateCanvasSize(canvasSize)
        if entry.retryPending {
            await runProcessing()
        } else {
            renderFromPersistence()
            state = (entry.processingFailed == true) ? .failed("Processing failed. Tap retry to try again.") : .ready
        }
    }

    /// Called from the view when the layout size changes. Cheap if the size
    /// hasn't actually changed.
    func updateCanvasSize(_ newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0, newSize != canvasSize else { return }
        canvasSize = newSize
        renderFromPersistence()
    }

    func retry() async {
        await runProcessing()
    }

    func updatePosition(nodeId: String, to point: CGPoint) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        nodes[index].position = point
    }

    func persistPosition(nodeId: String, to point: CGPoint) {
        guard let sdNode = entry.mapNodes.first(where: { $0.id == nodeId }) else { return }
        try? repository.setPosition(point, for: sdNode)
    }

    func loadExpandedContent(for positionedNode: PositionedNode) async {
        guard
            let sdNode = entry.mapNodes.first(where: { $0.id == positionedNode.id }),
            sdNode.expandedContent == nil
        else { return }
        let transcript = entry.polishedTranscript.isEmpty ? entry.rawTranscript : entry.polishedTranscript
        do {
            let content = try await deepDiveService.expand(themeLabel: positionedNode.label, transcript: transcript)
            try repository.setExpandedContent(content, for: sdNode)
        } catch {
            print("⚠️ Deep dive failed: \(error.localizedDescription)")
        }
    }

    func filter(by category: NodeCategory?) -> (nodes: [PositionedNode], edges: [SDLink]) {
        guard let category else { return (nodes, edges) }
        let filteredNodes = nodes.filter { $0.category == category }
        let validIds = Set(filteredNodes.map(\.id))
        let filteredEdges = edges.filter { validIds.contains($0.source) && validIds.contains($0.target) }
        return (filteredNodes, filteredEdges)
    }

    private func runProcessing() async {
        print("🌀 NeuralMapViewModel.runProcessing → starting (transcript=\(entry.rawTranscript.count) chars)")
        state = .processing
        do {
            let result = try await entryProcessor.process(transcript: entry.rawTranscript)
            print("✅ Entry processor returned \(result.nodes.count) nodes, \(result.edges.count) edges")
            try repository.apply(result, to: entry)
            print("💾 Repository.apply persisted \(entry.mapNodes.count) nodes")
            renderFromPersistence()
            state = .ready
            showUpdateToast = true
        } catch {
            print("❌ Processing failed: \(error.localizedDescription)")
            try? repository.markFailed(entry)
            renderFromPersistence()
            state = .failed(error.localizedDescription)
        }
    }

    private func renderFromPersistence() {
        let positioned = layout.layout(nodes: entry.mapNodes, canvasSize: canvasSize)
        let validIds = Set(positioned.map(\.id))
        nodes = positioned
        edges = entry.mapLinks.filter { validIds.contains($0.source) && validIds.contains($0.target) }
    }
}
