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
    let logger = SessionLogger()
    private var inSession = false
    private var lastLoggedSecond: Int = -1
    private var lastLoggedSupply: Int = -1
    private var consecutiveDataFailures: Int = 0
    private var warnedAboutDataFailure = false

    init() {
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
        // Step 1: Check if SC2 is reachable and whether we're in a game.
        // /ui is the authoritative signal — if it fails, SC2 isn't running.
        let ui: SC2UIState
        do {
            ui = try await client.fetchUI()
        } catch {
            isInGame = false
            score = nil
            players = []
            connectionStatus = .waitingForSC2
            if inSession {
                logger.append("SC2 unreachable: \(error.localizedDescription)")
                logger.endSession()
                inSession = false
            }
            return
        }

        connectionStatus = ui.isInGame ? .gameActive : .notInGame

        guard ui.isInGame else {
            isInGame = false
            score = nil
            players = []
            if inSession {
                if lastLoggedSecond < 0 {
                    logger.append("Session ended with no game data captured. Check SC2 API configuration (gameClientRequestPort=6119).")
                }
                logger.endSession()
                inSession = false
            }
            return
        }

        // /ui says we're in game — set this unconditionally so the overlay stays visible
        // even if /game or /score return transient errors during loading.
        isInGame = true

        let sessionJustStarted = !inSession
        if sessionJustStarted {
            logger.startSession()
            inSession = true
            lastLoggedSecond = -1
            lastLoggedSupply = -1
            consecutiveDataFailures = 0
            warnedAboutDataFailure = false
            logger.append("Polling active on port \(port)")
        }

        // Step 2: Fetch game details + score. These can fail transiently
        // (404 during loading screens) without meaning the game ended.
        do {
            async let gameTask  = client.fetchGame()
            async let scoreTask = client.fetchScore()
            let (game, newScore) = try await (gameTask, scoreTask)

            if sessionJustStarted {
                for p in game.players {
                    logger.append("Player \(p.id): \(p.name) (\(p.race)) type=\(p.type)")
                }
            }

            displayTime = game.displayTime
            players     = game.players
            score       = newScore

            consecutiveDataFailures = 0
            warnedAboutDataFailure = false

            let supply = newScore.player.first?.scoreValueFoodUsed ?? 0
            let currentSecond = Int(game.displayTime)
            if currentSecond != lastLoggedSecond || supply != lastLoggedSupply {
                logger.append("Tick supply=\(supply) time=\(currentSecond)s")
                lastLoggedSecond = currentSecond
                lastLoggedSupply = supply
            }
            onUpdate?(supply, game.displayTime)
        } catch {
            // /game or /score failed but /ui says we're in game.
            // This is normal during loading screens — keep the session alive.
            consecutiveDataFailures += 1
            // ~60 polls * 0.5s = ~30 seconds of continuous failure
            if consecutiveDataFailures == 60 && !warnedAboutDataFailure {
                warnedAboutDataFailure = true
                logger.append("WARNING: /game and /score have failed for ~30s. SC2 may not be configured with gameClientRequestPort=6119 in Variables.txt, or this game mode may not expose API data.")
            } else if consecutiveDataFailures <= 5 || consecutiveDataFailures % 60 == 0 {
                logger.append("Poll data error (session continues): \(error.localizedDescription)")
            }
        }
    }
}
