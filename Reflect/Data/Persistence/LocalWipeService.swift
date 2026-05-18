import Foundation
@preconcurrency import SwiftData

/// Hard-wipes the local SwiftData store.
///
/// Called by `AuthSyncCoordinator` on sign-out so the next user (or the same
/// user reinstalling) starts clean before `CloudPullService` rehydrates.
@MainActor
final class LocalWipeService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func wipeAll() throws {
        // Entries cascade-delete their child nodes and links.
        try context.delete(model: JournalEntry.self)
        // Belt-and-braces: anything orphaned by cascade gaps.
        try context.delete(model: SDNode.self)
        try context.delete(model: SDLink.self)
        try context.save()
        print("🗑️ LocalWipe complete")
    }
}
