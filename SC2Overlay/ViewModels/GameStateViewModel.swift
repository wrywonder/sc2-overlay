import Foundation
import Combine

@MainActor
class GameStateViewModel: ObservableObject {
    enum ConnectionStatus: String {
        case waitingForSC2 = "Waiting for SC2…"
        case gameActive = "Connected — game active"
        case notInGame = "Connected — not in game"
        case badConfiguration = "Connection issue — check port/API setting"
    }

    private static let portKey = "sc2ApiPort"

    @Published var isInGame: Bool = false
    @Published var displayTime: TimeInterval = 0
    @Published var score: SC2ScoreState?
    @Published var players: [SC2Player] = []
    @Published var connectionStatus: ConnectionStatus = .waitingForSC2
    @Published var port: Int {
        didSet {
            UserDefaults.standard.set(port, forKey: Self.portKey)
            restartPolling()
        }
    }

    /// Called each poll cycle with (currentSupply, displayTime).
    var onUpdate: ((Int, TimeInterval) -> Void)?

    private var client: SC2APIClient
    private var pollTask: Task<Void, Never>?
    private let logger = SessionLogger()
    private var inSession = false
    private var lastLoggedSecond: Int = -1
    private var lastLoggedSupply: Int = -1

    init() {
        let savedPort = UserDefaults.standard.integer(forKey: Self.portKey)
        self.port = savedPort == 0 ? 6119 : savedPort
        self.client = SC2APIClient(port: self.port)
        startPolling()
    }

    deinit {
        pollTask?.cancel()
        if inSession {
            logger.endSession()
        }
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
            connectionStatus = ui.isInGame ? .gameActive : .notInGame

            guard ui.isInGame else {
                score = nil
                players = []
                if inSession {
                    logger.endSession()
                    inSession = false
                }
                return
            }

            if !inSession {
                logger.startSession()
                inSession = true
                lastLoggedSecond = -1
                lastLoggedSupply = -1
                logger.append("Polling active on port \(port)")
            }

            async let gameTask  = client.fetchGame()
            async let scoreTask = client.fetchScore()
            let (game, newScore) = try await (gameTask, scoreTask)

            displayTime = game.displayTime
            players     = game.players
            score       = newScore

            let supply = newScore.player.first?.scoreValueFoodUsed ?? 0
            let currentSecond = Int(game.displayTime)
            if currentSecond != lastLoggedSecond || supply != lastLoggedSupply {
                logger.append("Tick supply=\(supply) time=\(currentSecond)s")
                lastLoggedSecond = currentSecond
                lastLoggedSupply = supply
            }
            onUpdate?(supply, game.displayTime)
        } catch {
            isInGame = false
            score = nil
            players = []
            connectionStatus = (error as? URLError) != nil ? .waitingForSC2 : .badConfiguration
            if inSession {
                logger.append("Poll error: \(error.localizedDescription)")
                logger.endSession()
                inSession = false
            }
        }
    }
}
