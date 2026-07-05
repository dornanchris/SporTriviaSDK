import XCTest
@testable import SporTriviaSDK

final class JsonParserTests: XCTestCase {

    func testParseAnswerKey() throws {
        let json = """
        {
            "combo": "NYI_Top5A",
            "type": 2,
            "player_id": ["p1", "p2", "p3"],
            "question": "Name the top 5 assists leaders"
        }
        """.data(using: .utf8)!

        let answerKey = try JsonParser.parseAnswerKey(from: json)

        XCTAssertEqual(answerKey.combo, "NYI_Top5A")
        XCTAssertEqual(answerKey.type, 2)
        XCTAssertEqual(answerKey.player_id, ["p1", "p2", "p3"])
        XCTAssertEqual(answerKey.question, "Name the top 5 assists leaders")
    }

    func testParseAnswerKeyWithIntPlayerIds() throws {
        let json = """
        {
            "combo": "BOS_100careerW",
            "type": 2,
            "player_id": [123, 456, 789]
        }
        """.data(using: .utf8)!

        let answerKey = try JsonParser.parseAnswerKey(from: json)

        XCTAssertEqual(answerKey.player_id, ["123", "456", "789"])
        XCTAssertNil(answerKey.question)
    }

    func testParseAnswerKeyWithResponsePath() throws {
        let json = """
        {
            "combo": "custom_who-holds-the-home-run-record",
            "type": 2,
            "player_id": ["p1"],
            "response_path": "custom/MLB/CD Test/who-holds-the-home-run-record/responses/"
        }
        """.data(using: .utf8)!

        let answerKey = try JsonParser.parseAnswerKey(from: json)

        XCTAssertEqual(answerKey.responsePath, "custom/MLB/CD Test/who-holds-the-home-run-record/responses/")
    }

    func testParseAnswerKeyWithoutResponsePath() throws {
        let json = """
        {
            "combo": "NYI_Top5A",
            "type": 2,
            "player_id": ["p1"]
        }
        """.data(using: .utf8)!

        let answerKey = try JsonParser.parseAnswerKey(from: json)

        XCTAssertNil(answerKey.responsePath)
    }

    func testParsePlayerList() throws {
        let json = """
        [
            {"player_id": "gretzwa01", "Player": "Wayne Gretzky", "first_season": "1979", "last_season": "1999"},
            {"player_id": "lemiema01", "Player": "Mario Lemieux", "first_season": 1984, "last_season": 2006}
        ]
        """.data(using: .utf8)!

        let players = try JsonParser.parsePlayerList(from: json)

        XCTAssertEqual(players.count, 2)

        let gretzky = players.first { $0.playerId == "gretzwa01" }
        XCTAssertNotNil(gretzky)
        XCTAssertEqual(gretzky?.playerName, "Wayne Gretzky")
        XCTAssertEqual(gretzky?.yearsPlayed, "1979-1999")

        let lemieux = players.first { $0.playerId == "lemiema01" }
        XCTAssertNotNil(lemieux)
        XCTAssertEqual(lemieux?.yearsPlayed, "1984-2006")
    }

    func testParsePlayerListWithHockeyFormat() throws {
        let json = """
        [
            {"player_id": 8471214, "name": "Sidney Crosby", "first_season": 2005, "last_season": 2024}
        ]
        """.data(using: .utf8)!

        let players = try JsonParser.parsePlayerList(from: json)

        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players[0].playerName, "Sidney Crosby")
        XCTAssertEqual(players[0].playerId, "8471214")
    }

    func testDeduplicate() {
        let players = [
            PlayerInfo(playerId: "p1", playerName: "Player One", yearsPlayed: "2000-2010"),
            PlayerInfo(playerId: "p1", playerName: "Player One Dupe", yearsPlayed: "2000-2010"),
            PlayerInfo(playerId: "p2", playerName: "Player Two", yearsPlayed: "2005-2015"),
        ]

        let deduped = JsonParser.deduplicate(players)

        XCTAssertEqual(deduped.count, 2)
        let ids = Set(deduped.map { $0.playerId })
        XCTAssertEqual(ids, Set(["p1", "p2"]))
    }

    func testFormatGameResults() throws {
        let userInfo = SporTriviaUserInfo(
            firstName: "Jane",
            lastName: "Smith",
            email: "jane@test.com",
            phoneNumber: "555-0000"
        )
        let players = [
            PlayerInfo(playerId: "p1", playerName: "Player One", yearsPlayed: "2000-2010")
        ]

        let data = try JsonParser.formatGameResults(
            userInfo: userInfo,
            gameId: "NYI_Top5A",
            correctPlayers: players
        )

        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?["firstName"] as? String, "Jane")
        XCTAssertEqual(parsed?["gameId"] as? String, "NYI_Top5A")

        let answers = parsed?["correctAnswers"] as? [[String: Any]]
        XCTAssertEqual(answers?.count, 1)
        XCTAssertEqual(answers?.first?["playerName"] as? String, "Player One")
    }
}
