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

    // MARK: - Schema v2 upload payload

    /// The documented cross-platform key order — must stay in lockstep with
    /// the Android SDK's JsonParserTest and PARTNER_SETUP.md.
    static let expectedKeyOrder = [
        "schema_version", "game_id", "submitted_at", "platform", "source",
        "sdk_version", "first_name", "last_name", "name", "email", "phone",
        "over_18", "custom_field_answers", "answers_found", "correct_answers",
        "location", "location_status",
    ]

    private func makeUserInfo() -> SporTriviaUserInfo {
        SporTriviaUserInfo(
            firstName: "Jane",
            lastName: "Smith",
            email: "jane@test.com",
            phoneNumber: "555-0000",
            over18: true,
            customFieldAnswers: ["Zebra question": "z", "Alpha question": "a"]
        )
    }

    func testFormatGameResultsSchemaV2() throws {
        let players = [
            PlayerInfo(playerId: "p1", playerName: "Player One", yearsPlayed: "2000-2010")
        ]

        let data = try JsonParser.formatGameResults(
            userInfo: makeUserInfo(),
            gameId: "NYI_Top5A",
            correctPlayers: players
        )

        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?["schema_version"] as? Int, 2)
        XCTAssertEqual(parsed?["game_id"] as? String, "NYI_Top5A")
        XCTAssertEqual(parsed?["platform"] as? String, "ios")
        XCTAssertEqual(parsed?["source"] as? String, "sdk")
        XCTAssertEqual(parsed?["sdk_version"] as? String, SporTriviaSDK.sdkVersion)
        XCTAssertEqual(parsed?["first_name"] as? String, "Jane")
        XCTAssertEqual(parsed?["last_name"] as? String, "Smith")
        XCTAssertEqual(parsed?["name"] as? String, "Jane Smith")
        XCTAssertEqual(parsed?["over_18"] as? Bool, true)

        let answers = parsed?["correct_answers"] as? [[String: Any]]
        XCTAssertEqual(answers?.count, 1)
        XCTAssertEqual(answers?.first?["player_name"] as? String, "Player One")
        XCTAssertEqual(answers?.first?["player_id"] as? String, "p1")
        XCTAssertEqual(answers?.first?["years_played"] as? String, "2000-2010")

        // No location provider → null location, status unavailable
        XCTAssertTrue(parsed?["location"] is NSNull)
        XCTAssertEqual(parsed?["location_status"] as? String, "unavailable")

        // Legacy duplicate keys are gone in v2
        for legacyKey in ["gameId", "firstName", "lastName", "phoneNumber", "correctAnswers"] {
            XCTAssertNil(parsed?[legacyKey], "\(legacyKey) must not be emitted in schema v2")
        }
    }

    func testFormatGameResultsKeyOrderIsExact() throws {
        let data = try JsonParser.formatGameResults(
            userInfo: makeUserInfo(),
            gameId: "NYI_Top5A",
            correctPlayers: []
        )
        let json = String(data: data, encoding: .utf8)!

        var lastIndex = json.startIndex
        for key in JsonParserTests.expectedKeyOrder {
            guard let range = json.range(of: "\"\(key)\":", range: lastIndex..<json.endIndex) else {
                XCTFail("Key \(key) missing or out of order")
                return
            }
            lastIndex = range.upperBound
        }
    }

    func testFormatGameResultsCustomAnswersAlphabetical() throws {
        let data = try JsonParser.formatGameResults(
            userInfo: makeUserInfo(),
            gameId: "NYI_Top5A",
            correctPlayers: []
        )
        let json = String(data: data, encoding: .utf8)!
        let alphaIndex = json.range(of: "Alpha question")!.lowerBound
        let zebraIndex = json.range(of: "Zebra question")!.lowerBound
        XCTAssertLessThan(alphaIndex, zebraIndex, "custom_field_answers keys must be alphabetical")
    }

    func testFormatGameResultsTimestampFormat() throws {
        let data = try JsonParser.formatGameResults(
            userInfo: makeUserInfo(),
            gameId: "g",
            correctPlayers: []
        )
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let stamp = parsed?["submitted_at"] as? String ?? ""
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"#
        XCTAssertNotNil(stamp.range(of: pattern, options: .regularExpression), "got: \(stamp)")
    }

    func testFormatGameResultsWithGrantedLocation() throws {
        let fix = LocationFix(latitude: 40.75, longitude: -73.99, accuracyMeters: 12.5, capturedAt: "2026-07-05T12:00:00Z")
        let data = try JsonParser.formatGameResults(
            userInfo: makeUserInfo(),
            gameId: "g",
            correctPlayers: [],
            location: .granted(fix)
        )
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let location = parsed?["location"] as? [String: Any]
        XCTAssertEqual(location?["latitude"] as? Double, 40.75)
        XCTAssertEqual(location?["longitude"] as? Double, -73.99)
        XCTAssertEqual(location?["accuracy_meters"] as? Double, 12.5)
        XCTAssertEqual(location?["captured_at"] as? String, "2026-07-05T12:00:00Z")
        XCTAssertEqual(parsed?["location_status"] as? String, "granted")

        // Inner key order is part of the schema too
        let json = String(data: data, encoding: .utf8)!
        for (earlier, later) in [("latitude", "longitude"), ("longitude", "accuracy_meters"), ("accuracy_meters", "captured_at")] {
            XCTAssertLessThan(json.range(of: "\"\(earlier)\":")!.lowerBound, json.range(of: "\"\(later)\":")!.lowerBound)
        }
    }

    func testFormatGameResultsLocationStatuses() throws {
        for (result, expected) in [(LocationResult.denied, "denied"), (.timedOut, "timeout"), (.unavailable, "unavailable")] {
            let data = try JsonParser.formatGameResults(
                userInfo: makeUserInfo(),
                gameId: "g",
                correctPlayers: [],
                location: result
            )
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertTrue(parsed?["location"] is NSNull)
            XCTAssertEqual(parsed?["location_status"] as? String, expected)
        }
    }

    // MARK: - Lenient player-list parsing

    func testParsePlayerListSkipsBadRecordsKeepsRest() throws {
        let json = """
        [
            {"player_id": "good1", "Player": "Good Player", "first_season": 2000, "last_season": 2010},
            {"player_id": "nullseason", "Player": "Null Season", "first_season": null, "last_season": null},
            {"player_id": "noname", "first_season": 2001, "last_season": 2002},
            {"player_id": "good2", "Player": "Other Player", "first_season": "2005", "last_season": "2015"}
        ]
        """.data(using: .utf8)!

        let players = try JsonParser.parsePlayerList(from: json)
        let ids = Set(players.map { $0.playerId })

        XCTAssertTrue(ids.contains("good1"))
        XCTAssertTrue(ids.contains("good2"))
        XCTAssertTrue(ids.contains("nullseason"), "null seasons must not drop the record")
        XCTAssertFalse(ids.contains("noname"), "record without any name key is unusable")
        XCTAssertEqual(players.first { $0.playerId == "nullseason" }?.yearsPlayed, "")
    }
}
