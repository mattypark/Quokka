import CoreHaptics
import UIKit

/// Quokka's haptics are part of the identity, not decoration -- the wordmark spelling itself
/// out with a tap per glyph is the first thing the app does.
///
/// Core Haptics is used rather than `UIFeedbackGenerator` because the patterns here need
/// control over sharpness and duration that the canned generators do not expose. The
/// generators remain as the fallback for devices with no haptic engine.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    /// Off is a real setting, not a hidden one. Haptics on every save is a lot of buzzing for
    /// someone who saves in bursts.
    var enabled = true

    private init() { prepare() }

    private func prepare() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()

            // The engine is stopped by the system for reasons outside the app's control --
            // an incoming call, going to the background. Without these it silently never
            // comes back and the app just stops having haptics for the rest of its life.
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engine = nil }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in try? self?.engine?.start() }
            }

            try engine.start()
            self.engine = engine
        } catch {
            // A missing haptic engine is never worth failing a launch over.
            engine = nil
        }
    }

    private func play(_ events: [CHHapticEvent]) {
        guard enabled, supportsHaptics else { return }
        if engine == nil { prepare() }
        // Bound to a differently-named local so the `catch` below can still clear the
        // property -- shadowing it with `guard let engine` makes that assignment illegal.
        guard let running = engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try running.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // A failed player usually means the engine died underneath us. Dropping it here
            // means the next call rebuilds rather than failing forever.
            engine = nil
        }
    }

    private func transient(intensity: Float, sharpness: Float, at time: TimeInterval = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    // MARK: - The vocabulary

    /// One tap as a glyph of the wordmark lands. Sharpness climbs across the word so the
    /// name resolves rather than just repeating -- five identical taps read as a stutter.
    func glyph(index: Int, of total: Int) {
        let progress = total > 1 ? Float(index) / Float(total - 1) : 1
        play([transient(intensity: 0.55, sharpness: 0.3 + 0.5 * progress)])
    }

    /// A save landed. Two sharp taps, tight together -- the confirmation happens inside
    /// another app's share sheet, where there is no room for anything visual.
    func saved() {
        play([
            transient(intensity: 0.9, sharpness: 0.75),
            transient(intensity: 0.65, sharpness: 0.9, at: 0.085),
        ])
    }

    /// The save could not be understood. One soft, dull tap: distinguishable from success
    /// without being punishing.
    func rejected() {
        play([transient(intensity: 0.4, sharpness: 0.1)])
    }

    /// A section header snapping past while scrolling.
    func tick() {
        guard enabled else { return }
        guard supportsHaptics else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        play([transient(intensity: 0.3, sharpness: 0.6)])
    }
}
