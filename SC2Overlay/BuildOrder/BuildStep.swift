import Foundation

struct BuildStep: Identifiable, Codable {
    let id: UUID
    /// Supply count that triggers this step (nil if time-only).
    let supply: Int?
    /// Elapsed game time in seconds that triggers this step (nil if supply-only).
    let time: TimeInterval?
    /// The action to perform (e.g. "Supply Depot", "Barracks").
    let action: String
    /// Optional free-text note shown below the action.
    let note: String?

    init(supply: Int? = nil, time: TimeInterval? = nil, action: String, note: String? = nil) {
        self.id = UUID()
        self.supply = supply
        self.time = time
        self.action = action
        self.note = note
    }
}

extension BuildStep {
    /// Human-readable trigger label shown in the overlay.
    func triggerLabel(mode: TrackingMode) -> String? {
        switch mode {
        case .supply:
            if let s = supply { return "@\(s)" }
            if let t = time   { return formatTime(t) }
        case .time:
            if let t = time   { return formatTime(t) }
            if let s = supply { return "@\(s)" }
        }
        return nil
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
