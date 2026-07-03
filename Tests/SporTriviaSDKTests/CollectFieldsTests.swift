import XCTest
@testable import SporTriviaSDK

final class CollectFieldsTests: XCTestCase {

    func testParseAnswerKeyWithCollectFields() throws {
        let json = """
        {
            "combo": "NYI_Top5A",
            "type": 2,
            "player_id": ["p1", "p2"],
            "question": "Name the top assists leaders",
            "collect_fields": {
                "name": true,
                "email": true,
                "phone": false,
                "over_18": true,
                "custom_questions": [
                    {"id": "q1", "label": "Favorite player", "placeholder": "Type a name", "required": true},
                    {"id": "q2", "label": "Season ticket holder?", "placeholder": "", "required": false}
                ]
            }
        }
        """.data(using: .utf8)!

        let answerKey = try JsonParser.parseAnswerKey(from: json)
        let fields = try XCTUnwrap(answerKey.collectFields)

        XCTAssertTrue(fields.name)
        XCTAssertTrue(fields.email)
        XCTAssertFalse(fields.phone)
        XCTAssertTrue(fields.over18)
        XCTAssertTrue(fields.hasAnythingToCollect)
        XCTAssertEqual(fields.customQuestions.count, 2)
        XCTAssertEqual(fields.customQuestions[0].id, "q1")
        XCTAssertEqual(fields.customQuestions[0].label, "Favorite player")
        XCTAssertEqual(fields.customQuestions[0].placeholder, "Type a name")
        XCTAssertTrue(fields.customQuestions[0].required)
        XCTAssertFalse(fields.customQuestions[1].required)
    }

    func testLegacyAnswerKeyHasNoCollectFields() throws {
        let json = """
        {"combo": "NYI_Top5A", "type": 2, "player_id": ["p1"], "question": "Q"}
        """.data(using: .utf8)!

        let answerKey = try JsonParser.parseAnswerKey(from: json)

        XCTAssertNil(answerKey.collectFields)
        XCTAssertTrue(CollectFields.legacyDefault.name)
        XCTAssertTrue(CollectFields.legacyDefault.email)
        XCTAssertTrue(CollectFields.legacyDefault.phone)
        XCTAssertFalse(CollectFields.legacyDefault.over18)
        XCTAssertTrue(CollectFields.legacyDefault.hasAnythingToCollect)
    }

    func testNothingToCollect() throws {
        let json = """
        {
            "combo": "X_Y", "type": 2, "player_id": ["p1"],
            "collect_fields": {"name": false, "email": false, "phone": false, "over_18": false, "custom_questions": []}
        }
        """.data(using: .utf8)!

        let answerKey = try JsonParser.parseAnswerKey(from: json)

        XCTAssertEqual(answerKey.collectFields?.hasAnythingToCollect, false)
    }

    func testFormatGameResultsIncludesPortalKeys() throws {
        let userInfo = SporTriviaUserInfo(
            firstName: "Casey",
            lastName: "Fan",
            email: "casey@example.com",
            phoneNumber: "555-1234",
            over18: true,
            customFieldAnswers: ["Favorite player": "Mat Barzal"]
        )
        let players = [PlayerInfo(playerId: "p1", playerName: "Mat Barzal", yearsPlayed: "2016-2024")]

        let data = try JsonParser.formatGameResults(userInfo: userInfo, gameId: "NYI_Top5A", correctPlayers: players)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["name"] as? String, "Casey Fan")
        XCTAssertEqual(payload["email"] as? String, "casey@example.com")
        XCTAssertEqual(payload["phone"] as? String, "555-1234")
        XCTAssertEqual(payload["over_18"] as? Bool, true)
        XCTAssertEqual(payload["custom_field_answers"] as? [String: String], ["Favorite player": "Mat Barzal"])
        XCTAssertEqual(payload["answers_found"] as? [String], ["Mat Barzal 2016-2024"])
        XCTAssertNotNil(payload["submitted_at"])
        // Legacy keys kept for older consumers
        XCTAssertEqual(payload["firstName"] as? String, "Casey")
        XCTAssertEqual(payload["phoneNumber"] as? String, "555-1234")
        XCTAssertNotNil(payload["correctAnswers"])
    }
}
