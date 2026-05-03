import XCTest
@testable import SporTriviaSDK

final class GameEngineTests: XCTestCase {

    func testCheckAnswerCorrect() {
        let gameState = GameState()
        let playerListManager = PlayerListManager()
        let s3Service = S3DataService(credentialProvider: MockCredentialProvider(), bucketName: "test")
        let imageCache = ImageCache(s3Service: s3Service)
        let engine = GameEngine(
            gameState: gameState,
            playerListManager: playerListManager,
            s3Service: s3Service,
            imageCache: imageCache
        )

        // Set up correct player IDs manually
        engine.correctPlayerIds = ["player001", "player002", "player003"]
        gameState.sport = .nhl
        gameState.correctPlayerInfo = [
            PlayerInfo(playerId: "player001", playerName: "Wayne Gretzky", yearsPlayed: "1979-1999"),
            PlayerInfo(playerId: "player002", playerName: "Mario Lemieux", yearsPlayed: "1984-2006"),
            PlayerInfo(playerId: "player003", playerName: "Bobby Orr", yearsPlayed: "1966-1979"),
        ]
        engine.startGame()

        let testPlayer = PlayerInfo(playerId: "player001", playerName: "Wayne Gretzky", yearsPlayed: "1979-1999")
        let result = engine.checkAnswer(playerInfo: testPlayer)

        XCTAssertTrue(result, "Correct player should return true")
        XCTAssertEqual(gameState.correct, 1)
        XCTAssertEqual(gameState.currentStreak, 1)
        XCTAssertEqual(gameState.correctUserPlayerInfo.count, 1)
        XCTAssertEqual(gameState.correctPlayerInfo.count, 2, "One player should be removed from remaining")
    }

    func testCheckAnswerIncorrect() {
        let gameState = GameState()
        let playerListManager = PlayerListManager()
        let s3Service = S3DataService(credentialProvider: MockCredentialProvider(), bucketName: "test")
        let imageCache = ImageCache(s3Service: s3Service)
        let engine = GameEngine(
            gameState: gameState,
            playerListManager: playerListManager,
            s3Service: s3Service,
            imageCache: imageCache
        )

        engine.correctPlayerIds = ["player001"]
        gameState.sport = .mlb
        engine.startGame()

        let wrongPlayer = PlayerInfo(playerId: "wrong999", playerName: "Fake Player", yearsPlayed: "2000-2010")
        let result = engine.checkAnswer(playerInfo: wrongPlayer)

        XCTAssertFalse(result, "Wrong player should return false")
        XCTAssertEqual(gameState.incorrect, 1)
        XCTAssertEqual(gameState.correct, 0)
    }

    func testCheckIfIdUsed() {
        let gameState = GameState()
        let playerListManager = PlayerListManager()
        let s3Service = S3DataService(credentialProvider: MockCredentialProvider(), bucketName: "test")
        let imageCache = ImageCache(s3Service: s3Service)
        let engine = GameEngine(
            gameState: gameState,
            playerListManager: playerListManager,
            s3Service: s3Service,
            imageCache: imageCache
        )

        engine.correctPlayerIds = ["player001"]
        gameState.sport = .mlb
        gameState.correctPlayerInfo = [
            PlayerInfo(playerId: "player001", playerName: "Test Player", yearsPlayed: "2000-2010")
        ]
        engine.startGame()

        let player = PlayerInfo(playerId: "player001", playerName: "Test Player", yearsPlayed: "2000-2010")
        _ = engine.checkAnswer(playerInfo: player)

        XCTAssertTrue(engine.checkIfIdUsed(playerId: "player001"))
        XCTAssertFalse(engine.checkIfIdUsed(playerId: "player002"))
    }

    func testNormalizePlayerIdWithDotZero() {
        let gameState = GameState()
        let playerListManager = PlayerListManager()
        let s3Service = S3DataService(credentialProvider: MockCredentialProvider(), bucketName: "test")
        let imageCache = ImageCache(s3Service: s3Service)
        let engine = GameEngine(
            gameState: gameState,
            playerListManager: playerListManager,
            s3Service: s3Service,
            imageCache: imageCache
        )

        // Player ID with ".0" suffix should still match
        engine.correctPlayerIds = ["12345"]
        gameState.sport = .nba
        engine.startGame()

        let player = PlayerInfo(playerId: "12345.0", playerName: "Test", yearsPlayed: "")
        let result = engine.checkAnswer(playerInfo: player)
        XCTAssertTrue(result, "Player ID '12345.0' should match '12345'")
    }

    func testAllAnswersFound() {
        let gameState = GameState()
        let playerListManager = PlayerListManager()
        let s3Service = S3DataService(credentialProvider: MockCredentialProvider(), bucketName: "test")
        let imageCache = ImageCache(s3Service: s3Service)
        let engine = GameEngine(
            gameState: gameState,
            playerListManager: playerListManager,
            s3Service: s3Service,
            imageCache: imageCache
        )

        engine.correctPlayerIds = ["p1"]
        gameState.sport = .mlb
        gameState.correctPlayerInfo = [
            PlayerInfo(playerId: "p1", playerName: "Only Player", yearsPlayed: "2020-2025")
        ]
        engine.startGame()

        XCTAssertFalse(engine.allAnswersFound)

        let player = PlayerInfo(playerId: "p1", playerName: "Only Player", yearsPlayed: "2020-2025")
        _ = engine.checkAnswer(playerInfo: player)

        XCTAssertTrue(engine.allAnswersFound)
    }

    func testBuildResult() {
        let gameState = GameState()
        gameState.gameId = "NYI_Top5A"
        gameState.sport = .nhl
        gameState.correct = 3
        gameState.incorrect = 1
        gameState.maxStreak = 2
        gameState.firstName = "John"
        gameState.lastName = "Doe"
        gameState.email = "john@test.com"
        gameState.phoneNumber = "555-1234"
        gameState.correctUserPlayerInfo = [
            PlayerInfo(playerId: "p1", playerName: "Player One", yearsPlayed: "2000-2010")
        ]

        let playerListManager = PlayerListManager()
        let s3Service = S3DataService(credentialProvider: MockCredentialProvider(), bucketName: "test")
        let imageCache = ImageCache(s3Service: s3Service)
        let engine = GameEngine(
            gameState: gameState,
            playerListManager: playerListManager,
            s3Service: s3Service,
            imageCache: imageCache
        )

        let result = engine.buildResult()

        XCTAssertEqual(result.gameId, "NYI_Top5A")
        XCTAssertEqual(result.sport, .nhl)
        XCTAssertEqual(result.correct, 3)
        XCTAssertEqual(result.incorrect, 1)
        XCTAssertEqual(result.maxStreak, 2)
        XCTAssertEqual(result.userInfo.firstName, "John")
        XCTAssertEqual(result.correctPlayerNames, ["Player One"])
    }
}

// MARK: - Mock

private struct MockCredentialProvider: SporTriviaCredentialProvider {
    func presignedGetURL(forKey key: String) async throws -> URL {
        return URL(string: "https://example.com/\(key)")!
    }
    func presignedPutURL(forKey key: String) async throws -> URL {
        return URL(string: "https://example.com/put/\(key)")!
    }
}
