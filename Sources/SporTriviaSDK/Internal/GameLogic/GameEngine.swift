import UIKit

/// Core game logic for custom games.
/// Extracted from CustomActivity.swift — handles answer validation, scoring, and game setup.
class GameEngine: ObservableObject {
    @Published var gameInProgress: Bool = false

    var correctPlayerIds: [String] = []
    private var usedPlayerInfoSet = Set<PlayerInfo>()

    let gameState: GameState
    let playerListManager: PlayerListManager
    let s3Service: S3DataService
    let imageCache: ImageCache

    /// Best-effort device location for the results upload; injected by the
    /// flow coordinator. Nil (e.g. in tests) uploads location_status "unavailable".
    weak var locationProvider: LocationProviding?

    init(gameState: GameState, playerListManager: PlayerListManager, s3Service: S3DataService, imageCache: ImageCache) {
        self.gameState = gameState
        self.playerListManager = playerListManager
        self.s3Service = s3Service
        self.imageCache = imageCache
    }

    /// Load game data from S3 and set up the game.
    ///
    /// Runs on a background task: all downloads/parsing happen off the main
    /// thread, and every @Published mutation (GameState, PlayerListManager)
    /// hops to the main actor — SwiftUI drops updates published from
    /// background threads, which is how the autocomplete list could load
    /// but never appear.
    func loadGame(gameId: String, sport: Sport) async throws {
        SporTriviaLogger.info("Loading game: gameId=\(gameId), sport=\(sport.rawValue)")
        await MainActor.run {
            gameState.gameId = gameId
            gameState.sport = sport
            gameState.customFileName = gameId
        }

        // 1. Download answer key
        let answerKey = try await s3Service.downloadAnswerKey(customFileName: gameId)
        let loadedCorrectIds = answerKey.player_id.map { normalizePlayerId($0) }
        correctPlayerIds = loadedCorrectIds
        SporTriviaLogger.info("Answer key loaded: \(loadedCorrectIds.count) correct IDs")
        SporTriviaLogger.debug("Correct IDs: \(loadedCorrectIds)")

        // 2. Download player list (parsed leniently, deduplicated)
        let players = try await s3Service.downloadPlayerList(sport: sport)
        if players.isEmpty {
            // Empty here means a runtime data/parse problem with this sport's
            // player file — the autocomplete dropdown will have nothing to show.
            SporTriviaLogger.warning("\u{26a0}\u{fe0f} Player list is EMPTY for \(sport.rawValue) — autocomplete suggestions will not appear. Check the all_\(sport.rawValue)_players.json format.")
        } else {
            SporTriviaLogger.info("\u{2705} Player list loaded: \(players.count) players for \(sport.rawValue) — autocomplete ready")
        }

        // 3. Match answers to the player list
        let matchedPlayers = findMatchingPlayerInfo(playerIds: loadedCorrectIds, in: players)
        SporTriviaLogger.info("Matched \(matchedPlayers.count) of \(loadedCorrectIds.count) player IDs to player names")

        if matchedPlayers.isEmpty && !loadedCorrectIds.isEmpty {
            SporTriviaLogger.warning("\u{26a0}\u{fe0f} 0 players matched! This means the answer key player IDs don't match the player list IDs.")
            SporTriviaLogger.warning("Answer key IDs (first 5): \(Array(loadedCorrectIds.prefix(5)))")
            SporTriviaLogger.warning("Player list IDs (first 5): \(Array(players.prefix(5).map { $0.playerId }))")
        }

        await MainActor.run {
            gameState.customQuestion = answerKey.question
            gameState.collectFields = answerKey.collectFields ?? .legacyDefault
            gameState.responsePath = answerKey.responsePath
            playerListManager.playerInfoList = players
            gameState.correctPlayerInfo = matchedPlayers
        }

        // 4. Load team image
        let comboComponents = gameId.components(separatedBy: "_")
        let teamAbbr = comboComponents[0]
        SporTriviaLogger.debug("Team abbreviation from gameId: \(teamAbbr)")

        if let image = await imageCache.teamImage(sport: sport, teamAbbr: teamAbbr) {
            await MainActor.run {
                gameState.team1Image = image
            }
            SporTriviaLogger.info("Team image loaded for \(teamAbbr)")
        } else {
            SporTriviaLogger.warning("No team image found for \(teamAbbr) — game will show without image")
        }

        // 5. Resolve team name
        let teamName = TeamAbbreviations.teamName(forAbbreviation: teamAbbr, sport: sport) ?? teamAbbr
        await MainActor.run {
            gameState.team1String = teamName
            gameState.team2String = ""
        }

        // 6. Load sponsorship banner (optional, non-fatal): the portal embeds
        // the chosen sponsorship in the answer key with the banner's S3 key.
        if let sponsorship = answerKey.sponsorship, !sponsorship.assetKey.isEmpty {
            do {
                let bannerData = try await s3Service.download(key: sponsorship.assetKey)
                if let bannerImage = UIImage(data: bannerData) {
                    await MainActor.run {
                        gameState.sponsorshipImage = bannerImage
                        gameState.sponsorshipBrand = sponsorship.brand
                        gameState.sponsorshipURL = sponsorship.url
                    }
                    SporTriviaLogger.info("Sponsorship banner loaded for '\(sponsorship.brand)'")
                } else {
                    SporTriviaLogger.error("Sponsorship banner for '\(sponsorship.brand)' downloaded but could not be decoded as an image (\(sponsorship.assetKey), \(bannerData.count) bytes) — banner will not be shown")
                }
            } catch {
                SporTriviaLogger.error("Sponsorship banner failed to download (\(sponsorship.assetKey)): \(error) — banner will not be shown. If this is an access error, the SDK credentials need s3:GetObject on sponsorships/* (see PARTNER_SETUP.md)")
            }
        }

        SporTriviaLogger.info("Game ready: '\(teamName)', \(gameState.correctPlayerInfo.count) players to guess, question: \(gameState.customQuestion ?? "none")")
    }

