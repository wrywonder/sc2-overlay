import Foundation
import Combine

enum TrackingMode: String, CaseIterable, Codable {
    case supply = "Supply"
    case time   = "Time"
}

@MainActor
class BuildOrderTracker: ObservableObject {
    @Published var steps: [BuildStep] = []
    @Published var currentIndex: Int = 0
    @Published var trackingMode: TrackingMode = .supply

    // MARK: - Derived state

    var completedSteps: [BuildStep] { Array(steps.prefix(currentIndex)) }
    var currentStep: BuildStep?    { steps[safe: currentIndex] }
    var nextStep: BuildStep?       { steps[safe: currentIndex + 1] }

    // MARK: - Load

    func load(text: String) {
        let parsed = BuildOrderParser.parse(text: text)
        steps = parsed
        currentIndex = 0
    }

    func reset() {
        currentIndex = 0
    }

    func clear() {
        steps = []
        currentIndex = 0
    }

    // MARK: - Update (called from polling)

    /// Called every ~500ms with current game state. Thread-safe.
    func update(supply: Int, time: TimeInterval) {
        guard !steps.isEmpty else { return }

        var newIndex = 0
        for (i, step) in steps.enumerated() {
            let triggered: Bool
            switch trackingMode {
            case .supply:
                if let s = step.supply {
                    triggered = supply >= s
                } else if let t = step.time {
                    triggered = time >= t   // fall back to time if no supply data
                } else {
                    triggered = false
                }
            case .time:
                if let t = step.time {
                    triggered = time >= t
                } else if let s = step.supply {
                    triggered = supply >= s // fall back to supply if no time data
                } else {
                    triggered = false
                }
            }
            if triggered { newIndex = i }
        }

        if newIndex != currentIndex {
            currentIndex = newIndex
        }
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
