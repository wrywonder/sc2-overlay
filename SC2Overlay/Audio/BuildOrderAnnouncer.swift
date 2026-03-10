import AppKit
import Combine

/// Announces build order step transitions via text-to-speech.
/// Observes `BuildOrderTracker.currentIndex` and speaks the next step's action.
@MainActor
final class BuildOrderAnnouncer {
    private let synth = NSSpeechSynthesizer()
    private let tracker: BuildOrderTracker
    private var cancellable: AnyCancellable?
    private var lastAnnouncedIndex: Int = -1

    /// When true, the next build step is spoken aloud on each transition.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "ttsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "ttsEnabled") }
    }

    init(tracker: BuildOrderTracker) {
        self.tracker = tracker
        synth.rate = 220  // slightly faster than default for gaming context

        cancellable = tracker.$currentIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] newIndex in
                self?.onIndexChanged(newIndex)
            }
    }

    private func onIndexChanged(_ newIndex: Int) {
        guard isEnabled else { return }
        guard newIndex != lastAnnouncedIndex else { return }
        lastAnnouncedIndex = newIndex

        // Announce the *next* step (what to build next)
        if let next = tracker.nextStep {
            let trigger = next.triggerLabel(mode: tracker.trackingMode) ?? ""
            let text: String
            if trigger.isEmpty {
                text = next.action
            } else {
                text = "\(next.action) at \(trigger)"
            }
            synth.stopSpeaking()
            synth.startSpeaking(text)
        } else if newIndex >= 0 {
            // Build order complete
            synth.stopSpeaking()
            synth.startSpeaking("Build order complete")
        }
    }
}
