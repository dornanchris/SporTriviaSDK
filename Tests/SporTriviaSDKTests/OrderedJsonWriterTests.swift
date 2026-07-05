import XCTest
@testable import SporTriviaSDK

final class OrderedJsonWriterTests: XCTestCase {

    func testObjectPreservesInsertionOrder() {
        let value = JsonValue.object([
            ("zebra", .int(1)),
            ("alpha", .int(2)),
            ("mid", .int(3)),
        ])
        XCTAssertEqual(value.serialized(), #"{"zebra":1,"alpha":2,"mid":3}"#)
    }

    func testEscaping() {
        let value = JsonValue.object([
            ("text", .string("He said \"hi\"\nback\\slash\ttab")),
        ])
        XCTAssertEqual(value.serialized(), #"{"text":"He said \"hi\"\nback\\slash\ttab"}"#)
    }

    func testControlCharacterEscaping() {
        let value = JsonValue.string("a\u{01}b")
        XCTAssertEqual(value.serialized(), #""ab""#)
    }

    func testUnicodePassthrough() {
        let value = JsonValue.string("José Peña — 東京")
        XCTAssertEqual(value.serialized(), "\"José Peña — 東京\"")
    }

    func testNestedStructures() {
        let value = JsonValue.object([
            ("list", .array([.bool(true), .null, .double(1.5)])),
            ("obj", .object([("k", .string("v"))])),
        ])
        XCTAssertEqual(value.serialized(), #"{"list":[true,null,1.5],"obj":{"k":"v"}}"#)
    }

    func testNonFiniteDoubleBecomesNull() {
        XCTAssertEqual(JsonValue.double(.nan).serialized(), "null")
        XCTAssertEqual(JsonValue.double(.infinity).serialized(), "null")
    }

    func testOutputIsValidJson() throws {
        let value = JsonValue.object([
            ("s", .string("quote \" and emoji 🎉")),
            ("n", .double(-0.25)),
            ("arr", .array([.object([("x", .null)])])),
        ])
        let parsed = try JSONSerialization.jsonObject(with: value.serializedData()) as? [String: Any]
        XCTAssertEqual(parsed?["s"] as? String, "quote \" and emoji 🎉")
        XCTAssertEqual(parsed?["n"] as? Double, -0.25)
    }

    // MARK: - Pretty printing

    func testPrettyOneFieldPerLinePreservesOrder() {
        let value = JsonValue.object([
            ("zebra", .int(1)),
            ("alpha", .int(2)),
        ])
        XCTAssertEqual(value.serialized(pretty: true), "{\n  \"zebra\": 1,\n  \"alpha\": 2\n}")
    }

    func testPrettyNestsAndKeepsEmptyInline() {
        let value = JsonValue.object([
            ("obj", .object([("k", .string("v"))])),
            ("empty_obj", .object([])),
            ("list", .array([.int(1), .int(2)])),
            ("empty_list", .array([])),
        ])
        let expected = """
        {
          "obj": {
            "k": "v"
          },
          "empty_obj": {},
          "list": [
            1,
            2
          ],
          "empty_list": []
        }
        """
        XCTAssertEqual(value.serialized(pretty: true), expected)
    }

    func testPrettyOutputParsesToSameObject() throws {
        let value = JsonValue.object([
            ("s", .string("quote \" and emoji 🎉")),
            ("arr", .array([.object([("x", .null)])])),
        ])
        let pretty = value.serializedData(pretty: true)
        XCTAssertTrue(String(data: pretty, encoding: .utf8)!.contains("\n"))
        let parsed = try JSONSerialization.jsonObject(with: pretty) as? [String: Any]
        XCTAssertEqual(parsed?["s"] as? String, "quote \" and emoji 🎉")
    }
}
