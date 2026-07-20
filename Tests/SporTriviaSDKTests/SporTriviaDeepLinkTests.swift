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

    func testParseMinorLeagueHockeyLinks() {
        let ahl = SporTriviaDeepLink.parse("partnerapp://sportrivia/custom/HSB_WBS?info=ahl")
        XCTAssertEqual(ahl?.gameId, "HSB_WBS")
        XCTAssertEqual(ahl?.sport, .ahl)

        let echl = SporTriviaDeepLink.parse("sportrivia://custom/FLE_TOW?info=echl")
        XCTAssertEqual(echl?.gameId, "FLE_TOW")
        XCTAssertEqual(echl?.sport, .echl)
    }

    func testMinorLeagueSportRawValuesMatchS3Folders() {
        // The suggestion list is fetched from
        // answer_keys/<rawValue>/all_<rawValue>_players.json, so a minor-league
        // custom game must resolve to the ahl/echl folders — not nhl.
        XCTAssertEqual(Sport.ahl.rawValue, "ahl")
        XCTAssertEqual(Sport.echl.rawValue, "echl")
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
