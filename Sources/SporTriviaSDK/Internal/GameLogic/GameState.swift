import SwiftUI

/// Instance-scoped game state for a single custom game session.
/// Replaces the singleton CustomViewModel from the main app.
class GameState: ObservableObject {
    // Scoring
    @Published var correct: Int = 0
    @Published var incorrect: Int = 0
    @Published var currentStreak: Int = 0
    @Published var maxStreak: Int = 0

    // Player lists
    @Published var correctPlayerInfo: [PlayerInfo] = []
    @Published var correctUserPlayerInfo: [PlayerInfo] = []

    // Team display
    @Published var team1String: String = ""
    @Published var team2String: String = ""
    @Published var team1Image: UIImage?
    @Published var team2Image: UIImage?

    // Game metadata
    @Published var gameId: String = ""
    @Published var sport: Sport = .mlb
    @Published var customFileName: String = ""
    @Published var customQuestion: String?
    @Published var gameInProgress: Bool = false

    // Guess tracking
    @Published var playerGuesses: [String] = []
    @Published var correctOrIncorrect: [Bool] = []

    // User info
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var over18: Bool = false
    @Published var customFieldAnswers: [String: String] = [:]

    // Data-capture configuration from the answer key; set during loading,
    // before the player-info screen is shown.
    var collectFields: CollectFields = .legacyDefault

    // S3 prefix from the answer key where game results are uploaded; nil for
    // answer keys published before the portal embedded response_path.
    var responsePath: String?

    // Per-question sponsorship from the answer key (nil banner = no sponsor)
    @Published var sponsorshipImage: UIImage?
    @Published var sponsorshipBrand: String = ""
    @Published var sponsorshipURL: String = ""

    /// Total number of players remaining to guess.
    var playersLeft: Int {
        correctPlayerInfo.count
    }

    func clearGameData() {
        correctUserPlayerInfo = []
    }
}
