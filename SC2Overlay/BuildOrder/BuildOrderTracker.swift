import Foundation
import Combine

enum TrackingMode: String, CaseIterable, Codable {
    case supply = "Supply"
    case time   = "Time"
}

@MainActor
class BuildOrderTracker: ObservableObject {
    @Published var steps: [BuildStep] = []
    /// Index of the most recently completed step, or -1 if none completed yet.
    @Published var currentIndex: Int = -1
    @Published var trackingMode: TrackingMode = .supply

    /// Minimum seconds a step stays visible before the tracker advances.
    private let minimumDisplayTime: TimeInterval = 3.0
    /// When the current step was first displayed.
    private var stepShownAt: Date = .distantPast

    // MARK: - Derived state

    var completedSteps: [BuildStep] {
        currentIndex >= 0 ? Array(steps.prefix(currentIndex)) : []
    }

    /// The most recently completed step (shown dimmed in the overlay).
    var currentStep: BuildStep? {
        currentIndex >= 0 ? steps[safe: currentIndex] : nil
    }

    /// The next upcoming step (highlighted in the overlay).
    var nextStep: BuildStep? {
        steps[safe: currentIndex + 1]
    }

    /// A small look-ahead window of upcoming steps after `nextStep`.
    var upcomingSteps: [BuildStep] {
        let start = currentIndex + 2
        let end   = min(start + 2, steps.count) // show up to 2 extra
        guard start < end else { return [] }
        return Array(steps[start..<end])
    }

    // MARK: - Load

    func load(text: String) {
        let parsed = BuildOrderParser.parse(text: text)
        steps = parsed
        currentIndex = -1
        stepShownAt = .distantPast
    }

    func reset() {
        currentIndex = -1
        stepShownAt = .distantPast
    }

    func clear() {
        steps = []
        currentIndex = -1
        stepShownAt = .distantPast
    }

    // MARK: - Update (called from polling)

    /// Called every ~500ms with current game state.
    func update(supply: Int, time: TimeInterval) {
        guard !steps.isEmpty else { return }

        // Find the highest index whose trigger condition is met.
        var targetIndex = -1
        for (i, step) in steps.enumerated() {
            let triggered: Bool
            switch trackingMode {
            case .supply:
                if let s = step.supply {
                    triggered = supply >= s
                } else if let t = step.time {
                    triggered = time >= t
                } else {
                    triggered = false
                }
            case .time:
                if let t = step.time {
                    triggered = time >= t
                } else if let s = step.supply {
                    triggered = supply >= s
                } else {
                    triggered = false
                }
            }
            if triggered { targetIndex = i }
        }

        guard targetIndex != currentIndex else { return }

        // Only advance (never go backwards during a game).
        guard targetIndex > currentIndex else { return }

        // Enforce minimum display time so steps aren't skipped too fast to read.
        // When multiple steps trigger simultaneously, advance one step at a time
        // with the minimum delay so the player sees each action.
        let elapsed = Date().timeIntervalSince(stepShownAt)
        if currentIndex >= 0 && elapsed < minimumDisplayTime {
            // Not enough time — advance by just one step toward the target.
            // The next poll cycle will continue catching up.
            return
        }

        // Advance one step at a time to ensure every step is visible briefly.
        let nextIndex = currentIndex + 1
        currentIndex = min(nextIndex, targetIndex)
        stepShownAt = Date()
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
