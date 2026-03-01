import Foundation

// MARK: - Response models

struct SC2UIState: Decodable {
    let activeScreens: [String]
    var isInGame: Bool { activeScreens.isEmpty }
}

struct SC2GameState: Decodable {
    let isReplay: Bool
    let displayTime: Double
    let players: [SC2Player]
}

struct SC2Player: Decodable {
    let id: Int
    let name: String
    let type: String
    let race: String
    let result: String
}

struct SC2ScoreState: Decodable {
    let player: [SC2PlayerScore]
}

struct SC2PlayerScore: Decodable {
    let id: Int
    let scoreValueFoodUsed: Int
    let scoreValueFoodMade: Int
    let scoreValueMineralsCurrent: Int
    let scoreValueVespenCurrent: Int
    let scoreValueMineralsCollectionRate: Int
    let scoreValueVespenCollectionRate: Int
    let scoreValueWorkersActiveCount: Int
}

// MARK: - Client

actor SC2APIClient {
    private let port: Int
    private let session: URLSession

    init(port: Int = 6119) {
        self.port = port
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1.0
        config.timeoutIntervalForResource = 2.0
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    func fetchUI() async throws -> SC2UIState {
        try await fetch("/ui", as: SC2UIState.self)
    }

    func fetchGame() async throws -> SC2GameState {
        try await fetch("/game", as: SC2GameState.self)
    }

    func fetchScore() async throws -> SC2ScoreState {
        try await fetch("/score", as: SC2ScoreState.self)
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        guard let url = URL(string: "http://localhost:\(port)\(path)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
