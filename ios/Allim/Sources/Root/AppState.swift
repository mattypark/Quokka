import Foundation
import Observation
import AllimEngine

/// In-memory for now. The GRDB store lands in the next stage; keeping the drain and the UI
/// honest first means the storage layer arrives with something real to store.
@MainActor
@Observable
final class AppState {
    private(set) var saves: [InboxDrain.Drained] = []
    private let inbox = InboxDrain()

    /// Called on launch and every foreground. The share extension writes while the app is not
    /// running, so this is the only moment saves actually arrive.
    func drainInbox() {
        let drained = inbox.drain()
        guard !drained.isEmpty else { return }
        saves.insert(contentsOf: drained.reversed(), at: 0)
    }
}
