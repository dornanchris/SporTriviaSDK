import Foundation

/// Parses JSON data structures used by the SDK.
enum JsonParser {

    /// Parse a custom answer key from raw JSON data.
    static func parseAnswerKey(from data: Data) throws -> AnswerKey {
        return try JSONDecoder().decode(AnswerKey.self, from: data)
    }

    /// Parse a player list from raw JSON data (the all_{sport}_players.json format).
    static func parsePlayerList(from data: Data) throws -> [PlayerInfo] {
        let playerDataList = try JSONDecoder().decode([PlayerData].self, from: data)
        return deduplicate(playerDataList.map { pd in
            PlayerInfo(
                playerId: pd.player_id.trimmingCharacters(in: .whitespacesAndNewlines),
                playerName: pd.playerName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\u{00c2}", with: "")
                    .replacingOccurrences(of: "#", with: "")
                    .replacingOccurrences(of: "+", with: "")
                    .replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: "?", with: ""),
                yearsPlayed: "\(pd.first_season)-\(pd.last_season)"
                    .replacingOccurrences(of: ".0", with: "")
            )
        })
    }

    /// Remove duplicate players by playerId.
    static func deduplicate(_ players: [PlayerInfo]) -> [PlayerInfo] {
        var seen: [String: PlayerInfo] = [:]
        for player in players {
            seen[player.playerId] = player
        }
        return Array(seen.values)
    }

    /// Format game results as JSON for S3 upload.
    static func formatGameResults(
        userInfo: SporTriviaUserInfo,
        gameId: String,
        correctPlayers: [PlayerInfo]
    ) throws -> Data {
        var result: [String: Any] = [
            "firstName": userInfo.firstName,
            "lastName": userInfo.lastName,
            "email": userInfo.email,
            "phoneNumber": userInfo.phoneNumber,
            "gameId": gameId,
            "correctAnswers": correctPlayers.map { [
                "playerId": $0.playerId,
                "playerName": $0.playerName,
                "yearsPlayed": $0.yearsPlayed
            ]}
        ]
        return try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
    }
}
