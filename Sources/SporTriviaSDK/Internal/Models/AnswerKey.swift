import Foundation

/// Represents a custom game answer key downloaded from S3.
struct AnswerKey: Decodable {
    let player_id: [String]
    let combo: String
    let type: Int
    let question: String?

    enum CodingKeys: String, CodingKey {
        case player_id
        case combo
        case type
        case question
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle player_id as [String] or [Int]
        if let playerIds = try? container.decode([String].self, forKey: .player_id) {
            player_id = playerIds
        } else if let playerIds = try? container.decode([Int].self, forKey: .player_id) {
            player_id = playerIds.map { String($0) }
        } else {
            throw DecodingError.typeMismatch(
                [String].self,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected [String] or [Int] for player_id"
                )
            )
        }

        combo = try container.decode(String.self, forKey: .combo)
        type = try container.decode(Int.self, forKey: .type)
        question = try container.decodeIfPresent(String.self, forKey: .question)
    }
}

/// Represents player data from the all_players JSON files.
struct PlayerData: Decodable {
    let player_id: String
    let playerName: String
    let first_season: String
    let last_season: String

    enum CodingKeys: String, CodingKey {
        case player_id
        case Player
        case first_season
        case last_season
    }

    enum AlternateCodingKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle player_id as String or Int
        if let playerIdInt = try? container.decode(Int.self, forKey: .player_id) {
            player_id = String(playerIdInt)
        } else if let playerIdString = try? container.decode(String.self, forKey: .player_id) {
            player_id = playerIdString
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected String or Int for player_id"
                )
            )
        }

        // Try "Player" key first, fall back to "name" (hockey format)
        if let name = try? container.decode(String.self, forKey: .Player) {
            playerName = name
        } else {
            let altContainer = try decoder.container(keyedBy: AlternateCodingKeys.self)
            playerName = try altContainer.decode(String.self, forKey: .name)
        }

        // Handle seasons as String or Int
        if let firstInt = try? container.decode(Int.self, forKey: .first_season) {
            first_season = String(firstInt)
        } else {
            first_season = try container.decode(String.self, forKey: .first_season)
        }

        if let lastInt = try? container.decode(Int.self, forKey: .last_season) {
            last_season = String(lastInt)
        } else {
            last_season = try container.decode(String.self, forKey: .last_season)
        }
    }
}