    /// Start the game after loading is complete.
    func startGame() {
        gameInProgress = true
        gameState.gameInProgress = true
        usedPlayerInfoSet = []
        gameState.correct = 0
        gameState.incorrect = 0
        gameState.currentStreak = 0
        gameState.maxStreak = 0
        gameState.playerGuesses = []
        gameState.correctOrIncorrect = []
        gameState.correctUserPlayerInfo = []
    }

    /// Check if a player ID has already been used in this session.
    func checkIfIdUsed(playerId: String) -> Bool {
        return usedPlayerInfoSet.contains { $0.playerId == playerId }
    }

    /// Validate an answer and update game state.
    /// Returns true if the answer is correct.
    func checkAnswer(playerInfo: PlayerInfo) -> Bool {
        let normalizedInputId = normalizePlayerId(playerInfo.playerId)
        var isCorrect = correctPlayerIds.contains(normalizedInputId)

        // Also check partial containment for non-baseball sports
        if !isCorrect && gameState.sport != .mlb {
            for correctId in correctPlayerIds {
                if correctId.contains(normalizedInputId) || normalizedInputId.contains(correctId) {
                    isCorrect = true
                    break
                }
            }
        }

        if isCorrect {
            usedPlayerInfoSet.insert(playerInfo)
            gameState.correctOrIncorrect.append(true)
            gameState.correct += 1
            gameState.currentStreak += 1
            gameState.maxStreak = max(gameState.currentStreak, gameState.maxStreak)
            gameState.correctPlayerInfo.removeAll { $0.playerId == playerInfo.playerId }
            gameState.correctUserPlayerInfo.append(playerInfo)
        } else {
            gameState.correctOrIncorrect.append(false)
            gameState.incorrect += 1
        }

        gameState.playerGuesses.append(playerInfo.playerName)
        playerListManager.selectedPlayerInfo = nil
        return isCorrect
    }

    /// Whether all correct answers have been found.
    var allAnswersFound: Bool {
        gameState.correctPlayerInfo.isEmpty
    }

    /// Upload game results to S3.
    func uploadResults() async {
        do {
            let userInfo = SporTriviaUserInfo(
                firstName: gameState.firstName,
                lastName: gameState.lastName,
                email: gameState.email,
                phoneNumber: gameState.phoneNumber,
                over18: gameState.over18,
                customFieldAnswers: gameState.customFieldAnswers
            )
            // Best-effort location: waits at most 8s for a fix that started
            // warming when the game opened; never fails the upload.
            let location = await locationProvider?.capture(timeout: 8) ?? .unavailable
            let resultData = try JsonParser.formatGameResults(
                userInfo: userInfo,
                gameId: gameState.gameId,
                correctPlayers: gameState.correctUserPlayerInfo,
                location: location
            )

            if let responsePath = gameState.responsePath?.trimmingCharacters(in: .whitespacesAndNewlines),
               !responsePath.isEmpty {
                // Preferred: the portal embeds the exact upload destination in
                // the answer key so results land where the portal export reads.
                try await s3Service.uploadGameResults(responsePath: responsePath, resultData: resultData)
            } else {
                // Legacy answer keys (no response_path): derive a path from the
                // gameId. For partner accounts this folder may not match the
                // portal export's location — republish the question to fix.
                let comboComponents = gameState.gameId.components(separatedBy: "_")
                let teamAbbr = comboComponents[0]
                let suffix = comboComponents.count > 1 ? comboComponents.dropFirst().joined(separator: "_") : ""
                let teamName = TeamAbbreviations.teamName(forAbbreviation: teamAbbr, sport: gameState.sport) ?? teamAbbr

                try await s3Service.uploadGameResults(
                    sport: gameState.sport,
                    teamName: teamName,
                    suffix: suffix,
                    resultData: resultData
                )
            }
        } catch {
            print("SporTriviaSDK: Failed to upload game results: \(error)")
        }
    }

    /// Build the game result for the delegate callback.
    func buildResult() -> SporTriviaGameResult {
        return SporTriviaGameResult(
            gameId: gameState.gameId,
            sport: gameState.sport,
            correct: gameState.correct,
            incorrect: gameState.incorrect,
            maxStreak: gameState.maxStreak,
            userInfo: SporTriviaUserInfo(
                firstName: gameState.firstName,
                lastName: gameState.lastName,
                email: gameState.email,
                phoneNumber: gameState.phoneNumber,
                over18: gameState.over18,
                customFieldAnswers: gameState.customFieldAnswers
            ),
            correctPlayerNames: gameState.correctUserPlayerInfo.map { $0.playerName }
        )
    }

    // MARK: - Private Helpers

    private func normalizePlayerId(_ id: String) -> String {
        if id.hasSuffix(".0") {
            return String(id.dropLast(2))
        }
        return id
    }

    private func findMatchingPlayerInfo(playerIds: [String], in playerInfoList: [PlayerInfo]) -> [PlayerInfo] {
        let normalizedIds = Set(playerIds.map { normalizePlayerId($0) })
        return playerInfoList.filter { playerInfo in
            normalizedIds.contains(normalizePlayerId(playerInfo.playerId))
        }
    }
}
