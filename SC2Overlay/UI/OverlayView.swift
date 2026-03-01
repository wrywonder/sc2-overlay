import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var tracker: BuildOrderTracker
    @EnvironmentObject var gameState: GameStateViewModel

    var body: some View {
        Group {
            if tracker.steps.isEmpty || !gameState.isInGame {
                EmptyView()
            } else {
                overlayContent
            }
        }
    }

    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Completed / current step (dimmed)
            if let current = tracker.currentStep {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green.opacity(0.6))
                    Text(current.action)
                        .foregroundStyle(.white.opacity(0.45))
                        .strikethrough(color: .white.opacity(0.3))
                    Spacer()
                    if let label = current.triggerLabel(mode: tracker.trackingMode) {
                        Text(label)
                            .foregroundStyle(.white.opacity(0.3))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }

            Divider().overlay(.white.opacity(0.12))

            // Next step (highlighted)
            if let next = tracker.nextStep {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.orange)
                    Text(next.action)
                        .foregroundStyle(.white)
                    Spacer()
                    if let label = next.triggerLabel(mode: tracker.trackingMode) {
                        Text(label)
                            .foregroundStyle(.orange.opacity(0.85))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.green)
                    Text("Build order complete")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
            }

            // Supply / time indicator strip
            HStack(spacing: 8) {
                if let score = gameState.score?.player.first {
                    Label("\(score.scoreValueFoodUsed)/\(score.scoreValueFoodMade)",
                          systemImage: "person.2.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text(formatTime(gameState.displayTime))
                    .foregroundStyle(.white.opacity(0.35))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
            }
            .font(.system(size: 10, weight: .regular, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.68))
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 2)
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
