import XCTest
@testable import SporTriviaSDK

final class SporTriviaDeepLinkTests: XCTestCase {

    func testParsePartnerSchemeLink() {
        let link = SporTriviaDeepLink.parse("partnerapp://sportrivia/custom/NYI_Top5A?info=nhl")

        XCTAssertEqual(link?.gameId, "NYI_Top5A")
        XCTAssertEqual(link?.sport, .nhl)
    }

    func testParseSporTriviaAppLink() {
        let link = SporTriviaDeepLink.parse("sportrivia://custom/BOS_NYY?info=mlb")

        XCTAssertEqual(link?.gameId, "BOS_NYY")
        XCTAssertEqual(link?.sport, .mlb)
    }

    func testParseUniversalLinkForm() {
        let link = SporTriviaDeepLink.parse("https://sportrivia-app.com/sdk/r/islanders/abc-123?game=NYI_Top5A&info=nhl")

        XCTAssertEqual(link?.gameId, "NYI_Top5A")
        XCTAssertEqual(link?.sport, .nhl)
    }

    func testParseUniversalLinkWithoutGameParamIsRejected() {
        XCTAssertNil(SporTriviaDeepLink.parse("https://sportrivia-app.com/sdk/r/islanders/abc-123?info=nhl"))
    }

    func testParseStripsJsonSuffix() {
        let link = SporTriviaDeepLink.parse("partnerapp://sportrivia/custom/NYI_Top5A.json?info=nhl")

        XCTAssertEqual(link?.gameId, "NYI_Top5A")
    }

    func testParseURLOverload() {
        let url = URL(string: "partnerapp://sportrivia/custom/LAL_BOS?info=nba")!

        let link = SporTriviaDeepLink.parse(url)

        XCTAssertEqual(link, SporTriviaDeepLink(gameId: "LAL_BOS", sport: .nba))
    }

    func testParseRejectsUnknownSport() {
        XCTAssertNil(SporTriviaDeepLink.parse("partnerapp://sportrivia/custom/NYI_Top5A?info=cricket"))
    }

    func testParseRejectsMissingSport() {
        XCTAssertNil(SporTriviaDeepLink.parse("partnerapp://sportrivia/custom/NYI_Top5A"))
    }

    func testParseRejectsNonGameLink() {
        XCTAssertNil(SporTriviaDeepLink.parse("partnerapp://sportrivia/settings?info=nhl"))
        XCTAssertNil(SporTriviaDeepLink.parse("partnerapp://sportrivia/custom?info=nhl"))
        XCTAssertNil(SporTriviaDeepLink.parse("not a url"))
    }
}
