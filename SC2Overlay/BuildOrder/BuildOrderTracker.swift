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
    private let logger: SessionLogger

    init(logger: SessionLogger) {
        self.logger = logger
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
        logger.append("BuildOrder loaded: \(parsed.count) steps parsed (mode=\(trackingMode.rawValue))")
        if let first = parsed.first {
            logger.append("  first step: supply=\(first.supply ?? -1) time=\(first.time ?? -1) action=\"\(first.action)\"")
        }
        DispatchQueue.main.async {
            self.steps = parsed
            self.currentIndex = -1
        }
    }

    func reset() {
        logger.append("BuildOrder reset")
        DispatchQueue.main.async {
            self.currentIndex = -1
        }
    }

    func clear() {
        logger.append("BuildOrder cleared")
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
            let oldIndex = currentIndex
            let stepName = steps[safe: newIndex]?.action ?? "n/a"
            let nextName = steps[safe: newIndex + 1]?.action ?? "(end)"
            logger.append("Tracker step \(oldIndex)→\(newIndex): completed=\"\(stepName)\" next=\"\(nextName)\" supply=\(supply) time=\(Int(time))s")
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
