import UIKit

/// The share extension gets its own, deliberately minimal haptics.
///
/// Core Haptics is not worth starting an engine for in a process that lives for half a
/// second; the canned generators fire immediately and cost nothing. The app's richer
/// vocabulary lives in Haptics.swift, where the engine has time to be useful.
enum ShareHaptics {
    static func saved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func rejected() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
