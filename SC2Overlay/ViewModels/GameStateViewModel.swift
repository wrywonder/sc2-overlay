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
    private let logger: SessionLogger
    private var inSession = false
    private var lastLoggedSecond: Int = -1
    private var lastLoggedSupply: Int = -1

    init(logger: SessionLogger) {
        self.logger = logger
        let savedPort = UserDefaults.standard.integer(forKey: Self.portKey)
        let initialPort = savedPort == 0 ? 6119 : savedPort
        self.port = initialPort
        self.client = SC2APIClient(port: initialPort)
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
        // ── Phase 1: Is the game running? ─────────────────────
        // Only this phase can set isInGame to false.
        let ui: SC2UIState
        do {
            ui = try await client.fetchUI()
        } catch {
            // Cannot reach SC2 at all (URLError) or bad config.
            if isInGame {
                logger.append("/ui FAIL — lost connection: \(error.localizedDescription)")
            }
            isInGame = false
            score = nil
            players = []
            connectionStatus = (error is URLError) ? .waitingForSC2 : .badConfiguration
            if inSession {
                logger.endSession()
                inSession = false
            }
            return
        }

        let wasInGame = isInGame
        isInGame = ui.isInGame
        connectionStatus = ui.isInGame ? .gameActive : .notInGame

        if wasInGame != ui.isInGame {
            logger.append("/ui isInGame changed: \(wasInGame) → \(ui.isInGame)  activeScreens=\(ui.activeScreens)")
        }

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

        // ── Phase 2: Fetch game data ──────────────────────────
        // Errors here are logged but do NOT set isInGame = false.
        // /game and /score are independent — one can fail without
        // affecting the other.

        var gameTime: TimeInterval?
        var supply: Int = 0

        // /game
        do {
            let game = try await client.fetchGame()
            displayTime = game.displayTime
            players     = game.players
            gameTime    = game.displayTime
        } catch {
            logger.append("/game error (overlay stays visible): \(error.localizedDescription)")
        }

        // /score (independent of /game success)
        do {
            let newScore = try await client.fetchScore()
            score  = newScore
            supply = newScore.player.first?.scoreValueFoodUsed ?? 0
        } catch {
            logger.append("/score error (using supply=0 fallback): \(error.localizedDescription)")
        }

        // Call tracker whenever we have time data.
        // Supply may be 0 if /score failed — tracker will still
        // advance time-based steps.
        if let t = gameTime {
            let currentSecond = Int(t)
            if currentSecond != lastLoggedSecond || supply != lastLoggedSupply {
                logger.append("tick supply=\(supply) time=\(currentSecond)s")
                lastLoggedSecond = currentSecond
                lastLoggedSupply = supply
            }
            onUpdate?(supply, t)
        }
    }
}
