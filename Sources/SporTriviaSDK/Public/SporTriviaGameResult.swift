import Foundation

/// Result data returned when a custom game completes.
public struct SporTriviaGameResult: Sendable {
    /// The game identifier (custom file name).
    public let gameId: String

    /// The sport/league for this game.
    public let sport: Sport

    /// Number of correct answers.
    public let correct: Int

    /// Number of incorrect answers.
    public let incorrect: Int

    /// Longest streak of consecutive correct answers.
    public let maxStreak: Int

    /// User information collected before the game.
    public let userInfo: SporTriviaUserInfo

    /// Names of correctly guessed players.
    public let correctPlayerNames: [String]
}

/// User information collected by the SDK's user info screen.
public struct SporTriviaUserInfo: Sendable {
    public let firstName: String
    public let lastName: String
    public let email: String
    public let phoneNumber: String
}
