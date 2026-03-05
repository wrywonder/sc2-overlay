import Foundation
import Combine

enum TrackingMode: String, CaseIterable, Codable {
    case supply = "Supply"
    case time   = "Time"
}

class BuildOrderTracker: ObservableObject {
    @Published var steps: [BuildStep] = []
    /// Index of last completed step, or -1 if no step has been completed yet.
    @Published var currentIndex: Int = -1
    @Published var trackingMode: TrackingMode = .supply {
        didSet {
            UserDefaults.standard.set(trackingMode.rawValue, forKey: Self.trackingModeKey)
        }
    }

    private static let trackingModeKey = "trackingMode"

    /// Shared logger injected by AppDelegate after both objects are created.
    var logger: SessionLogger?

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.trackingModeKey),
           let mode = TrackingMode(rawValue: raw) {
            trackingMode = mode
        }
    }

    // MARK: - Derived state

    var completedSteps: [BuildStep] { Array(steps.prefix(max(currentIndex + 1, 0))) }
    var currentStep: BuildStep?    { steps[safe: currentIndex] }
    var nextStep: BuildStep?       { steps[safe: currentIndex + 1] }

    // MARK: - Load

    func load(text: String) {
        let parsed = BuildOrderParser.parse(text: text)
        logger?.append("Build order loaded: \(parsed.count) steps (tracking: \(trackingMode.rawValue))")
        for (i, step) in parsed.enumerated() {
            var trigger = ""
            if let s = step.supply { trigger += "supply=\(s)" }
            if let t = step.time   { trigger += trigger.isEmpty ? "" : " "; trigger += "time=\(Int(t))s" }
            logger?.append("  Step \(i): \(trigger.isEmpty ? "(no trigger)" : trigger) — \(step.action)")
        }
        DispatchQueue.main.async {
            self.steps = parsed
            self.currentIndex = -1
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.currentIndex = -1
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.steps = []
            self.currentIndex = -1
        }
    }

    // MARK: - Update (called from polling)

    /// Called every ~500ms with current game state. Thread-safe.
    func update(supply: Int, time: TimeInterval) {
        guard !steps.isEmpty else { return }

        var newIndex = -1
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
            let stepDesc = steps[safe: newIndex].map { "\"\($0.action)\"" } ?? "none"
            logger?.append("Step advanced to \(newIndex): \(stepDesc) — supply=\(supply) time=\(Int(time))s")
            DispatchQueue.main.async { self.currentIndex = newIndex }
        }
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
