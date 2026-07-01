import SwiftUI

/// A custom game referenced by a deep link, ready to be launched.
public struct SporTriviaPendingGame: Sendable, Equatable {
    /// The custom game identifier (S3 file name, e.g. "NYI_Top5A").
    public let gameId: String
    /// The sport/league for this game.
    public let sport: Sport

    public init(gameId: String, sport: Sport) {
        self.gameId = gameId
        self.sport = sport
    }
}

extension SporTriviaSDK {

    private static let pendingDefaults = UserDefaults(suiteName: "com.sportrivia.sdk")
    private static let pendingGameIdKey = "pendingGameId"
    private static let pendingSportKey = "pendingSport"

    /// Handle an incoming deep link (e.g. from `onOpenURL`).
    ///
    /// Recognizes links of the form
    /// `sportrivia-<partnerId>://game?gameId=<id>&sport=<code>` produced by the
    /// SporTrivia SDK redirect page. When recognized, the game is saved so it
    /// can be launched (see ``pendingGame()`` / ``pendingGameView(delegate:)``).
    ///
    /// - Returns: `true` if the URL was a valid SporTrivia game link, else `false`.
    @discardableResult
    public static func handleDeepLink(_ url: URL) -> Bool {
        guard let game = parseGameLink(url) else { return false }
        savePendingGame(game)
        return true
    }

    /// Parse a SporTrivia game deep link without persisting it.
    public static func parseGameLink(_ url: URL) -> SporTriviaPendingGame? {
        // Only accept our reserved scheme family: "sportrivia" / "sportrivia-<id>".
        let scheme = (url.scheme ?? "").lowercased()
        guard scheme == "sportrivia" || scheme.hasPrefix("sportrivia-") else { return nil }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }

        // gameId + sport can arrive as query params. Fall back to path segments
        // for links shaped like `.../game/<gameId>`.
        let pathParts = url.pathComponents.filter { $0 != "/" }
        let gameId = (value("gameId") ?? value("game_id") ?? pathParts.last ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sportCode = (value("sport") ?? value("info") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !gameId.isEmpty, let sport = Sport(rawValue: sportCode) else { return nil }
        return SporTriviaPendingGame(gameId: gameId, sport: sport)
    }

    /// The game most recently saved from a deep link (or claimed after install),
    /// if any.
    public static func pendingGame() -> SporTriviaPendingGame? {
        guard
            let gameId = pendingDefaults?.string(forKey: pendingGameIdKey), !gameId.isEmpty,
            let sportCode = pendingDefaults?.string(forKey: pendingSportKey),
            let sport = Sport(rawValue: sportCode)
        else { return nil }
        return SporTriviaPendingGame(gameId: gameId, sport: sport)
    }

    /// Clear any saved pending game. Call this after you launch it so it does
    /// not re-launch on the next app start.
    public static func clearPendingGame() {
        pendingDefaults?.removeObject(forKey: pendingGameIdKey)
        pendingDefaults?.removeObject(forKey: pendingSportKey)
    }

    /// Convenience: if a pending game exists, return the game view for it and
    /// clear the pending state. Returns `nil` when there is nothing pending.
    ///
    /// Requires ``configure(_:)`` to have been called first.
    public static func pendingGameView(delegate: SporTriviaDelegate? = nil) -> AnyView? {
        guard let game = pendingGame() else { return nil }
        clearPendingGame()
        return AnyView(customGameView(gameId: game.gameId, sport: game.sport, delegate: delegate))
    }

    /// Persist a pending game so it survives an app restart / cold launch.
    public static func savePendingGame(_ game: SporTriviaPendingGame) {
        pendingDefaults?.set(game.gameId, forKey: pendingGameIdKey)
        pendingDefaults?.set(game.sport.rawValue, forKey: pendingSportKey)
    }

    // MARK: - Deferred (post-install) claiming

    /// Ask the SporTrivia redirect service whether a game was saved off for
    /// this partner before the app was installed (deferred deep linking).
    ///
    /// Requires `partnerId` and `redirectBaseURL` to be set on the
    /// ``SporTriviaConfiguration``. On success the returned game is also saved
    /// as the pending game.
    ///
    /// - Parameter completion: Called on the main thread with the claimed game,
    ///   or `nil` if none was found / claiming isn't configured.
    public static func claimPendingGame(completion: @escaping (SporTriviaPendingGame?) -> Void) {
        func finish(_ game: SporTriviaPendingGame?) {
            DispatchQueue.main.async { completion(game) }
        }

        guard
            let config = configuration,
            let partnerId = config.partnerId, !partnerId.isEmpty,
            let baseURL = config.redirectBaseURL
        else {
            finish(nil)
            return
        }

        let endpoint = baseURL.appendingPathComponent("api/sdk/claim-game")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["partner_id": partnerId])

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                json["found"] as? Bool == true,
                let gameId = json["game_id"] as? String, !gameId.isEmpty,
                let sportCode = (json["sport"] as? String)?.lowercased(),
                let sport = Sport(rawValue: sportCode)
            else {
                finish(nil)
                return
            }
            let game = SporTriviaPendingGame(gameId: gameId, sport: sport)
            savePendingGame(game)
            finish(game)
        }.resume()
    }
}
