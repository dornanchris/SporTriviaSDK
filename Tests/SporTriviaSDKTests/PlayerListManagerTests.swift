import XCTest
@testable import SporTriviaSDK

final class PlayerListManagerTests: XCTestCase {

    func testFilteredPlayerInfoList() {
        let manager = PlayerListManager()
        manager.playerInfoList = [
            PlayerInfo(playerId: "p1", playerName: "Wayne Gretzky", yearsPlayed: "1979-1999"),
            PlayerInfo(playerId: "p2", playerName: "Mario Lemieux", yearsPlayed: "1984-2006"),
            PlayerInfo(playerId: "p3", playerName: "Mark Messier", yearsPlayed: "1979-2004"),
        ]

        manager.userInput = "Mar"
        manager.updateFilteredPlayerInfoList()

        XCTAssertEqual(manager.filteredPlayerInfoList.count, 2, "Should match Mario and Mark")

        manager.userInput = "Gretzky"
        manager.updateFilteredPlayerInfoList()

        XCTAssertEqual(manager.filteredPlayerInfoList.count, 1)
        XCTAssertEqual(manager.filteredPlayerInfoList.first?.playerId, "p1")
    }

    func testFilterWithDiacritics() {
        let manager = PlayerListManager()
        manager.playerInfoList = [
            PlayerInfo(playerId: "p1", playerName: "Jos\u{00e9} Bautista", yearsPlayed: "2004-2018"),
        ]

        manager.userInput = "Jose"
        manager.updateFilteredPlayerInfoList()

        XCTAssertEqual(manager.filteredPlayerInfoList.count, 1, "Diacritics should be normalized")
    }

    func testSelectPlayerInfoFromInput() {
        let manager = PlayerListManager()
        manager.playerInfoList = [
            PlayerInfo(playerId: "p1", playerName: "Wayne Gretzky", yearsPlayed: "1979-1999"),
        ]

        manager.userInput = "Wayne Gretzky"
        let result = manager.selectPlayerInfoFromInput()

        XCTAssertEqual(result.playerId, "p1")
        XCTAssertNotNil(manager.selectedPlayerInfo)
    }

    func testSelectPlayerInfoFromInputNoMatch() {
        let manager = PlayerListManager()
        manager.playerInfoList = [
            PlayerInfo(playerId: "p1", playerName: "Wayne Gretzky", yearsPlayed: "1979-1999"),
        ]

        manager.userInput = "Not A Player"
        let result = manager.selectPlayerInfoFromInput()

        // Should return a dummy with the input as playerName
        XCTAssertEqual(result.playerName, "Not A Player")
        XCTAssertTrue(result.playerId.hasPrefix("unknown_"))
    }

    func testEmptyInputReturnsNoResults() {
        let manager = PlayerListManager()
        manager.playerInfoList = [
            PlayerInfo(playerId: "p1", playerName: "Wayne Gretzky", yearsPlayed: "1979-1999"),
        ]

        manager.userInput = ""
        manager.updateFilteredPlayerInfoList()

        XCTAssertTrue(manager.filteredPlayerInfoList.isEmpty)
    }
}
