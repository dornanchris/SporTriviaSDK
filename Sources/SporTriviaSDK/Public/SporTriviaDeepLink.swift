import Foundation

/// A parsed SporTrivia deep link.
///
/// SporTrivia QR codes launch partner apps with a URL of the form:
/// ```
/// yourscheme://sportrivia/custom/<gameId>?info=<sportCode>
/// ```
/// where `yourscheme` is the custom URL scheme your app registers in its
/// `Info.plist` (`CFBundleURLTypes`). The path and query are supplied by
/// SporTrivia and identify the question to load.
///
/// Usage (SwiftUI):
/// ```swift
/// .onOpenURL { url in
///     guard let link = SporTriviaDeepLink.parse(url) else { return }
///     let gameView = SporTriviaSDK.customGameView(
///         gameId: link.gameId,
///         sport: link.sport
///     )
///     // Present the view.
/// }
/// ```
public struct SporTriviaDeepLink: Equatable, Sendable {
    /// The custom game identifier (S3 file name, e.g. "NYI_Top5A").
    public let gameId: String
    /// The sport/league for the game.
    public let sport: Sport

    public init(gameId: String, sport: Sport) {
        self.gameId = gameId
        self.sport = sport
    }

    /// Parses a SporTrivia deep link URL.
    ///
    /// Accepts both the partner form (`scheme://sportrivia/custom/<gameId>`)
    /// and the SporTrivia app form (`sportrivia://custom/<gameId>`). Returns
    /// `nil` if the URL is not a SporTrivia game link or the sport code in
    /// the `info` query parameter is unknown.
    public static func parse(_ url: URL) -> SporTriviaDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var segments: [String] = []
        if let host = components.host, !host.isEmpty {
            segments.append(host)
        }
        segments.append(contentsOf: components.path.split(separator: "/").map(String.init))

        guard
            let customIndex = segments.firstIndex(where: { $0.caseInsensitiveCompare("custom") == .orderedSame }),
            segments.indices.contains(customIndex + 1)
        else {
            return nil
        }

        var gameId = segments[customIndex + 1]
        if gameId.lowercased().hasSuffix(".json") {
            gameId = String(gameId.dropLast(5))
        }
        guard !gameId.isEmpty else {
            return nil
        }

        let sportCode = components.queryItems?
            .first(where: { $0.name.caseInsensitiveCompare("info") == .orderedSame })?
            .value ?? ""
        guard let sport = Sport(rawValue: sportCode.trimmingCharacters(in: .whitespaces).lowercased()) else {
            return nil
        }

        return SporTriviaDeepLink(gameId: gameId, sport: sport)
    }

    /// Convenience overload for parsing from a raw string.
    public static func parse(_ string: String) -> SporTriviaDeepLink? {
        guard let url = URL(string: string) else {
            return nil
        }
        return parse(url)
    }
}
