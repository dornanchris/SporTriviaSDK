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
    ///
    /// Writes the keys the SporTrivia portal reads back for its contacts
    /// view and CSV export (name/email/phone/over_18/custom_field_answers/
    /// answers_found), plus the original firstName/lastName/phoneNumber/
    /// correctAnswers keys for older downstream consumers.
    static func formatGameResults(
        userInfo: SporTriviaUserInfo,
        gameId: String,
        correctPlayers: [PlayerInfo]
    ) throws -> Data {
        let fullName = [userInfo.firstName, userInfo.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let answersFound = correctPlayers.map { player -> String in
            player.yearsPlayed.isEmpty ? player.playerName : "\(player.playerName) \(player.yearsPlayed)"
        }
        let result: [String: Any] = [
            "gameId": gameId,
            "submitted_at": ISO8601DateFormatter().string(from: Date()),
            "name": fullName,
            "email": userInfo.email,
            "phone": userInfo.phoneNumber,
            "over_18": userInfo.over18,
            "custom_field_answers": userInfo.customFieldAnswers,
            "answers_found": answersFound,
            "firstName": userInfo.firstName,
            "lastName": userInfo.lastName,
            "phoneNumber": userInfo.phoneNumber,
            "correctAnswers": correctPlayers.map { [
                "playerId": $0.playerId,
                "playerName": $0.playerName,
                "yearsPlayed": $0.yearsPlayed
            ]}
        ]
        return try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
    }
}
