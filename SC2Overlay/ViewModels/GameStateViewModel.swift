import Foundation
import Combine

@MainActor
class GameStateViewModel: ObservableObject {
    @Published var isInGame: Bool = false
    @Published var displayTime: TimeInterval = 0
    @Published var score: SC2ScoreState?
    @Published var players: [SC2Player] = []
    @Published var port: Int = 6119 {
        didSet { restartPolling() }
    }

    /// Called each poll cycle with (currentSupply, displayTime).
    var onUpdate: ((Int, TimeInterval) -> Void)?

    private var client: SC2APIClient
    private var pollTask: Task<Void, Never>?

    init() {
        self.client = SC2APIClient(port: 6119)
        startPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func restartPolling() {
        pollTask?.cancel()
        client = SC2APIClient(port: port)
        startPolling()
    }

    // MARK: - Poll

    private func poll() async {
        do {
            let ui = try await client.fetchUI()
            isInGame = ui.isInGame

            guard ui.isInGame else { return }

            async let gameTask  = client.fetchGame()
            async let scoreTask = client.fetchScore()
            let (game, newScore) = try await (gameTask, scoreTask)

            displayTime = game.displayTime
            players     = game.players
            score       = newScore

            let supply = newScore.player.first?.scoreValueFoodUsed ?? 0
            onUpdate?(supply, game.displayTime)
        } catch {
            // SC2 not running or not in a game — silently swallow
        }
    }
}
