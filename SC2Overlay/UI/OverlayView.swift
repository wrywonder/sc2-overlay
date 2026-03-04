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
            // Most recently completed step (dimmed)
            if let current = tracker.currentStep {
                stepRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .green.opacity(0.6),
                    step: current,
                    textColor: .white.opacity(0.45),
                    labelColor: .white.opacity(0.3),
                    fontSize: 12,
                    strikethrough: true
                )
            }

            Divider().overlay(.white.opacity(0.12))

            // Next step (highlighted — the one the player should do now)
            if let next = tracker.nextStep {
                stepRow(
                    icon: "arrow.right.circle.fill",
                    iconColor: .orange,
                    step: next,
                    textColor: .white,
                    labelColor: .orange.opacity(0.85),
                    fontSize: 14,
                    strikethrough: false
                )

                // Look-ahead: 2 more upcoming steps (dimmer)
                ForEach(tracker.upcomingSteps) { step in
                    stepRow(
                        icon: "circle",
                        iconColor: .white.opacity(0.25),
                        step: step,
                        textColor: .white.opacity(0.5),
                        labelColor: .white.opacity(0.35),
                        fontSize: 12,
                        strikethrough: false
                    )
                }
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

    private func stepRow(
        icon: String,
        iconColor: Color,
        step: BuildStep,
        textColor: Color,
        labelColor: Color,
        fontSize: CGFloat,
        strikethrough: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Group {
                if strikethrough {
                    Text(step.action)
                        .strikethrough(color: .white.opacity(0.3))
                } else {
                    Text(step.action)
                }
            }
            .foregroundStyle(textColor)
            Spacer()
            if let label = step.triggerLabel(mode: tracker.trackingMode) {
                Text(label)
                    .foregroundStyle(labelColor)
                    .font(.system(size: max(fontSize - 3, 10), weight: .medium, design: .monospaced))
            }
        }
        .font(.system(size: fontSize, weight: fontSize >= 14 ? .semibold : .medium, design: .rounded))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
