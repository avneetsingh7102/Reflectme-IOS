import Foundation
import Observation
@preconcurrency import SwiftData

/// Bridges auth-state changes to data-side effects.
///
/// - On sign-in: pull every owned row from Supabase into local SwiftData.
/// - On sign-out: wipe the local store so the next sign-in starts clean.
///
/// Owned by `ContentView` because it needs the SwiftUI-supplied
/// `ModelContext` and the live `ServiceContainer`. The coordinator itself is
/// stateless beyond a small `state` enum used to show a "syncing…" overlay.
@MainActor
@Observable
final class AuthSyncCoordinator {
    enum State: Equatable {
        case idle
        case pulling
        case ready
        case failed(String)
    }

    private(set) var state: State = .idle

    private let auth: any AuthService
    private let pull: CloudPullService
    private let wipe: LocalWipeService

    init(auth: any AuthService, pull: CloudPullService, wipe: LocalWipeService) {
        self.auth = auth
        self.pull = pull
        self.wipe = wipe
    }

    /// Call after authentication transitions. We compare to the previous
    /// state at the call site so we don't kick off a pull on every render.
    func handle(isAuthenticatedNow: Bool) async {
        if isAuthenticatedNow {
            // Local-bypass mode skips both pull and wipe — user is testing
            // offline without a Supabase session.
            if auth.isLocalBypass {
                print("⚠️ Local bypass active — skipping cloud pull.")
                state = .ready
                return
            }
            guard let userID = auth.currentUserID else {
                state = .failed("Signed in but no user id.")
                return
            }
            state = .pulling
            do {
                try await pull.pullAll(userID: userID)
                state = .ready
            } catch {
                print("❌ CloudPull failed: \(error)")
                state = .failed(error.localizedDescription)
            }
        } else {
            do {
                try wipe.wipeAll()
            } catch {
                print("❌ LocalWipe failed: \(error)")
            }
            state = .idle
        }
    }
}
